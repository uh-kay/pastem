import gleam/json
import wisp.{type Response}

pub fn health() -> Response {
  json.object([#("status", json.string("available"))])
  |> json.to_string
  |> wisp.json_response(200)
}
