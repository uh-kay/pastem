import cigogne
import cigogne/config
import envoy
import gleam/erlang/process
import gleam/int
import gleam/option
import gleam/otp/static_supervisor.{OneForOne}
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import logging
import mist
import pog
import server/context
import server/router
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  wisp.configure_logger()

  let pog_config = pog_config()
  let ctx =
    context.Context(
      pog.named_connection(pog_config.pool_name),
      option.None,
      option.None,
    )
  let assert Ok(priv_directory) = wisp.priv_directory("server")

  let db_spec = pog_config |> pog.supervised
  let server_spec = mist_config(ctx, priv_directory) |> mist.supervised

  let assert Ok(_) =
    static_supervisor.new(OneForOne)
    |> static_supervisor.add(db_spec)
    |> static_supervisor.add(server_spec)
    |> static_supervisor.start()

  logging.log(
    logging.Info,
    timestamp.to_rfc3339(timestamp.system_time(), calendar.local_offset())
      <> " server started",
  )

  process.sleep(500)

  let assert Ok(_) = migrate_db()

  process.sleep_forever()
}

fn mist_config(ctx, priv_directory) {
  let secret_key_base =
    result.unwrap(envoy.get("SECRET_KEY_BASE"), "changethis")

  let static_directory = priv_directory <> "/static"

  let port_str = result.unwrap(envoy.get("PORT"), "8000")
  let assert Ok(port) = int.parse(port_str)

  router.handle_request(ctx, static_directory, _)
  |> wisp_mist.handler(secret_key_base)
  |> mist.new
  |> mist.port(port)
  |> mist.bind("0.0.0.0")
}

pub fn pog_config() -> pog.Config {
  let db_pool_name = process.new_name("db_pool")
  let assert Ok(database_url) = envoy.get("DATABASE_URL")
  let assert Ok(pog_config) = pog.url_config(db_pool_name, database_url)
  pog_config |> pog.pool_size(10)
}

fn migrate_db() {
  use config <- result.try(
    config.get("server") |> result.map_error(cigogne.ConfigError),
  )

  use engine <- result.try(cigogne.create_engine(config))
  cigogne.apply_all(engine)
}
