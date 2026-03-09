import client/component/input
import formal/form.{type Form}
import glaze/basecoat/textarea
import gleam/http/response.{type Response}
import gleam/json
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element/html
import lustre/event
import rsvp

pub type Model {
  FormPage(form: Form(CreateSnippetForm))
}

pub type Msg {
  ServerSavedSnippet(Result(Response(String), rsvp.Error))
  UserSubmittedCreateForm(Result(CreateSnippetForm, Form(CreateSnippetForm)))
}

pub type CreateSnippetForm {
  CreateSnippetForm(title: String, content: String, ttl: Int)
}

pub fn create_snippet_to_json(create_snippet: CreateSnippetForm) -> json.Json {
  let CreateSnippetForm(title:, content:, ttl:) = create_snippet
  json.object([
    #("title", json.string(title)),
    #("content", json.string(content)),
    #("ttl", json.int(ttl)),
  ])
}

pub fn create_snippet_form() {
  form.new({
    use title <- form.field("title", form.parse_string)
    use content <- form.field("content", form.parse_string)
    use ttl <- form.field("ttl", form.parse_string)

    case ttl {
      "custom" -> {
        use custom_ttl <- form.field("custom-ttl", form.parse_int)
        form.success(CreateSnippetForm(title:, content:, ttl: custom_ttl))
      }
      _ -> {
        use ttl <- form.field("ttl", form.parse_int)
        form.success(CreateSnippetForm(title:, content:, ttl:))
      }
    }
  })
}

pub fn save_snippet(snippet) -> Effect(Msg) {
  let body = create_snippet_to_json(snippet)
  let url = "/api/snippets"

  rsvp.post(url, body, rsvp.expect_ok_response(ServerSavedSnippet))
}

pub fn view(model: Model) {
  case model {
    FormPage(form) -> create_snippet_view(form)
  }
}

fn create_snippet_view(form) {
  let submitted = fn(fields) {
    form |> form.add_values(fields) |> form.run |> UserSubmittedCreateForm
  }

  html.form(
    [
      event.on_submit(submitted),
      attribute.method("post"),
      attribute.class("max-w-sm mx-auto"),
    ],
    [
      html.h1([attribute.class("text-xl font-bold my-4")], [
        html.text("Create a New Snippet"),
      ]),
      html.label([attribute.class("block mb-2 text-sm")], [html.text("Title")]),
      html.input([
        attribute.class(
          "border border-gray-400 rounded-md focus:border-transparent block w-full px-3 py-2 mb-2",
        ),
        attribute.name("title"),
        attribute.value(form.field_value(form, "title")),
        attribute.required(True),
      ]),
      html.div([attribute.class("mb-4")], [
        html.label([attribute.class("block mb-2 text-sm")], [
          html.text("Content"),
        ]),
        textarea.textarea(
          [
            attribute.class(
              "block rounded-md w-full px-3 py-2 border border-gray-400 focus:border-transparent",
            ),
            attribute.name("content"),
            attribute.required(True),
          ],
          "",
        ),
      ]),
      html.legend([attribute.class("block mb-2 text-sm")], [
        html.text("Set expiry"),
      ]),
      html.div([attribute.class("mb-4")], [
        input.radio("ttl", "1", "mr-2", [attribute.required(True)]),
        html.label([attribute.class("mr-2")], [html.text("1 hour")]),
        input.radio("ttl", "3", "mr-2", []),
        html.label([attribute.class("mr-2")], [html.text("3 hours")]),
        input.radio("ttl", "24", "mr-2", []),
        html.label([attribute.class("mr-2")], [html.text("1 day")]),
        input.radio("ttl", "custom", "peer mr-2", []),
        html.label([attribute.for("ttl-custom")], [html.text("Custom (hours)")]),
        html.input([
          attribute.type_("number"),
          attribute.name("custom-ttl"),
          attribute.min("1"),
          attribute.max("168"),
          attribute.class("hidden mt-2 rounded-md px-3 py-2 peer-checked:flex"),
          attribute.class("border border-gray-400 focus:border-transparent"),
        ]),
      ]),
      html.button(
        [
          attribute.type_("submit"),
          attribute.class("border border-transparent rounded-lg px-4 py-2"),
          attribute.class("text-white bg-blue-500 hover:bg-blue-600"),
        ],
        [
          html.text("Submit"),
        ],
      ),
    ],
  )
}
