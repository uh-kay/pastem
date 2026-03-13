import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp
import pog
import server/context
import server/db
import server/error
import server/helper
import server/sql
import server/validator/validator
import shared
import wisp

pub type SnippetError {
  SnippetLookupError(pog.QueryError)
  SnippetNotFoundError(id: Int)
  NoSnippetAvailableError
  BadRequest(String)
  Unauthorized
}

pub fn validate_title(validator: validator.Validator, title: String) {
  let len = string.length(title)

  validator
  |> validator.check(string.is_empty(title), "title", "must be provided")
  |> validator.check(len < 1, "title", "must be at least 1 byte long")
  |> validator.check(len > 255, "title", "must not be more than 255 bytes long")
}

pub fn validate_content(validator: validator.Validator, content: String) {
  let len = string.length(content)

  validator
  |> validator.check(string.is_empty(content), "content", "must be provided")
  |> validator.check(len < 1, "content", "must be at least 1 byte long")
  |> validator.check(
    len > 4096,
    "content",
    "must not be more than 4096 bytes long",
  )
}

pub fn validate_ttl(validator: validator.Validator, ttl: Int) {
  validator
  |> validator.check(ttl < 1, "ttl", "must be at least 1 hour")
  |> validator.check(
    ttl > 7 * 24,
    "ttl",
    "must not be more than " <> int.to_string(7 * 24) <> " hours",
  )
}

pub fn list_snippets(ctx: context.Context, limit, offset) {
  case
    sql.get_snippets(helper.current_time(), limit, offset)
    |> db.query(ctx.db, _)
  {
    Ok(pog.Returned(0, _)) -> Error(NoSnippetAvailableError)
    Ok(pog.Returned(_count, rows)) ->
      Ok(
        list.map(rows, fn(row: sql.GetSnippets) {
          shared.Snippet(
            row.id,
            row.author_id,
            row.author_name,
            row.title,
            row.content,
            row.version,
            row.expires_at,
            row.updated_at,
            row.created_at,
          )
        }),
      )
    Error(err) -> Error(SnippetLookupError(err))
  }
}

pub fn get_snippet(
  ctx: context.Context,
  id: Int,
) -> Result(shared.Snippet, SnippetError) {
  use snippet <- result.try(
    sql.get_snippet(id, helper.current_time())
    |> db.query(ctx.db, _)
    |> result.map_error(SnippetLookupError),
  )

  list.first(snippet.rows)
  |> result.replace_error(SnippetNotFoundError(id))
  |> result.map(fn(row) {
    shared.Snippet(
      id: row.id,
      author_id: row.author_id,
      author_name: row.author_name,
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
      use snippet <- result.try(
        timestamp.to_unix_seconds_and_nanoseconds(expires_at).0
        |> sql.create_snippet(
          user.id,
          title,
          content,
          _,
          helper.current_time(),
          helper.current_time(),
        )
        |> db.query(ctx.db, _)
        |> result.map_error(SnippetLookupError),
      )

      list.first(snippet.rows)
      |> result.replace_error(NoSnippetAvailableError)
      |> result.map(fn(row) { row.id })
    }
    option.None -> Error(Unauthorized)
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
    option.None, option.None -> Error(BadRequest("missing title and content"))
    option.None, option.Some(content) ->
      sql.update_snippet(old_snippet.title, content, id, old_snippet.version)
      |> db.exec(ctx.db, _)
      |> result.map_error(SnippetLookupError)
    option.Some(title), option.None ->
      sql.update_snippet(title, old_snippet.content, id, old_snippet.version)
      |> db.exec(ctx.db, _)
      |> result.map_error(SnippetLookupError)
    option.Some(title), option.Some(content) ->
      sql.update_snippet(title, content, id, old_snippet.version)
      |> db.exec(ctx.db, _)
      |> result.map_error(SnippetLookupError)
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
//       Error(error.BadRequest("missing title and content"))
//     _, _ ->
//       {
//         use conn <- pog.transaction(ctx.db)

//         sql.update_snippet(id, title, content)
//         |> db.exec(conn, _)
//         |> result.map_error(error.DatabaseError)
//       }
//       |> result.map_error(fn(err) { case err {
//         pog.TransactionQueryError(err) -> error.DatabaseError(err)
//         pog.TransactionRolledBack(err) -> todo as "transaction error"
//       }})
//   }
// }

pub fn delete_snippet(ctx: context.Context, id: Int) {
  sql.delete_snippet(id)
  |> db.exec(ctx.db, _)
  |> result.map_error(SnippetLookupError)
}

pub fn get_snippet_count(ctx: context.Context) -> Result(Int, SnippetError) {
  sql.get_snippet_count(helper.current_time())
  |> db.query(ctx.db, _)
  |> result.map_error(SnippetLookupError)
  |> result.map(fn(count) {
    case list.first(count.rows) {
      Ok(count) -> count.count
      Error(_) -> 0
    }
  })
}

pub fn handle_error(req: wisp.Request, err: SnippetError) {
  case err {
    SnippetLookupError(err) -> {
      error.format_log(req, error.pog_error_to_string(err)) |> wisp.log_error()
      helper.internal_server_error()
    }
    SnippetNotFoundError(id:) -> {
      error.format_log(
        req,
        "snippet with id: " <> int.to_string(id) <> "not found",
      )
      |> wisp.log_warning()
      helper.error_response("snippet not found", 404)
    }
    NoSnippetAvailableError -> {
      error.format_log(req, "no snippet available")
      |> wisp.log_warning()
      helper.error_response("snippet not found", 404)
    }
    BadRequest(msg) -> {
      error.format_log(req, msg) |> wisp.log_warning()
      helper.error_response(msg, 400)
    }
    Unauthorized -> {
      error.format_log(req, "unauthorized") |> wisp.log_warning()
      helper.unauthorized()
    }
  }
}
