import formal/form
import gleam/http.{Get, Post}
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleam/result
import gleam/string_tree
import lustre/attribute
import lustre/element/html
import server/api_route/snippets.{StoreSnippet}
import server/component/input
import server/component/layout
import server/errors.{BadRequest, InternalServerError, NotFound, Unauthorized}
import server/helpers
import server/page/request.{Header}
import shared.{type Snippet}
import wisp

type CreateSnippetError {
  CouldNotParseForm(form: form.Form(snippets.StoreSnippet))
  CouldNotGetCookie(errors.AppError)
  CreateSnippetRequestFailed(errors.AppError)
}

pub fn create_snippet_submit(req) {
  use formdata <- wisp.require_form(req)

  let result = {
    use data <- result.try(
      create_snippet_form()
      |> form.add_values(formdata.values)
      |> form.run
      |> result.map_error(CouldNotParseForm),
    )

    let body = snippets.store_snippet_to_json(data) |> json.to_string
    use cookie <- result.try(
      wisp.get_cookie(req, "auth_token", wisp.Signed)
      |> result.replace_error(CouldNotGetCookie(Unauthorized)),
    )

    let headers = [
      Header("content-type", "application/json"),
      Header("authorization", "Bearer " <> cookie),
    ]

    request.send_request(
      path: "/snippets",
      body: Some(body),
      method: Post,
      headers:,
    )
    |> result.map_error(CreateSnippetRequestFailed)
  }

  case result {
    Ok(_) -> wisp.redirect("/")
    Error(CouldNotParseForm(form)) ->
      helpers.html_response(req, create_snippet_view(form), 422)
    Error(_) -> helpers.html_error_response(500)
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

pub fn create(req) {
  let form = create_snippet_form()

  layout.page_layout_view(req, create_snippet_view(form))
  |> string_tree.to_string
  |> wisp.html_response(200)
}

fn create_snippet_view(form) {
  html.form([attribute.method("post"), attribute.class("max-w-sm mx-auto")], [
    html.h1([attribute.class("text-xl font-bold my-4")], [
      html.text("Create a New Snippet"),
    ]),
    input.field_input(form, "title", "text", "Title", [attribute.required(True)]),
    html.div([attribute.class("mb-4")], [
      html.label([attribute.class("block mb-2 text-sm")], [html.text("Content")]),
      input.textarea(
        "content",
        "",
        "block rounded-md w-full px-3 py-2 border border-gray-400 focus:border-transparent",
        [attribute.required(True)],
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
  ])
}

pub fn show(req, id) {
  let result = {
    use res <- result.try(
      request.send_request(
        path: "/snippets/" <> id,
        body: None,
        method: Get,
        headers: [],
      ),
    )

    case res.status >= 200 && res.status < 300 {
      False ->
        case res.status {
          404 -> Error(NotFound("snippet"))
          _ -> Error(InternalServerError("internal server error"))
        }
      True ->
        json.parse(res.body, shared.snippet_item_decoder())
        |> result.replace_error(InternalServerError("Failed to decode snippet"))
    }
  }

  case result {
    Ok(snippet) ->
      layout.page_layout_view(req, snippet_page_view(snippet))
      |> string_tree.to_string
      |> wisp.html_response(200)
    Error(err) ->
      case err {
        BadRequest(_) -> helpers.html_error_response(400)
        NotFound(_) -> helpers.html_error_response(404)
        Unauthorized -> helpers.html_error_response(401)
        _ -> helpers.html_error_response(500)
      }
  }
}

fn time_until(unix_timestamp) {
  let diff = unix_timestamp - helpers.current_time()

  case diff {
    _ if diff > 86_400 -> int.to_string(diff / 86_400) <> " days"
    _ if diff > 3600 -> int.to_string(diff / 3600) <> " hours"
    _ if diff > 60 -> int.to_string(diff / 60) <> " minutes"
    _ -> "expired"
  }
}

fn snippet_page_view(snippet: Snippet) {
  html.div(
    [
      attribute.class(
        "max-w-2xl mx-auto my-4 p-6 bg-white border border-gray-200 rounded-lg shadow-sm",
      ),
    ],
    [
      html.h1([attribute.class("text-2xl font-bold text-gray-900")], [
        html.text(snippet.title),
      ]),
      html.p([attribute.class("text-sm text-gray-500")], [
        html.text("Author: " <> snippet.author_name),
      ]),
      html.p([attribute.class("text-sm text-gray-400 italic")], [
        html.text("Expires in " <> time_until(snippet.expires_at)),
      ]),
      html.pre(
        [
          attribute.class(
            "mt-4 p-4 bg-gray-50 rounded border border-gray-300 font-mono text-sm overflow-x-auto",
          ),
        ],
        [html.text(snippet.content)],
      ),
    ],
  )
}
