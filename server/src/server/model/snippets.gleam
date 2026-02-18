import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import pog
import server/context
import server/db
import server/errors
import server/helpers
import server/sql
import shared
import validator/validator

pub fn validate_title(validator: validator.Validator, title: String) {
  let len = string.length(title)

  validator
  |> validator.check(!string.is_empty(title), "title", "must be provided")
  |> validator.check(len >= 1, "title", "must be at least 1 byte long")
  |> validator.check(
    len <= 255,
    "title",
    "must not be more than 255 bytes long",
  )
}

pub fn validate_content(validator: validator.Validator, content: String) {
  let len = string.length(content)

  validator
  |> validator.check(!string.is_empty(content), "content", "must be provided")
  |> validator.check(len >= 1, "content", "must be at least 1 byte long")
  |> validator.check(
    len <= 4096,
    "content",
    "must not be more than 4096 bytes long",
  )
}

pub fn validate_ttl(validator: validator.Validator, ttl: Int) {
  validator
  |> validator.check(ttl > 0, "ttl", "must be at least 1 hour")
  |> validator.check(
    ttl <= 7 * 24,
    "ttl",
    "must not be more than " <> int.to_string(7 * 24) <> " hours",
  )
}

pub fn list_snippets(ctx: context.Context, limit, offset) {
  case sql.get_snippets(limit, offset) |> db.query(ctx.db, _) {
    Ok(pog.Returned(0, _)) -> Error(errors.NotFound("snippet"))
    Ok(rows) ->
      Ok({
        rows.rows
        |> list.map(fn(row: sql.GetSnippets) {
          shared.Snippet(
            row.id,
            row.author,
            row.title,
            row.content,
            row.version,
            row.expires_at,
            row.updated_at,
            row.created_at,
          )
        })
      })
    Error(err) -> Error(errors.DatabaseError(err))
  }
}

pub fn get_snippet(
  ctx: context.Context,
  id: Int,
) -> Result(shared.Snippet, errors.AppError) {
  use snippet <- result.try(
    sql.get_snippet(id)
    |> db.query(ctx.db, _)
    |> result.map_error(errors.DatabaseError),
  )

  list.first(snippet.rows)
  |> result.replace_error(errors.NotFound("snippet"))
  |> result.map(fn(row) {
    shared.Snippet(
      id: row.id,
      author: row.author,
      title: row.title,
      content: row.content,
      version: row.version,
      expires_at: row.expires_at,
      updated_at: row.updated_at,
      created_at: row.created_at,
    )
  })
}

pub fn create_snippet(
  ctx: context.Context,
  title: String,
  content: String,
  expires_at: timestamp.Timestamp,
) {
  case ctx.user {
    option.Some(user) -> {
      timestamp.to_unix_seconds_and_nanoseconds(expires_at).0
      |> sql.create_snippet(
        user.id,
        title,
        content,
        _,
        helpers.current_time(),
        helpers.current_time(),
      )
      |> db.exec(ctx.db, _)
      |> result.map_error(errors.DatabaseError)
    }
    option.None -> {
      Error(errors.Unauthorized)
    }
  }
}

pub fn update_snippet(
  ctx: context.Context,
  title: option.Option(String),
  content: option.Option(String),
  id: Int,
) {
  use old_snippet <- result.try(get_snippet(ctx, id))

  case title, content {
    option.None, option.None ->
      Error(errors.BadRequest("missing title and content"))
    option.None, option.Some(content) ->
      sql.update_snippet(old_snippet.title, content, id, old_snippet.version)
      |> db.exec(ctx.db, _)
      |> result.map_error(errors.DatabaseError)
    option.Some(title), _ -> {
      sql.update_snippet(title, old_snippet.content, id, old_snippet.version)
      |> db.exec(ctx.db, _)
      |> result.map_error(errors.DatabaseError)
    }
  }
}

// pub fn update_snippet_transaction(
//   ctx: context.Context,
//   title: option.Option(String),
//   content: option.Option(String),
//   id: Int,
// ) {
//   case title, content {
//     option.None, option.None ->
//       Error(errors.BadRequest("missing title and content"))
//     _, _ ->
//       {
//         use conn <- pog.transaction(ctx.db)

//         sql.update_snippet(id, title, content)
//         |> db.exec(conn, _)
//         |> result.map_error(errors.DatabaseError)
//       }
//       |> result.map_error(fn(err) { case err {
//         pog.TransactionQueryError(err) -> errors.DatabaseError(err)
//         pog.TransactionRolledBack(err) -> todo as "transaction error"
//       }})
//   }
// }

pub fn delete_snippet(ctx: context.Context, id: Int) {
  sql.delete_snippet(id)
  |> db.exec(ctx.db, _)
  |> result.map_error(errors.DatabaseError)
}
