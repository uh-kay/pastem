import birdie
import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/string
import server/model/snippet
import server/model/user
import server/router
import server_test
import shared
import wisp/simulate

fn get_token(db) {
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

  let body = simulate.read_body(res)
  let decoder = {
    use token <- decode.field("token", decode.string)
    decode.success(token)
  }

  case json.parse(body, decoder) {
    Ok(token) -> token
    Error(err) -> string.inspect(err)
  }
}

pub fn create_snippet(db, token) {
  let #(priv_directory, ctx) = server_test.setup_test(db)

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

  router.handle_request(ctx, priv_directory, req)
}

pub fn create_snippet_ok_test() {
  use db <- server_test.with_connection()

  let token = get_token(db)
  let res = create_snippet(db, token)

  assert res.status == 201
}

pub fn create_snippet_unauthorized_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

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

  let res = router.handle_request(ctx, priv_directory, req)

  assert res.status == 401
}

pub fn get_snippet_ok_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let token = get_token(db)
  let res = create_snippet(db, token)

  let body = simulate.read_body(res)
  let decoder = {
    use snippet_id <- decode.field("snippet_id", decode.int)
    decode.success(snippet_id)
  }
  let assert Ok(id) = json.parse(body, decoder)

  let req = simulate.request(http.Get, "/v1/snippets/" <> int.to_string(id))
  let res = router.handle_request(ctx, priv_directory, req)
  let body = simulate.read_body(res)

  let decoder = {
    use snippet <- decode.field("snippet", shared.snippet_decoder())
    decode.success(snippet)
  }
  let assert Ok(snippet) = json.parse(body, decoder)

  assert snippet.title == "foo"
  assert snippet.content == "bar"
}

pub fn get_snippet_not_found_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let req = simulate.request(http.Get, "/v1/snippets/67")
  let res = router.handle_request(ctx, priv_directory, req)

  assert res.status == 404

  simulate.read_body(res)
  |> birdie.snap("get snippet not found")
}

pub fn list_snippets_ok_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let token = get_token(db)
  create_snippet(db, token)

  let req = simulate.request(http.Get, "/v1/snippets")
  let res = router.handle_request(ctx, priv_directory, req)

  assert res.status == 200
}

pub fn list_snippets_not_found_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let req = simulate.request(http.Get, "/v1/snippets")
  let res = router.handle_request(ctx, priv_directory, req)

  assert res.status == 404
}

pub fn update_snippet_ok_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let token = get_token(db)
  let res = create_snippet(db, token)

  let body = simulate.read_body(res)
  let decoder = {
    use snippet_id <- decode.field("snippet_id", decode.int)
    decode.success(snippet_id)
  }
  let assert Ok(id) = json.parse(body, decoder)

  let req =
    simulate.request(http.Patch, "/v1/snippets/" <> int.to_string(id))
    |> simulate.json_body(
      json.object([
        #("title", json.string("hello")),
        #("content", json.string("world")),
      ]),
    )
    |> simulate.header("content-type", "application/json")
    |> simulate.header("authorization", "Bearer " <> token)

  let res = router.handle_request(ctx, priv_directory, req)

  assert res.status == 200
  let assert Ok(snippet) = snippet.get_snippet(ctx, id)

  // original = {"title": "foo", "content":"bar"}
  assert snippet.title == "hello"
  assert snippet.content == "world"
}

pub fn delete_snippet_ok_test() {
  use db <- server_test.with_connection()
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let token = get_token(db)
  let res = create_snippet(db, token)

  let body = simulate.read_body(res)
  let decoder = {
    use snippet_id <- decode.field("snippet_id", decode.int)
    decode.success(snippet_id)
  }
  let assert Ok(id) = json.parse(body, decoder)

  let req =
    simulate.request(http.Delete, "/v1/snippets/" <> int.to_string(id))
    |> simulate.header("authorization", "Bearer " <> token)

  let res = router.handle_request(ctx, priv_directory, req)

  let assert Error(_) = snippet.get_snippet(ctx, id)
  assert res.status == 200
}
