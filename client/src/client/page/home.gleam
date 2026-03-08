import gleam/int
import gleam/list
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event
import shared.{type Snippet}

pub type Model {
  Model(snippets: List(Snippet), logged_in: Bool)
}

pub type Msg {
  UserClickedSnippet(Int)
}

pub fn view(model: Model) {
  snippet_list_view(model.snippets, 0, 0)
}

fn snippet_list_view(snippets: List(Snippet), current_page, page_count) {
  case snippets {
    [] ->
      html.div([attribute.class("max-w-2xl mx-auto p-6")], [
        html.h1([attribute.class("text-slate-500 text-2xl")], [
          html.text("No snippet found."),
        ]),
      ])
    snippets ->
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
                  event.prevent_default(
                    event.on_click(UserClickedSnippet(item.id)),
                  ),
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
