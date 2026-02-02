import envoy
import gleam/erlang/process
import gleam/option
import gleam/result
import mist
import pog
import server/context
import server/router
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let db_pool_name = process.new_name("db_pool")
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
  let assert Ok(pog_config) = pog.url_config(db_pool_name, database_url)
  let assert Ok(_) = pog_config |> pog.pool_size(10) |> pog.start
  let con = pog.named_connection(db_pool_name)

  let secret_key_base =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "changethis")

  let context = context.Context(con, option.None, option.None)
  let handler = router.handle_request(context, _)

  let assert Ok(_) =
    handler
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()
}
