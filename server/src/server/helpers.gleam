import gleam/json
import gleam/time/timestamp
import wisp

pub fn current_time() -> Int {
  let #(now, _) =
    timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds()
  now
}

pub fn message_response(message, status) {
  json.object([#("message", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}

pub fn json_response(data, item, status) {
  json.object([#(item, data)])
  |> json.to_string
  |> wisp.json_response(status)
}

pub fn error_response(message, status) {
  json.object([#("error", json.string(message))])
  |> json.to_string
  |> wisp.json_response(status)
}
