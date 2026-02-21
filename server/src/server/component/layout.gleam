import lustre/attribute
import lustre/element
import lustre/element/html
import server/component/navbar

pub fn page_layout_view(req, content) {
  html.html([], [
    html.head([], [
      html.title([], "Create Snippet"),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/server/output.css"),
      ]),
    ]),
    html.body([], [
      navbar.navbar(req),
      content,
    ]),
  ])
  |> element.to_document_string_tree
}
