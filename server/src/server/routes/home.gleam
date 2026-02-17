import envoy
import gleam/http/request
import gleam/httpc
import gleam/result
import lustre/attribute
import lustre/element
import lustre/element/html
import wisp

pub fn index() {
  let items = fetch_snippets()

  let html =
    html.html([], [
      html.head([], [
        html.title([], "Pastem"),
        html.script(
          [attribute.type_("module"), attribute.src("/static/client.js")],
          "",
        ),
        html.script(
          [attribute.type_("application/json"), attribute.id("model")],
          items,
        ),
        html.link([
          attribute.href("/static/client.css"),
          attribute.rel("stylesheet"),
        ]),
      ]),
      html.body([], [html.div([attribute.id("app")], [])]),
    ])

  html
  |> element.to_document_string
  |> wisp.html_response(200)
}

fn fetch_snippets() {
  let result = {
    use req <- result.try(request.to(api_url() <> "/snippets"))

    req
    |> httpc.send
    |> result.replace_error(Nil)
  }

  case result {
    Ok(res) -> {
      res.body
    }
    Error(_) -> ""
  }
}

fn api_url() {
  result.unwrap(envoy.get("API_URL"), "")
}
