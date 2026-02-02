import gleam/option
import pog.{type Connection}
import shared

pub type Context {
  Context(
    db: Connection,
    user: option.Option(shared.User),
    snippet: option.Option(shared.Snippet),
  )
}
