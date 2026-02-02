import argus
import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/result
import gleam/time/duration
import server/context
import server/db
import server/db/tokens
import server/db/users
import server/errors
import server/sql
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

    use password <- result.try(
      argus.hasher()
      |> argus.hash(input.password, argus.gen_salt())
      |> result.map_error(errors.HashError),
    )

    let password_bits = password.encoded_hash |> bit_array.from_string

    sql.create_user(input.username, input.email, password_bits)
    |> db.exec(ctx.db, _)
    |> result.map_error(errors.DatabaseError)
  }

  case result {
    Ok(_) -> wisp.created()
    Error(errors.BadRequest(err)) -> wisp.bad_request(err)
    Error(err) -> errors.handle_error(req, err)
  }
}

pub fn login(ctx: context.Context, req: wisp.Request) {
  case req.method {
    http.Post -> login_user(ctx, req)
    _ -> wisp.method_not_allowed([http.Post])
  }
}

pub type Login {
  Login(email: String, password: String)
}

fn login_decoder() -> decode.Decoder(Login) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(Login(email:, password:))
}

fn login_user(ctx: context.Context, req: wisp.Request) -> wisp.Response {
  use json <- wisp.require_json(req)

  let result = {
    use input <- result.try(case decode.run(json, login_decoder()) {
      Ok(input) -> Ok(input)
      Error(_) -> Error(errors.BadRequest("failed to decode body"))
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
      |> json.to_string
      |> wisp.json_response(200)
    Error(err) -> {
      case err {
        errors.BadRequest(err) -> wisp.bad_request(err)
        _ -> errors.handle_error(req, err)
      }
    }
  }
}
