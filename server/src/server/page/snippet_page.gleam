import formal/form.{type Form}
import gleam/http.{Post}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string_tree
import lustre/attribute
import lustre/element/html
import server/component/layout
import server/errors.{BadRequest, InternalServerError, NotFound, Unauthorized}
import server/helpers
import server/routes/snippets.{StoreSnippet}
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
          |> result.replace_error(InternalServerError("internal server error")),
        )

        let body = snippets.store_snippet_to_json(data) |> json.to_string

        api_req
        |> request.set_method(Post)
        |> request.set_header("content-type", "application/json")
        |> request.set_body(body)
        |> httpc.send()
        |> result.replace_error(InternalServerError("internal server error"))
      }
      case result {
        Ok(_) -> wisp.redirect("/")
        Error(err) -> {
          echo err
          wisp.internal_server_error()
        }
      }
    }
    Error(err) -> {
      echo err
      wisp.internal_server_error()
    }
  }
}

fn create_snippet_form() {
  form.new({
    use title <- form.field("title", form.parse_string)
    use content <- form.field("content", form.parse_string)
    use ttl <- form.field("ttl", form.parse_int)

    form.success(StoreSnippet(title:, content:, ttl:))
  })
}

pub fn create() {
  let form = create_snippet_form()

  create_snippet_page_view(form)
  |> string_tree.to_string
  |> wisp.html_response(200)
}

fn create_snippet_page_view(form) {
  html.form([attribute.method("post"), attribute.class("flex flex-col")], [
    field_input(form, "title", "text", "Title"),
    html.label([], [
      html.text("Content"),
      html.textarea([attribute.name("content"), attribute.class("border")], ""),
    ]),
    field_input(form, "ttl", "number", "TTL"),
    html.button([attribute.type_("submit")], [html.text("Submit")]),
  ])
  |> layout.page_layout_view("Create Snippet", _)
}

fn field_input(form: Form(t), name: String, kind: String, label: String) {
  let errors = form.field_error_messages(form, name)

  html.label([], [
    html.text(label),
    html.input([
      attribute.class("border"),
      attribute.type_(kind),
      attribute.name(name),
      attribute.value(form.field_value(form, name)),
      case errors {
        [] -> attribute.none()
        _ -> attribute.aria_invalid("true")
      },
    ]),
    ..list.map(errors, fn(msg) { html.small([], [html.text(msg)]) })
  ])
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
      layout.page_layout_view("Snippet", snippet_page_view(snippet))
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
    html.p([], [html.text(snippet.title)]),
  ])
}
