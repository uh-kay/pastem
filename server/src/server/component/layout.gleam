import gleam/string_tree.{type StringTree}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import server/component/navbar
import wisp.{type Request}

pub fn page_layout_view(
  req: Request,
  title: String,
  content: Element(a),
) -> StringTree {
  html.html([], [
    html.head([], [
      html.title([], title),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/output.css"),
      ]),
    ]),
    html.body([], [
      navbar.navbar(req),
      content,
    ]),
  ])
  |> element.to_document_string_tree
}
