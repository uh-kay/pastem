import gleam/list
import gleam/result
import gleam/time/timestamp
import server/context.{type Context}
import server/db
import server/error
import server/sql
import youid/uuid

pub fn create_session(ctx: Context, user_id, expires_at) {
  let expiry = timestamp.add(timestamp.system_time(), expires_at)
  let #(expiry_unix, _) = timestamp.to_unix_seconds_and_nanoseconds(expiry)

  let id = uuid.v7() |> uuid.to_bit_array

  use session <- result.try(
    sql.create_session(id:, user_id:, expires_at: expiry_unix)
    |> db.query(ctx.db, _)
    |> result.map_error(error.DatabaseError),
  )

  list.first(session.rows)
  |> result.replace_error(error.InternalServerError("no session created"))
  |> result.map(fn(snippet) { snippet.id })
}
