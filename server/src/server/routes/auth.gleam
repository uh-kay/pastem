import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/result
import gleam/time/duration
import server/context
import server/errors
import server/helpers
import server/models/tokens
import server/models/users
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

    let _ =
      validator.new()
      |> users.validate_username(input.username)
      |> users.validate_email(input.email)
      |> users.validate_password(input.password)
      |> validator.valid

    use password_bits <- result.try(users.hash_password(input.password))

    users.create_user(ctx, input.username, input.email, password_bits)
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

    let _ =
      validator.new()
      |> users.validate_email(input.email)
      |> users.validate_password(input.password)
      |> validator.valid

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
    Ok(token) -> helpers.json_response(json.string(token), "token", 201)
    Error(err) -> errors.handle_error(req, err)
  }
}
