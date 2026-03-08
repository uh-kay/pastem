import gleam/option.{type Option, None}
import lustre/attribute
import lustre/element/html
import shared.{type Snippet}

pub type Msg

pub type Model {
  Model(snippet: Option(Snippet), logged_in: Bool)
}

pub fn view(model: Model) {
  case model.snippet {
    option.Some(snippet) -> snippet_view(snippet)
    None -> html.p([], [html.text("not found")])
  }
}

fn snippet_view(snippet: Snippet) {
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
        html.text("Expires in " <> shared.time_until(snippet.expires_at)),
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
