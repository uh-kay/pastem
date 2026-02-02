import gleam/list
import gleam/result
import server/context
import server/db
import server/errors
import server/sql
import shared

pub fn get_role(ctx: context.Context, role_name: String) {
  use role <- result.try(
    sql.get_role_by_name(role_name)
    |> db.query(ctx.db, _)
    |> result.map_error(errors.DatabaseError),
  )

  list.first(role.rows)
  |> result.replace_error(errors.NotFound("role"))
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
