import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp
import pog
import server/context
import server/db
import server/errors
import server/sql
import shared

pub fn list_snippets(ctx: context.Context) {
  case sql.get_snippets(20, 0) |> db.query(ctx.db, _) {
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
            row.expires_at,
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
      expires_at: row.expires_at,
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
  sql.create_snippet(2, title, content, expires_at)
  |> db.exec(ctx.db, _)
  |> result.map_error(errors.DatabaseError)
}

pub fn update_snippet(
  ctx: context.Context,
  title: option.Option(String),
  content: option.Option(String),
  old_title: String,
  old_content,
  id: Int,
) {
  case title, content {
    option.None, option.None ->
      Error(errors.BadRequest("missing title and content"))
    _, _ -> {
      sql.update_snippet(
        option.unwrap(title, old_title),
        option.unwrap(content, old_content),
        id,
      )
      |> db.exec(ctx.db, _)
      |> result.map_error(errors.DatabaseError)
    }
  }
}

pub fn delete_snippet(ctx: context.Context, id: Int) {
  sql.delete_snippet(id)
  |> db.exec(ctx.db, _)
  |> result.map_error(errors.DatabaseError)
}
