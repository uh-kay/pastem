import birdie
import gleeunit/should
import server/routes/health
import wisp

pub fn health_handler_test() {
  let res = health.health()

  res.status |> should.equal(200)

  case res.body {
    wisp.Text(text) -> text
    _ -> "error: expected text body, got something else"
  }
  |> birdie.snap("health handler")
}
