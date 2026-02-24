import gleam/option
import pog
import shared

pub type Context {
  Context(
    db: pog.Connection,
    user: option.Option(shared.User),
    snippet: option.Option(shared.Snippet),
  )
}
