import envoy
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/result
import gleam/string_tree.{type StringTree}
import gleam/time/timestamp
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import server/component/layout
import wisp.{type Request, type Response}

// Returns the current time in UNIX seconds.
pub fn current_time() -> Int {
  let #(now, _) =
    timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds()
  now
}

pub fn api_url() -> String {
  result.unwrap(envoy.get("API_URL"), "")
}

pub fn json_response(
  key: List(String),
  value: List(Json),
  status: Int,
) -> Response {
  list.zip(key, value)
  |> json.object
  |> json.to_string
  |> wisp.json_response(status)
}

pub fn html_response(
  req: Request,
  title: String,
  content: Element(a),
  status: Int,
) -> Response {
  layout.page_layout_view(req, title, content)
  |> string_tree.to_string
  |> wisp.html_response(status)
}

pub fn error_response(message: String, status: Int) -> Response {
  json_response(["error"], [json.string(message)], status)
}

pub fn internal_server_error() {
  error_response("internal server error", 500)
}

pub fn unauthorized() {
  error_response("unauthorized", 401)
}

pub fn html_error_response(status: Int) -> Response {
  error_page_view(int.to_string(status))
  |> string_tree.to_string
  |> wisp.html_response(status)
}

fn error_page_view(status: String) -> StringTree {
  html.div([], [html.img([attribute.src("https://http.cat/images/" <> status)])])
  |> element.to_document_string_tree
}

pub fn query_to_int(queries, key, fallback) {
  list.key_find(queries, key)
  |> result.unwrap("")
  |> int.parse()
  |> result.unwrap(fallback)
}
