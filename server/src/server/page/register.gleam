import formal/form
import gleam/http
import gleam/json
import gleam/option
import gleam/result
import lustre/attribute
import lustre/element/html
import server/api_route/auth
import server/component/input
import server/errors
import server/helpers
import server/page/request
import wisp

pub fn register_page(req) {
  let form = register_form()

  helpers.html_response(req, register_view(form), 200)
}

fn register_form() {
  form.new({
    use username <- form.field("username", form.parse_string)
    use email <- form.field("email", form.parse_email)
    use password <- form.field("password", form.parse_string)

    form.success(auth.Register(username:, email:, password:))
  })
}

fn register_view(form) {
  html.form([attribute.method("post"), attribute.class("max-w-sm mx-auto")], [
    html.h1([attribute.class("text-xl font-bold my-4")], [
      html.text("Create a New Account"),
    ]),
    input.field_input(form, "username", "text", "Username", [
      attribute.required(True),
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

type RegisterError {
  CannotParseForm(form.Form(auth.Register))
  RegisterRequestFailed(errors.AppError)
}

pub fn register_submit(req) {
  use wisp.FormData(values:, files: _) <- wisp.require_form(req)

  let result = {
    use data <- result.try(
      register_form()
      |> form.add_values(values)
      |> form.run
      |> result.map_error(CannotParseForm),
    )

    let body = auth.register_to_json(data) |> json.to_string

    request.send_request("/register", option.Some(body), http.Post, [
      request.Header("content-type", "application/json"),
    ])
    |> result.map_error(RegisterRequestFailed)
  }

  case result {
    Ok(_) -> wisp.redirect("/login")
    Error(CannotParseForm(form)) ->
      helpers.html_response(req, register_view(form), 422)
    Error(RegisterRequestFailed(_)) -> helpers.html_error_response(500)
  }
}
