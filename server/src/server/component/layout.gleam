import lustre/attribute
import lustre/element
import lustre/element/html
import server/component/navbar

pub fn page_layout_view(content) {
  html.html([], [
    html.head([], [
      html.title([], "Create Snippet"),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/server/output.css"),
      ]),
      html.script(
        [attribute.type_("module"), attribute.src("/static/client.js")],
        "",
      ),
    ]),
    html.body([], [
      navbar.navbar(),
      content,
    ]),
  ])
  |> element.to_document_string_tree
}
