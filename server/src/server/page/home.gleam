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
import shared.{type Snippet}
import wisp

pub fn home_page() {
  let result = {
    use api_req <- result.try(
      request.to(helpers.api_url() <> "/snippets")
      |> result.replace_error(InternalServerError("invalid URL")),
    )

    use res <- result.try(
      httpc.send(api_req)
      |> result.replace_error(InternalServerError("API connection failed")),
    )

    case res.status >= 200 && res.status < 300 {
      True ->
        json.parse(res.body, shared.snippet_list_decoder())
        |> result.replace_error(InternalServerError("failed to decode snippet"))
      False ->
        case res.status {
          404 -> Error(NotFound("snippet"))
          _ -> Error(InternalServerError("internal server error"))
        }
    }
  }

  case result {
    Ok(snippets) ->
      layout.page_layout_view(snippet_list_view(snippets))
      |> string_tree.to_string
      |> wisp.html_response(200)
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

fn snippet_list_view(snippets) {
  html.div([attribute.class("max-w-md mx-auto p-2")], [
    html.h1([attribute.class("text-blue-500 text-2xl")], [
      html.text("Snippet List"),
    ]),
    view_snippet_list(snippets),
  ])
}

fn view_snippet_list(snippets: List(Snippet)) {
  case snippets {
    [] -> html.p([], [html.text("No snippet found.")])
    _ -> {
      html.ul(
        [],
        list.index_map(snippets, fn(item, _index) {
          html.li([], [
            html.a(
              [
                attribute.class("text-blue-500 hover:text-blue-600"),
                attribute.href("/snippets/" <> int.to_string(item.id)),
              ],
              [
                html.text(item.title),
              ],
            ),
          ])
        }),
      )
    }
  }
}
