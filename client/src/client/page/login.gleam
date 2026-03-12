import formal/form.{type Form}
import glaze/basecoat/button
import glaze/basecoat/input
import glaze/basecoat/label
import gleam/dynamic/decode
import gleam/json
import lustre/attribute
import lustre/effect
import lustre/element/html
import lustre/event
import rsvp.{type Error}

pub type LoginForm {
  LoginForm(email: String, password: String)
}

pub type Model {
  FormPage(form: Form(LoginForm))
}

pub type Msg {
  UserSubmittedLoginForm(result: Result(LoginForm, Form(LoginForm)))
  ServerReturnedToken(Result(Token, Error))
}

pub type LoginFlow

pub fn login_form() {
  form.new({
    use email <- form.field("email", form.parse_email)
    use password <- form.field("password", form.parse_string)
    form.success(LoginForm(email:, password:))
  })
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    UserSubmittedLoginForm(result: Ok(login)) -> {
      let effect = do_login(login)
      #(model, effect)
    }
    UserSubmittedLoginForm(result: Error(form)) -> #(
      FormPage(form),
      effect.none(),
    )
    ServerReturnedToken(_) -> #(model, effect.none())
  }
}

pub type Token {
  Token(token: String)
}

fn token_decoder() -> decode.Decoder(Token) {
  use token <- decode.field("token", decode.string)
  decode.success(Token(token:))
}

pub fn do_login(login_form: LoginForm) {
  let url = "/v1/tokens"
  let handler = rsvp.expect_json(token_decoder(), ServerReturnedToken)
  let body =
    json.object([
      #("email", json.string(login_form.email)),
      #("password", json.string(login_form.password)),
    ])
  rsvp.post(url, body, handler)
}

pub fn view(model: Model) {
  case model {
    FormPage(form:) -> form_view(form)
  }
}

fn form_view(form) {
  let input_class =
    "border border-gray-400 rounded-md focus:border-transparent block w-full px-3 py-2 mb-2"
  let submitted = fn(fields) {
    form |> form.add_values(fields) |> form.run |> UserSubmittedLoginForm
  }

  html.form([event.on_submit(submitted), attribute.class("max-w-sm mx-auto")], [
    html.h1([attribute.class("text-xl font-bold my-4")], [
      html.text("Login to Your Account"),
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
    button.submit(
      [
        attribute.class(
          "bg-blue-500 px-4 py-2 rounded-md text-white hover:bg-blue-600 mt-2",
        ),
      ],
      [html.text("Login")],
    ),
  ])
}
