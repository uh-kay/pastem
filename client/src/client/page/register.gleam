import formal/form.{type Form}
import glaze/basecoat/input
import glaze/basecoat/label
import gleam/http/response.{type Response}
import gleam/json
import lustre/attribute
import lustre/element/html
import lustre/event
import rsvp

pub type RegisterForm {
  RegisterForm(username: String, email: String, password: String)
}

pub type Model {
  FormPage(form: Form(RegisterForm))
}

pub type Msg {
  UserSubmittedRegisterForm(result: Result(RegisterForm, Form(RegisterForm)))
  ServerReturnedMessage(Result(Response(String), rsvp.Error))
}

pub fn register_form() {
  form.new({
    use username <- form.field("username", form.parse_string)
    use email <- form.field("email", form.parse_email)
    use password <- form.field("password", form.parse_string)

    form.success(RegisterForm(username, email, password))
  })
}

pub fn register(form: RegisterForm) {
  let url = "/api/register"
  let handler = rsvp.expect_ok_response(ServerReturnedMessage)
  let body =
    json.object([
      #("username", json.string(form.username)),
      #("email", json.string(form.email)),
      #("password", json.string(form.password)),
    ])
  rsvp.post(url, body, handler)
}

pub fn view(model: Model) {
  case model {
    FormPage(form:) -> register_view(form)
  }
}

fn register_view(form) {
  let input_class =
    "border border-gray-400 rounded-md focus:border-transparent block w-full px-3 py-2 mb-2"
  let submitted = fn(fields) {
    form |> form.add_values(fields) |> form.run |> UserSubmittedRegisterForm
  }

  html.form(
    [
      event.on_submit(submitted),
      attribute.method("post"),
      attribute.class("max-w-sm mx-auto"),
    ],
    [
      html.h1([attribute.class("text-xl font-bold my-4")], [
        html.text("Create a New Account"),
      ]),
      label.label([], [html.text("Username")]),
      input.input([
        attribute.class(input_class),
        attribute.name("username"),
        attribute.value(form.field_value(form, "username")),
        attribute.required(True),
      ]),
      label.label([], [html.text("Email")]),
      input.email([
        attribute.class(input_class),
        attribute.name("email"),
        attribute.value(form.field_value(form, "email")),
        attribute.required(True),
      ]),
      label.label([], [html.text("Password")]),
      input.password([
        attribute.class(input_class),
        attribute.name("password"),
        attribute.value(form.field_value(form, "password")),
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
    ],
  )
}
