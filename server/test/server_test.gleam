import gleam/option.{None}
import gleeunit
import global_value
import logging
import pog
import server
import server/context.{Context}
import wisp

pub fn main() -> Nil {
  logging.set_level(logging.Error)

  gleeunit.main()
}

pub fn setup_test(db) {
  let assert Ok(priv_directory) = wisp.priv_directory("server")
  let static_directory = priv_directory <> "/static"

  let ctx = Context(db: db, user: None, snippet: None)

  #(static_directory, ctx)
}

pub fn with_connection(test_case: fn(pog.Connection) -> a) -> Nil {
  let pool = global_connection_pool()
  let assert Error(pog.TransactionRolledBack(Nil)) =
    pog.transaction(pool, fn(conn) {
      test_case(conn)
      Error(Nil)
    })
  Nil
}

fn global_connection_pool() -> pog.Connection {
  global_value.create_with_unique_name(
    "server_test.global_connection_pool",
    fn() { new_pool() },
  )
}

fn new_pool() -> pog.Connection {
  let config = server.pog_config()
  let assert Ok(_) = pog.start(config)
  pog.named_connection(config.pool_name)
}
