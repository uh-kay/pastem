import formal/form
import gleam/http.{Post}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/result
import gleam/string_tree
import lustre/attribute
import lustre/element/html
import server/api_route/snippets.{StoreSnippet}
import server/component/input
import server/component/layout
import server/errors.{BadRequest, InternalServerError, NotFound, Unauthorized}
import server/helpers
import shared.{type Snippet}
import wisp

pub fn create_snippet_submit(req) {
  use formdata <- wisp.require_form(req)

  let form = create_snippet_form() |> form.add_values(formdata.values)

  case form.run(form) {
    Ok(data) -> {
      let result = {
        use api_req <- result.try(
          request.to("http://localhost:8000/v1/snippets")
          |> result.replace_error(InternalServerError("invalid URL")),
        )

        let body = snippets.store_snippet_to_json(data) |> json.to_string

        api_req
        |> request.set_method(Post)
        |> request.set_header("content-type", "application/json")
        |> request.set_body(body)
        |> httpc.send()
        |> result.replace_error(InternalServerError("cannot connect to API"))
      }
      case result {
        Ok(_) -> wisp.redirect("/")
        Error(err) -> {
          echo err
          wisp.internal_server_error()
        }
      }
    }
    Error(form) -> {
      create_snippet_view(form)
      |> string_tree.to_string
      |> wisp.html_response(422)
    }
  }
}

fn create_snippet_form() {
  form.new({
    use title <- form.field("title", form.parse_string)
    use content <- form.field("content", form.parse_string)
    use ttl <- form.field("ttl", form.parse_string)

    case ttl {
      "custom" -> {
        use custom_ttl <- form.field("custom-ttl", form.parse_int)
        form.success(StoreSnippet(title:, content:, ttl: custom_ttl))
      }
      _ -> {
        use ttl <- form.field("ttl", form.parse_int)
        form.success(StoreSnippet(title:, content:, ttl:))
      }
    }
  })
}

pub fn create() {
  let form = create_snippet_form()

  create_snippet_view(form)
  |> string_tree.to_string
  |> wisp.html_response(200)
}

fn create_snippet_view(form) {
  html.form([attribute.method("post"), attribute.class("max-w-sm mx-auto")], [
    input.field_input(form, "title", "text", "Title", True),
    html.div([attribute.class("mb-4")], [
      html.label([attribute.class("block mb-2 text-sm")], [html.text("Content")]),
      html.textarea(
        [
          attribute.name("content"),
          attribute.required(True),
          attribute.class("block rounded-md w-full px-3 py-2"),
          attribute.class("border border-gray-400 focus:border-transparent"),
        ],
        "",
      ),
    ]),
    html.legend([attribute.class("block mb-2 text-sm")], [
      html.text("Set expiry"),
    ]),
    html.div([attribute.class("mb-4")], [
      html.label([attribute.class("mr-2")], [
        input.radio("ttl", "1", "mr-2", [attribute.required(True)]),
        html.text("1 hour"),
      ]),
      html.label([attribute.class("mr-2")], [
        input.radio("ttl", "3", "mr-2", []),
        html.text("3 hours"),
      ]),
      html.label([attribute.class("mr-2")], [
        input.radio("ttl", "24", "mr-2", []),
        html.text("1 day"),
      ]),
      input.radio("ttl", "custom", "peer mr-2", []),
      html.label([attribute.for("ttl-custom")], [
        html.text("Custom (hours)"),
      ]),
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
  ])
  |> layout.page_layout_view("Create Snippet", _)
}

pub fn show(id) {
  let result = {
    use api_req <- result.try(
      request.to(helpers.api_url() <> "/snippets/" <> id)
      |> result.replace_error(InternalServerError("invalid URL")),
    )

    use res <- result.try(
      httpc.send(api_req)
      |> result.replace_error(InternalServerError("API connection failed")),
    )

    case res.status >= 200 && res.status < 300 {
      False ->
        case res.status {
          404 -> Error(NotFound("snippet"))
          _ -> Error(InternalServerError("internal server error"))
        }
      True -> {
        json.parse(res.body, shared.snippet_item_decoder())
        |> result.replace_error(InternalServerError("Failed to decode snippet"))
      }
    }
  }

  case result {
    Ok(snippet) -> {
      layout.page_layout_view(snippet.title, snippet_page_view(snippet))
      |> string_tree.to_string
      |> wisp.html_response(200)
    }
    Error(err) -> {
      case err {
        BadRequest(_) -> helpers.html_error_response(400)
        NotFound(_) -> helpers.html_error_response(404)
        Unauthorized -> helpers.html_error_response(401)
        _ -> helpers.html_error_response(500)
      }
    }
  }
}

fn snippet_page_view(snippet: Snippet) {
  html.div([], [
    html.p([], [html.text(int.to_string(snippet.id))]),
  ])
}
