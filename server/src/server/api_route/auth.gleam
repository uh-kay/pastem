import gleam/crypto.{Sha256}
import gleam/dynamic/decode
import gleam/http
import gleam/http/cookie
import gleam/http/response
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/time/duration
import server/context
import server/error.{Unauthorized}
import server/helper
import server/model/token
import server/model/user
import validator/validator
import wisp

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
      |> result.replace_error(error.BadRequest(
        "missing email, username, or password",
      )),
    )

    use _ <- result.try(
      validator.new()
      |> user.validate_username(input.username)
      |> user.validate_email(input.email)
      |> user.validate_password(input.password)
      |> validator.valid,
    )

    use password_bits <- result.try(user.hash_password(input.password))

    user.create_user(ctx, input.username, input.email, password_bits)
  }

  case result {
    Ok(_) ->
      helper.json_response(["message"], [json.string("user created")], 201)
    Error(err) -> error.handle_error(req, err)
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
    use input <- result.try(case decode.run(json, create_token_decoder()) {
      Ok(input) -> Ok(input)
      Error(_) -> Error(error.BadRequest("failed to decode body"))
    })

    use _ <- result.try(
      validator.new()
      |> user.validate_email(input.email)
      |> user.validate_password(input.password)
      |> validator.valid,
    )

    use user <- result.try(user.verify_user(ctx, input.email, input.password))

    use token <- result.try(token.create_new_token(
      ctx,
      user.id,
      duration.hours(365 * 24),
      token.scope_authentication,
    ))

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
    Error(err) -> error.handle_error(req, err)
  }
}

pub fn delete_token(ctx, req) {
  let result = {
    use cookie <- result.try(
      wisp.get_cookie(req, "auth_token", wisp.Signed)
      |> result.replace_error(Unauthorized),
    )

    let token = crypto.hash(Sha256, <<cookie:utf8>>)
    use user <- result.try(user.get_user_by_token(ctx, token))

    token.delete_token(ctx, token.scope_authentication, user.id)
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
    Error(err) -> error.handle_error(req, err)
  }
}
