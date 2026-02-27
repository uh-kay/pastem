import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/list
import gleam/result
import gleam/time/duration
import server/context
import server/error
import server/helper
import server/model/session
import server/model/token
import server/model/user
import validator/validator
import wisp
import youid/uuid

pub type Register {
  Register(username: String, email: String)
}

pub fn register_to_json(register: Register) -> json.Json {
  let Register(username:, email:) = register
  json.object([
    #("username", json.string(username)),
    #("email", json.string(email)),
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
  decode.success(Register(username:, email:))
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
      |> validator.valid,
    )

    user.create_user(ctx, input.username, input.email)
  }

  case result {
    Ok(_) ->
      helper.json_response(["message"], [json.string("user created")], 201)
    Error(err) -> error.handle_error(req, err)
  }
}

pub type CreateToken {
  CreateToken(email: String)
}

pub fn create_token_to_json(create_token: CreateToken) -> json.Json {
  let CreateToken(email) = create_token
  json.object([
    #("email", json.string(email)),
  ])
}

pub fn create_token_decoder() -> decode.Decoder(CreateToken) {
  use email <- decode.field("email", decode.string)
  decode.success(CreateToken(email:))
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
      |> validator.valid,
    )

    use user <- result.try(user.get_user(ctx, input.email))

    use token <- result.try(token.create_new_token(
      ctx,
      user.id,
      duration.hours(365 * 24),
    ))

    Ok(token.plaintext)
  }

  case result {
    Ok(token) -> helper.json_response(["token"], [json.string(token)], 201)
    Error(err) -> error.handle_error(req, err)
  }
}

pub fn create_session(ctx, req) {
  let result = {
    use token <- result.try(
      wisp.get_query(req)
      |> list.key_find("token")
      |> result.replace_error(error.BadRequest("missing token")),
    )

    use user <- result.try(user.get_user_by_token(ctx, token))

    use session_bit_aray <- result.try(session.create_session(
      ctx,
      user.id,
      duration.hours(24 * 365),
    ))

    case uuid.from_bit_array(session_bit_aray) {
      Ok(uuid) -> Ok(uuid.to_string(uuid))
      Error(_) -> Error(error.InternalServerError("error parsing bit array"))
    }
  }

  case result {
    Ok(session_id) ->
      helper.json_response(["session_id"], [json.string(session_id)], 200)
    Error(err) -> error.handle_error(req, err)
  }
}
