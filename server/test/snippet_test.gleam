import birdie
import gleam/dynamic/decode
import gleam/http
import gleam/json
import gleam/string
import server/model/user
import server/router
import server_test
import wisp
import wisp/simulate

pub fn create_snippet_ok_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let assert Ok(password) = user.hash_password("password")
  let assert Ok(_) = user.create_user(ctx, "foo", "foo@example.com", password)

  let req =
    simulate.json_body(
      simulate.request(http.Post, "/v1/tokens"),
      json.object([
        #("email", json.string("foo@example.com")),
        #("password", json.string("password")),
      ]),
    )

  let res = router.handle_request(ctx, priv_directory, req)

  let token = case res.body {
    wisp.Text(body) -> {
      let decoder = {
        use token <- decode.field("token", decode.string)
        decode.success(token)
      }
      case json.parse(body, decoder) {
        Ok(token) -> token
        Error(err) -> string.inspect(err)
      }
    }
    _ -> "expected text body: found something else"
  }

  let req =
    simulate.request(http.Post, "/v1/snippets")
    |> simulate.json_body(
      json.object([
        #("title", json.string("foo")),
        #("content", json.string("bar")),
        #("ttl", json.int(1)),
      ]),
    )
    |> simulate.header("content-type", "application/json")
    |> simulate.header("authorization", "Bearer " <> token)

  let res = router.handle_request(ctx, priv_directory, req)

  assert res.status == 201

  case res.body {
    wisp.Text(body) -> body
    _ -> "expected text body: found something else"
  }
  |> birdie.snap("create snippet ok")
}
