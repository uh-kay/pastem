import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string_tree
import lustre/attribute
import lustre/element
import lustre/element/html
import server/component/layout
import server/error.{BadRequest, InternalServerError, NotFound, Unauthorized}
import server/helper
import server/page/request
import shared.{type Snippet}
import wisp

type ListSnippets {
  ListSnippets(count: Int, snippets: List(Snippet))
}

fn list_snippets_decoder() -> decode.Decoder(ListSnippets) {
  use count <- decode.field("count", decode.int)
  use snippets <- decode.field(
    "snippets",
    decode.list(shared.snippet_decoder()),
  )

  decode.success(ListSnippets(count:, snippets:))
}

pub fn home_page(req) {
  let queries = wisp.get_query(req)
  let page = helper.query_to_int(queries, "page", 1)
  let offset = { page - 1 } * 20

  let result = {
    use res <- result.try(
      request.send_request(
        "/snippets?offset=" <> int.to_string(offset),
        body: None,
        method: http.Get,
        headers: [],
      ),
    )

    case res.status >= 200 && res.status < 300 {
      True ->
        json.parse(res.body, list_snippets_decoder())
        |> result.replace_error(InternalServerError("failed to decode snippet"))
      False ->
        case res.status {
          404 -> Error(NotFound("snippet"))
          _ -> Error(InternalServerError("internal server error"))
        }
    }
  }

  case result {
    Ok(snippets) -> {
      let page_count = int.max(snippets.count / 20, 1)

      layout.page_layout_view(
        req,
        "Pastem",
        snippet_list_view(Some(snippets.snippets), page, page_count),
      )
      |> string_tree.to_string
      |> wisp.html_response(200)
    }
    Error(err) -> {
      case err {
        BadRequest(_) -> helper.html_error_response(400)
        NotFound(_) -> {
          layout.page_layout_view(req, "Pastem", snippet_list_view(None, 0, 0))
          |> string_tree.to_string
          |> wisp.html_response(200)
        }
        Unauthorized -> helper.html_error_response(401)
        _ -> helper.html_error_response(500)
      }
    }
  }
}

fn snippet_list_view(
  snippets: option.Option(List(Snippet)),
  current_page,
  page_count,
) {
  case snippets {
    Some(snippets) ->
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
        paginate(current_page, page_count),
      ])
    None ->
      html.div([attribute.class("max-w-2xl mx-auto p-6")], [
        html.h1([attribute.class("text-slate-500 text-2xl")], [
          html.text("No snippet found."),
        ]),
      ])
  }
}

fn paginate(current_page, page_count) {
  let pages =
    int.range(from: page_count, to: 0, with: [], run: fn(acc, i) {
      [
        html.a(
          [
            attribute.href("?page=" <> int.to_string(i)),
            attribute.class(case i == current_page {
              True -> "font-bold p-2"
              False -> "p-2"
            }),
          ],
          [html.text(int.to_string(i))],
        ),
        ..acc
      ]
    })

  html.div([attribute.class("flex justify-center items-center")], [
    html.a(
      list.flatten([
        case current_page {
          _ if current_page <= 1 -> {
            [
              attribute.class("text-gray-400 cursor-not-allowed text-xl p-2"),
            ]
          }
          _ -> [
            attribute.href("?page=" <> int.to_string(current_page - 1)),
            attribute.class("text-xl p-2"),
          ]
        },
      ]),
      [html.text("<")],
    ),
    element.fragment(pages),
    html.a(
      list.flatten([
        case current_page {
          _ if current_page >= page_count -> {
            [attribute.class("text-gray-400 cursor-not-allowed text-xl p-2")]
          }
          _ -> [
            attribute.href("?page=" <> int.to_string(current_page + 1)),
            attribute.class("text-xl p-2"),
          ]
        },
      ]),
      [html.text(">")],
    ),
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
      html.div([], [
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
                  html.div([], [
                    html.span(
                      [
                        attribute.class(
                          "text-lg font-semibold text-slate-800 group-hover:text-blue-600",
                        ),
                      ],
                      [html.text(item.title)],
                    ),
                  ]),
                ],
              ),
            ])
          }),
        ),
      ])
    }
  }
}
