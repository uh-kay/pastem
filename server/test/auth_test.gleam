import birdie
import gleam/http
import gleam/json
import server/model/user
import server/router
import server_test
import wisp/simulate

pub fn create_token_ok_test() {
  use db <- server_test.with_connection()

  test_create_token(db, "foo@example.com", "password", 201)
}

pub fn create_token_invalid_password_test() {
  use db <- server_test.with_connection()

  test_create_token(db, "foo@example.com", "zoinks", 401)
}

pub fn create_token_invalid_email_test() {
  use db <- server_test.with_connection()

  test_create_token(db, "bar@example.com", "password", 404)
}

fn test_create_token(db, email, password, expected_status) -> Nil {
  let #(priv_directory, ctx) = server_test.setup_test(db)

  let assert Ok(user_password) = user.hash_password("password")
  let assert Ok(_) =
    user.create_user(ctx, "foo", "foo@example.com", user_password)

  let req =
    simulate.request(http.Post, "/v1/tokens")
    |> simulate.json_body(
      json.object([
        #("email", json.string(email)),
        #("password", json.string(password)),
      ]),
    )

  let res = router.handle_request(ctx, priv_directory, req)

  assert res.status == expected_status
}

fn register(db, req) {
  let #(priv_directory, ctx) = server_test.setup_test(db)

  router.handle_request(ctx, priv_directory, req)
}

pub fn register_ok_test() {
  use db <- server_test.with_connection()

  let req =
    simulate.request(http.Post, "/v1/register")
    |> simulate.json_body(
      json.object([
        #("username", json.string("foo")),
        #("email", json.string("foo@example.com")),
        #("password", json.string("password")),
      ]),
    )

  let res = register(db, req)

  assert res.status == 201

  simulate.read_body(res)
  |> birdie.snap("create user ok")
}

pub fn register_username_conflict_test() {
  use db <- server_test.with_connection()

  let req =
    simulate.request(http.Post, "/v1/register")
    |> simulate.json_body(
      json.object([
        #("username", json.string("foo")),
        #("email", json.string("foo@example.com")),
        #("password", json.string("password")),
      ]),
    )

  register(db, req)

  let req =
    simulate.request(http.Post, "/v1/register")
    |> simulate.json_body(
      json.object([
        #("username", json.string("foo")),
        #("email", json.string("foo2@example.com")),
        #("password", json.string("password")),
      ]),
    )

  let res = register(db, req)

  simulate.read_body(res)
  |> birdie.snap("create user username conflict")
}

pub fn register_email_conflict_test() {
  use db <- server_test.with_connection()

  let req =
    simulate.request(http.Post, "/v1/register")
    |> simulate.json_body(
      json.object([
        #("username", json.string("foo")),
        #("email", json.string("foo@example.com")),
        #("password", json.string("password")),
      ]),
    )

  register(db, req)

  let req =
    simulate.request(http.Post, "/v1/register")
    |> simulate.json_body(
      json.object([
        #("username", json.string("foo2")),
        #("email", json.string("foo@example.com")),
        #("password", json.string("password")),
      ]),
    )

  let res = register(db, req)

  simulate.read_body(res)
  |> birdie.snap("create user email conflict")
}
