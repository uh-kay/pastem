import formal/form
import gleam/dynamic/decode
import gleam/http.{Post}
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre/attribute
import lustre/element/html
import server/api_route/auth.{CreateToken}
import server/component/input
import server/errors.{InternalServerError}
import server/helpers
import wisp

type LoginError {
  CouldNotParseForm(form.Form(auth.CreateToken))
  TokenRequestFailed(errors.AppError)
  CouldNotDecodeToken(json.DecodeError)
}

pub fn login_page(req) {
  let form = login_form()

  helpers.html_response(req, login_view(form), 200)
}

fn login_view(form) {
  html.form([attribute.method("post"), attribute.class("max-w-sm mx-auto")], [
    html.h1([attribute.class("text-xl font-bold my-4")], [
      html.text("Login to Your Account"),
    ]),
    input.field_input(form, "email", "text", "Email", [attribute.required(True)]),
    input.field_input(form, "password", "password", "Password", [
      attribute.required(True),
    ]),
    html.button(
      [
        attribute.type_("submit"),
        attribute.class(
          "bg-blue-500 px-4 py-2 rounded-md text-white hover:bg-blue-600",
        ),
      ],
      [html.text("Login")],
    ),
  ])
}

pub fn login_form() {
  form.new({
    use email <- form.field("email", form.parse_email)
    use password <- form.field("password", form.parse_string)

    form.success(CreateToken(email:, password:))
  })
}

type Token {
  Token(token: String)
}

fn token_decoder() -> decode.Decoder(Token) {
  use token <- decode.field("token", decode.string)
  decode.success(Token(token:))
}

pub fn login_submit(req) {
  use wisp.FormData(values:, files: _) <- wisp.require_form(req)

  let result = {
    use data <- result.try(
      login_form()
      |> form.add_values(values)
      |> form.run
      |> result.map_error(CouldNotParseForm),
    )

    let body = auth.create_token_to_json(data) |> json.to_string
    let headers = [Header(key: "Content-Type", value: "application/json")]

    use res <- result.try(
      send_request("/tokens", option.Some(body), Post, headers)
      |> result.map_error(TokenRequestFailed),
    )

    use token <- result.try(
      json.parse(res.body, token_decoder())
      |> result.map_error(CouldNotDecodeToken),
    )

    Ok(token)
  }

  case result {
    Ok(token) ->
      wisp.redirect("/")
      |> wisp.set_cookie(
        req,
        "auth_token",
        token.token,
        wisp.Signed,
        365 * 24 * 60 * 60,
      )

    Error(CouldNotParseForm(form)) ->
      helpers.html_response(req, login_view(form), 422)
    Error(_) -> wisp.internal_server_error()
  }
}

pub type Header {
  Header(key: String, value: String)
}

pub fn send_request(
  path path: String,
  body body: Option(String),
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
