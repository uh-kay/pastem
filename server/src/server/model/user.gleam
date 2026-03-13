import argus
import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string
import pog.{ConstraintViolated}
import server/context
import server/db
import server/error
import server/helper
import server/sql
import server/validator/validator
import shared
import wisp

pub type Identifier {
  Email(String)
  Token(String)
}

pub type UserError {
  UserNotFoundError(Identifier)
  CreateUserError(pog.QueryError)
  UserLookupError(pog.QueryError)
  WrongCredentialError

  PasswordHashingError(argus.HashError)

  DuplicateEmailError(pog.QueryError)
  DuplicateUsernameError(pog.QueryError)
}

pub fn validate_username(validator: validator.Validator, username: String) {
  let len = string.length(username)
  let is_empty = string.is_empty(username)

  validator
  |> validator.check(is_empty, "username", "must be provided")
  |> validator.check(
    !is_empty && len < 3,
    "username",
    "must be at least 3 bytes long",
  )
  |> validator.check(
    len > 255,
    "username",
    "must not be more than 255 bytes long",
  )
}

pub fn validate_email(validator: validator.Validator, email: String) {
  let len = string.length(email)
  let is_empty = string.is_empty(email)

  validator
  |> validator.check(is_empty, "email", "must be provided")
  |> validator.check(
    !validator.matches(email, validator.email_rx()),
    "email",
    "invalid email",
  )
  |> validator.check(len > 255, "email", "must not be more than 255 bytes long")
}

pub fn validate_password(validator: validator.Validator, password: String) {
  let len = string.length(password)
  let is_empty = string.is_empty(password)

  validator
  |> validator.check(is_empty, "password", "must be provided")
  |> validator.check(len < 5, "password", "must be at least 5 bytes long")
  |> validator.check(
    len > 72,
    "password",
    "must not be more than 72 bytes long",
  )
}

pub fn hash_password(password) {
  use password <- result.try(
    argus.hasher()
    |> argus.hash(password, argus.gen_salt())
    |> result.map_error(PasswordHashingError),
  )
  Ok(password.encoded_hash)
}

pub fn create_user(
  ctx: context.Context,
  username,
  email,
  password,
) -> Result(pog.Returned(Nil), UserError) {
  case
    sql.create_user(username, email, password, helper.current_time())
    |> db.exec(ctx.db, _)
  {
    Ok(nil) -> Ok(nil)
    Error(err) ->
      case err {
        ConstraintViolated(constraint: "users_email_key", ..) ->
          Error(DuplicateEmailError(err))
        ConstraintViolated(constraint: "users_username_key", ..) ->
          Error(DuplicateUsernameError(err))
        _ -> Error(CreateUserError(err))
      }
  }
}

pub fn get_user(ctx: context.Context, email: String) {
  use user <- result.try(
    sql.get_user_by_email(email)
    |> db.query(ctx.db, _)
    |> result.map_error(UserLookupError),
  )

  use row <- result.try(
    list.first(user.rows)
    |> result.replace_error(UserNotFoundError(Email(email))),
  )

  Ok(shared.User(
    id: row.id,
    username: row.username,
    email: row.email,
    password: row.password_hash,
    role_level: row.role_level,
    created_at: row.created_at,
  ))
}

pub fn verify_user(ctx: context.Context, email: String, password: String) {
  use user <- result.try(get_user(ctx, email))

  case argus.verify(user.password, password) {
    Ok(True) -> Ok(user)
    Ok(False) -> Error(WrongCredentialError)
    Error(err) -> Error(PasswordHashingError(err))
  }
}

pub fn get_user_by_token(ctx: context.Context, token: String) {
  let token_hash = bit_array.from_string(token)

  use user <- result.try(
    sql.get_user_by_token(token_hash)
    |> db.query(ctx.db, _)
    |> result.map_error(UserLookupError),
  )

  use row <- result.try(
    list.first(user.rows)
    |> result.replace_error(UserNotFoundError(Token(token))),
  )

  Ok(shared.User(
    id: row.id,
    username: row.username,
    email: row.email,
    password: row.password_hash,
    role_level: row.role_level,
    created_at: row.created_at,
  ))
}

pub fn handle_error(req: wisp.Request, err: UserError) {
  case err {
    UserNotFoundError(identifier) ->
      case identifier {
        Email(email) -> {
          error.format_log(req, "user with email: " <> email <> " not found")
          helper.error_response("user not found", 404)
        }
        Token(token) -> {
          error.format_log(
            req,
            "user with token: "
              <> string.slice(token, 0, 4)
              <> "..."
              <> " not found",
          )
          helper.error_response("user not found", 404)
        }
      }
    WrongCredentialError -> {
      error.format_log(req, "wrong email or password")
      |> wisp.log_warning()
      helper.error_response("wrong email or password", 401)
    }
    PasswordHashingError(err) -> {
      error.format_log(req, error.argus_error_to_string(err))
      |> wisp.log_error()
      helper.internal_server_error()
    }
    UserLookupError(err) | CreateUserError(err) -> {
      error.format_log(req, error.pog_error_to_string(err))
      |> wisp.log_error()
      helper.internal_server_error()
    }
    DuplicateEmailError(_) -> {
      error.format_log(req, "duplicate email")
      |> wisp.log_warning()
      helper.error_response("email already exists", 409)
    }
    DuplicateUsernameError(_) -> {
      error.format_log(req, "duplicate username")
      |> wisp.log_warning()
      helper.error_response("username already exists", 409)
    }
  }
}
