import argus
import gleam/bit_array
import gleam/list
import gleam/result
import server/context
import server/db
import server/errors
import server/sql
import shared

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
