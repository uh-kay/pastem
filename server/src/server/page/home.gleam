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

pub fn home_page(req) {
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
      layout.page_layout_view(req, snippet_list_view(snippets))
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
  html.div([attribute.class("max-w-2xl mx-auto p-6")], [
    html.header([attribute.class("mb-8 border-b pb-4")], [
      html.h1([attribute.class("text-3xl font-bold text-slate-900")], [
        html.text("Recent Snippets"),
      ]),
      html.p([attribute.class("text-slate-500 mt-2")], [
        html.text("Browse and explore public snippets."),
      ]),
    ]),
    view_snippet_list(snippets),
  ])
}

fn view_snippet_list(snippets: List(Snippet)) {
  case snippets {
    [] ->
      html.div(
        [
          attribute.class(
            "text-center py-20 bg-slate-50 rounded-lg border-2 border-dashed border-slate-200",
          ),
        ],
        [
          html.p([attribute.class("text-slate-400 font-medium")], [
            html.text("No snippets found. Why not create one?"),
          ]),
        ],
      )

    _ -> {
      html.ul(
        [attribute.class("space-y-4")],
        list.index_map(snippets, fn(item, _index) {
          html.li([attribute.class("group")], [
            html.a(
              [
                attribute.class(
                  "block p-4 bg-white border border-slate-200 rounded-xl shadow-sm transition-all hover:border-blue-400 hover:shadow-md hover:-translate-y-0.5",
                ),
                attribute.href("/snippets/" <> int.to_string(item.id)),
              ],
              [
                html.div(
                  [attribute.class("flex justify-between items-center")],
                  [
                    html.span(
                      [
                        attribute.class(
                          "text-lg font-semibold text-slate-800 group-hover:text-blue-600",
                        ),
                      ],
                      [
                        html.text(item.title),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ])
        }),
      )
    }
  }
}
