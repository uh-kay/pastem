import gleam/int
import gleam/json.{type Json}
import gleam/string_tree.{type StringTree}
import gleam/time/timestamp
import lustre/attribute
import lustre/element
import lustre/element/html
import wisp.{type Response}

pub fn current_time() -> Int {
  let #(now, _) =
    timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds()
  now
}

pub fn message_response(message: String, status: Int) -> Response {
  json.object([#("message", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}

pub fn json_response(data: Json, item: String, status: Int) -> Response {
  json.object([#(item, data)])
  |> json.to_string
  |> wisp.json_response(status)
}

pub fn error_response(message: String, status: Int) -> Response {
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
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
