import argus
import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/result
import gleam/time/duration
import server/context
import server/db
import server/errors
import server/helpers
import server/model/tokens
import server/model/users
import server/sql
import validator/validator
import wisp

pub type Register {
  Register(username: String, email: String, password: String)
}

pub fn register(ctx: context.Context, req: wisp.Request) {
  case req.method {
    http.Post -> register_user(ctx, req)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

fn register_decoder() -> decode.Decoder(Register) {
  use username <- decode.field("username", decode.string)
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(Register(username:, email:, password:))
}

fn register_user(ctx: context.Context, req: wisp.Request) {
  use json <- wisp.require_json(req)

  let result = {
    use input <- result.try(
      decode.run(json, register_decoder())
      |> result.replace_error(errors.BadRequest(
        "missing email, username, or password",
      )),
    )

    let validation = {
      validator.new()
      |> users.validate_username(input.username)
      |> users.validate_email(input.email)
      |> users.validate_password(input.password)
    }

    use _ <- result.try(case validator.valid(validation) {
      True -> Ok(Nil)
      False -> Error(errors.ValidationError(validation.errors))
    })

    use password <- result.try(
      argus.hasher()
      |> argus.hash(input.password, argus.gen_salt())
      |> result.map_error(errors.HashError),
    )

    let password_bits = password.encoded_hash |> bit_array.from_string

    sql.create_user(
      input.username,
      input.email,
      password_bits,
      helpers.current_time(),
    )
    |> db.exec(ctx.db, _)
    |> result.map_error(errors.DatabaseError)
  }

  case result {
    Ok(_) -> helpers.message_response("user created", 201)
    Error(err) -> errors.handle_error(req, err)
  }
}

pub fn tokens(ctx: context.Context, req: wisp.Request) {
  case req.method {
    http.Post -> create_token(ctx, req)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub type CreateToken {
  CreateToken(email: String, password: String)
}

fn create_token_decoder() -> decode.Decoder(CreateToken) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(CreateToken(email:, password:))
}

fn create_token(ctx: context.Context, req: wisp.Request) -> wisp.Response {
  use json <- wisp.require_json(req)

  let result = {
    use input <- result.try(case decode.run(json, create_token_decoder()) {
      Ok(input) -> Ok(input)
      Error(_) -> Error(errors.BadRequest("failed to decode body"))
    })

    let validation = {
      validator.new()
      |> users.validate_email(input.email)
      |> users.validate_password(input.password)
    }

    use _ <- result.try(case validator.valid(validation) {
      True -> Ok(Nil)
      False -> Error(errors.ValidationError(validation.errors))
    })

    use user <- result.try(users.verify_user(ctx, input.email, input.password))

    use token <- result.try(tokens.create_new_token(
      ctx,
      user.id,
      duration.hours(365 * 24),
      tokens.scope_authentication,
    ))

    Ok(token.plaintext)
  }

  case result {
    Ok(token) ->
      json.object([#("token", json.string(token))])
      |> helpers.json_response("token", 201)
    Error(err) -> errors.handle_error(req, err)
  }
}
