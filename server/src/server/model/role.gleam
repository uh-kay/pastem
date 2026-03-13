import gleam/list
import gleam/result
import pog
import server/context
import server/db
import server/error
import server/helper
import server/sql
import shared
import wisp

pub type RoleError {
  RoleLookupError(pog.QueryError)
  RoleNotFound(role_name: String)
}

pub fn get_role(ctx: context.Context, role_name: String) {
  use role <- result.try(
    sql.get_role_by_name(role_name)
    |> db.query(ctx.db, _)
    |> result.map_error(RoleLookupError),
  )

  list.first(role.rows)
  |> result.replace_error(RoleNotFound(role_name))
  |> result.map(fn(row) {
    shared.Role(
      id: row.id,
      name: row.name,
      level: row.level,
      description: row.description,
      created_at: row.created_at,
    )
  })
}

pub fn handle_error(req: wisp.Request, err: RoleError) -> wisp.Response {
  case err {
    RoleLookupError(err) -> {
      error.format_log(req, error.pog_error_to_string(err)) |> wisp.log_error()
      helper.internal_server_error()
    }
    RoleNotFound(role_name:) -> {
      error.format_log(req, "role with name: " <> role_name <> " not found")
      |> wisp.log_warning()
      helper.error_response("role not found", 404)
    }
  }
}
