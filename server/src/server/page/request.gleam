import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import server/errors.{InternalServerError}
import server/helpers

pub type Header {
  Header(key: String, value: String)
}

pub fn send_request(
  path path: String,
  body body: option.Option(String),
  method method: http.Method,
  headers headers: List(Header),
) {
  use api_req <- result.try(
    request.to(helpers.api_url() <> path)
    |> result.replace_error(InternalServerError("invalid URL")),
  )

  api_req
  |> request.set_method(method)
  |> fn(api_req) {
    case body {
      Some(body) -> request.set_body(api_req, body)
      None -> api_req
    }
  }
  |> fn(api_req) {
    list.fold(headers, api_req, fn(acc_req, header) {
      request.set_header(acc_req, header.key, header.value)
    })
  }
  |> httpc.send()
  |> result.replace_error(InternalServerError("cannot connect to API"))
}
