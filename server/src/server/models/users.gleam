import argus
import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string
import server/context
import server/db
import server/errors
import server/helpers
import server/sql
import shared
import validator/validator

pub fn validate_username(validator: validator.Validator, username: String) {
  let len = string.length(username)

  validator
  |> validator.check(!string.is_empty(username), "username", "must be provided")
  |> validator.check(len >= 1, "username", "must be at least 1 byte long")
  |> validator.check(
    len <= 255,
    "username",
    "must not be more than 255 bytes long",
  )
}

pub fn validate_email(validator: validator.Validator, email: String) {
  let len = string.length(email)

  validator
  |> validator.check(!string.is_empty(email), "email", "must be provided")
  |> validator.check(
    validator.matches(email, validator.email_rx()),
    "email",
    "invalid email",
  )
  |> validator.check(len >= 1, "email", "must be at least 1 byte long")
  |> validator.check(
    len <= 255,
    "email",
    "must not be more than 255 bytes long",
  )
}

pub fn validate_password(validator: validator.Validator, password: String) {
  let len = string.length(password)

  validator
  |> validator.check(!string.is_empty(password), "password", "must be provided")
  |> validator.check(len >= 1, "password", "must be at least 1 byte long")
  |> validator.check(
    len <= 72,
    "password",
    "must not be more than 255 bytes long",
  )
}

pub fn hash_password(password) {
  use password <- result.try(
    argus.hasher()
    |> argus.hash(password, argus.gen_salt())
    |> result.map_error(errors.HashError),
  )
  Ok(password.encoded_hash |> bit_array.from_string)
}

pub fn create_user(ctx: context.Context, username, email, password) {
  sql.create_user(username, email, password, helpers.current_time())
  |> db.exec(ctx.db, _)
  |> result.map_error(errors.DatabaseError)
}

pub fn get_user(ctx: context.Context, email: String) {
  case sql.get_user_by_email(email) |> db.query(ctx.db, _) {
    Ok(user) -> {
      list.first(user.rows)
      |> result.replace_error(errors.NotFound("user"))
      |> result.map(fn(row) {
        shared.User(
          id: row.id,
          username: row.username,
          email: row.email,
          password: row.password_hash,
          role_level: row.role_level,
          created_at: row.created_at,
        )
      })
    }
    Error(err) -> Error(errors.DatabaseError(err))
  }
}

pub fn verify_user(ctx: context.Context, email: String, password: String) {
  use user <- result.try(get_user(ctx, email))

  use password_hash <- result.try(
    bit_array.to_string(user.password)
    |> result.replace_error(errors.InternalServerError(
      "failed hashing password",
    )),
  )

  case argus.verify(password_hash, password) {
    Ok(True) -> Ok(user)
    Ok(False) -> Error(errors.Unauthorized)
    Error(err) -> Error(errors.HashError(err))
  }
}

pub fn get_user_by_token(ctx: context.Context, token: BitArray) {
  case
    sql.get_user_by_token(token)
    |> db.query(ctx.db, _)
  {
    Ok(user) -> {
      list.first(user.rows)
      |> result.replace_error(errors.NotFound("user"))
      |> result.map(fn(row) {
        shared.User(
          id: row.id,
          username: row.username,
          email: row.email,
          password: row.password_hash,
          role_level: row.role_level,
          created_at: row.created_at,
        )
      })
    }
    Error(err) -> Error(errors.DatabaseError(err))
  }
}
