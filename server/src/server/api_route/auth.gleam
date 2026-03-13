import gleam/dynamic/decode
import gleam/http
import gleam/http/cookie
import gleam/http/response
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/time/duration
import server/context
import server/error
import server/helper
import server/model/token
import server/model/user
import server/validator/validator
import wisp

type AuthError {
  UserError(user.UserError)
  TokenError(token.TokenError)
  ValidationError(validator.ValidationError)
  DecodeError(List(decode.DecodeError))
  Unauthorized
}

pub type Register {
  Register(username: String, email: String, password: String)
}

pub fn register_to_json(register: Register) -> json.Json {
  let Register(username:, email:, password:) = register
  json.object([
    #("username", json.string(username)),
    #("email", json.string(email)),
    #("password", json.string(password)),
  ])
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
      |> result.map_error(DecodeError),
    )

    use _ <- result.try(
      validator.new()
      |> user.validate_username(input.username)
      |> user.validate_email(input.email)
      |> user.validate_password(input.password)
      |> validator.valid
      |> result.map_error(ValidationError),
    )

    use password_bits <- result.try(
      user.hash_password(input.password) |> result.map_error(UserError),
    )

    user.create_user(ctx, input.username, input.email, password_bits)
    |> result.map_error(UserError)
  }

  case result {
    Ok(_) ->
      helper.json_response(["message"], [json.string("user created")], 201)
    Error(err) -> handle_error(req, err)
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

pub fn create_token_to_json(create_token: CreateToken) -> json.Json {
  let CreateToken(email:, password:) = create_token
  json.object([
    #("email", json.string(email)),
    #("password", json.string(password)),
  ])
}

pub fn create_token_decoder() -> decode.Decoder(CreateToken) {
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.string)
  decode.success(CreateToken(email:, password:))
}

pub fn create_token(ctx: context.Context, req: wisp.Request) -> wisp.Response {
  use json <- wisp.require_json(req)

  let result = {
    use input <- result.try(
      decode.run(json, create_token_decoder()) |> result.map_error(DecodeError),
    )

    use _ <- result.try(
      validator.new()
      |> user.validate_email(input.email)
      |> user.validate_password(input.password)
      |> validator.valid
      |> result.map_error(ValidationError),
    )

    use user <- result.try(
      user.verify_user(ctx, input.email, input.password)
      |> result.map_error(UserError),
    )

    use token <- result.try(
      token.create_new_token(
        ctx,
        user.id,
        duration.hours(365 * 24),
        token.scope_authentication,
      )
      |> result.map_error(TokenError),
    )

    Ok(token.plaintext)
  }

  case result {
    Ok(token) ->
      helper.json_response(["token"], [json.string(token)], 201)
      |> wisp.set_cookie(
        req,
        "auth_token",
        token,
        wisp.Signed,
        365 * 24 * 60 * 60,
      )
      |> response.set_cookie(
        "logged_in",
        "true",
        cookie.Attributes(
          max_age: Some(365 * 24 * 60 * 60),
          domain: None,
          path: Some("/"),
          secure: False,
          http_only: False,
          same_site: Some(cookie.Lax),
        ),
      )
    Error(err) -> handle_error(req, err)
  }
}

pub fn delete_token(ctx, req: wisp.Request) {
  let result = {
    use token <- result.try(
      wisp.get_cookie(req, "auth_token", wisp.Signed)
      |> result.replace_error(Unauthorized),
    )

    use user <- result.try(
      user.get_user_by_token(ctx, token) |> result.map_error(UserError),
    )

    token.delete_token(ctx, token.scope_authentication, user.id)
    |> result.map_error(TokenError)
  }

  case result {
    Ok(_) ->
      wisp.redirect("/")
      |> wisp.set_cookie(req, "auth_token", "", wisp.Signed, 0)
      |> response.set_cookie(
        "logged_in",
        "",
        cookie.Attributes(
          max_age: Some(0),
          domain: None,
          path: Some("/"),
          secure: False,
          http_only: False,
          same_site: Some(cookie.Lax),
        ),
      )
    Error(err) -> handle_error(req, err)
  }
}

fn handle_error(req: wisp.Request, err: AuthError) {
  case err {
    UserError(err) -> user.handle_error(req, err)
    TokenError(err) -> token.handle_error(req, err)
    ValidationError(err) -> validator.handle_error(req, err)
    DecodeError(err) -> {
      error.decode_error_to_string(err) |> wisp.log_warning()
      helper.error_response("bad request", 400)
    }
    Unauthorized -> {
      error.format_log(req, "unauthorized")
      helper.unauthorized()
    }
  }
}
