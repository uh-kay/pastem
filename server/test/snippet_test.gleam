import birdie
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option
import gleeunit/should
import helpers
import logging
import pog
import server/context
import server/router
import wisp/simulate

pub type Logger {
  Logger(log: fn(String) -> Nil)
}

fn check_request(
  db,
  method,
  auth: Bool,
  body: option.Option(json.Json),
  path,
  expected_status,
) {
  let ctx = context.Context(db: db, user: option.None, snippet: option.None)
  let req = case auth {
    True ->
      simulate.request(method, path)
      |> request.set_header("authorization", "Bearer test")
    False -> simulate.request(method, path)
  }
  let req = case body {
    option.Some(json) -> simulate.json_body(req, json)
    option.None -> req
  }

  let res = router.handle_request(ctx, todo, req)

  // set log level to critical to suppress error
  logging.set_level(logging.Critical)

  res.status |> should.equal(expected_status)

  simulate.read_body(res)
}

pub fn list_snippets_test() {
  helpers.mock_query(Ok(1))
  |> check_request(http.Get, False, option.None, "/api/snippets", 200)
  |> birdie.snap("list snippets success")
}

pub fn list_snippets_not_found_test() {
  helpers.mock_query(Ok(0))
  |> check_request(http.Get, False, option.None, "/api/snippets", 404)
  |> birdie.snap("list snippets not found")
}

pub fn list_snippets_internal_err_test() {
  helpers.mock_query(Error(pog.ConnectionUnavailable))
  |> check_request(http.Get, False, option.None, "/api/snippets", 500)
  |> birdie.snap("list snippets internal error")
}

pub fn get_snippet_test() {
  helpers.mock_query(Ok(1))
  |> check_request(http.Get, False, option.None, "/api/snippets/1", 200)
  |> birdie.snap("get snippet success")
}

pub fn get_snippet_not_found_test() {
  helpers.mock_query(Ok(0))
  |> check_request(http.Get, False, option.None, "/api/snippets/1", 404)
  |> birdie.snap("get snippet not found")
}

pub fn get_snippet_internal_err_test() {
  helpers.mock_query(Error(pog.ConnectionUnavailable))
  |> check_request(http.Get, False, option.None, "/api/snippets/1", 500)
  |> birdie.snap("get snippet internal error")
}

pub fn create_snippet_test() {
  let body =
    json.object([
      #("title", json.string("test")),
      #("content", json.string("test")),
      #("ttl", json.int(100)),
    ])

  helpers.mock_query(Ok(0))
  |> check_request(http.Post, True, option.Some(body), "/api/snippets", 201)
  |> birdie.snap("create snippet success")
}

pub fn create_snippet_incomplete_json_test() {
  let body =
    json.object([
      #("title", json.string("test")),
      #("content", json.string("test")),
    ])

  helpers.mock_query(Ok(0))
  |> check_request(http.Post, True, option.Some(body), "/api/snippets", 400)
  |> birdie.snap("create snippet incomplete json")
}

pub fn create_snippet_internal_err_test() {
  let body =
    json.object([
      #("title", json.string("test")),
      #("content", json.string("test")),
      #("ttl", json.int(100)),
    ])

  helpers.mock_query(Error(pog.ConnectionUnavailable))
  |> check_request(http.Post, True, option.Some(body), "/api/snippets", 500)
  |> birdie.snap("create snippet internal error")
}
