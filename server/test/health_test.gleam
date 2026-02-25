import birdie
import gleam/http
import gleam/option.{None}
import server/context
import server/router
import server_test
import wisp
import wisp/simulate

pub fn health_handler_test() {
  use db <- server_test.with_connection()

  let assert Ok(priv_directory) = wisp.priv_directory("server")
  let static_directory = priv_directory <> "/static"

  let ctx = context.Context(db: db, user: None, snippet: None)
  let req = simulate.request(http.Get, "/v1/health")
  let res = router.handle_request(ctx, static_directory, req)

  assert res.status == 200

  simulate.read_body(res)
  |> birdie.snap("health handler ok")
}
