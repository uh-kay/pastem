import gleam/option
import server/db
import shared

pub type Context {
  Context(
    db: db.Connection,
    user: option.Option(shared.User),
    snippet: option.Option(shared.Snippet),
  )
}
