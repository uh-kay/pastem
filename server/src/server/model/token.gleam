import gleam/bit_array
import gleam/crypto
import gleam/time/duration
import gleam/time/timestamp
import pog
import server/context.{type Context}
import server/db
import server/error
import server/helper
import server/sql
import wisp

pub const scope_authentication = "authentication"

pub type TokenError {
  CreateTokenError(pog.QueryError)
  DeleteTokenError(pog.QueryError)
}

pub type Token {
  Token(
    plaintext: String,
    hash: BitArray,
    user_id: Int,
    expiry: Int,
    scope: String,
  )
}

pub fn generate_token(user_id: Int, ttl: duration.Duration, scope: String) {
  let random_bytes = crypto.strong_random_bytes(16)

  let plaintext = random_bytes |> bit_array.base64_url_encode(False)

  let hash = crypto.hash(crypto.Sha256, <<plaintext:utf8>>)

  let expiry = timestamp.add(timestamp.system_time(), ttl)
  let #(expiry_unix, _) = timestamp.to_unix_seconds_and_nanoseconds(expiry)

  Token(user_id:, expiry: expiry_unix, scope:, plaintext:, hash:)
}

pub fn create_new_token(
  ctx: Context,
  user_id: Int,
  ttl: duration.Duration,
  scope: String,
) {
  let token = generate_token(user_id, ttl, scope)

  case
    sql.create_new_token(token.hash, token.user_id, token.expiry, token.scope)
    |> db.exec(ctx.db, _)
  {
    Ok(_) -> Ok(token)
    Error(err) -> Error(CreateTokenError(err))
  }
}

pub fn delete_token(ctx: Context, scope: String, user_id: Int) {
  case sql.delete_token(scope, user_id) |> db.exec(ctx.db, _) {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error(DeleteTokenError(err))
  }
}

pub fn handle_error(req: wisp.Request, err: TokenError) {
  case err {
    CreateTokenError(err) | DeleteTokenError(err) -> {
      error.format_log(req, error.pog_error_to_string(err)) |> wisp.log_error()
      helper.internal_server_error()
    }
  }
}
