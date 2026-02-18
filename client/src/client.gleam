import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None}
import gleam/result
import gleam/uri
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import plinth/browser/document
import plinth/browser/element as plinth_element
import plinth/browser/event as plinth_event
import plinth/browser/location
import plinth/browser/window
import rsvp
import shared.{type Snippet}

pub fn main() -> Nil {
  let initial_items =
    document.query_selector("#model")
    |> result.map(plinth_element.inner_text)
    |> result.try(fn(json) {
      json.parse(json, shared.snippet_list_decoder())
      |> result.replace_error(Nil)
    })
    |> result.unwrap([])

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", initial_items)

  Nil
}

type Model {
  Model(
    snippets: List(Snippet),
    current_snippet: Option(Snippet),
    current_route: Route,
    saving: Bool,
    error: Option(String),
  )
}

type Route {
  Home
  ShowSnippet(snippet_id: Int)
  NotFound
}

fn get_route() -> Route {
  let uri = case
    window.self() |> window.location() |> location.pathname() |> uri.parse()
  {
    Ok(uri) -> uri
    Error(_) -> uri.empty
  }

  case uri.path |> uri.path_segments {
    [] -> Home
    ["snippets", snippet_id] ->
      case int.parse(snippet_id) {
        Ok(id) -> ShowSnippet(id)
        Error(_) -> NotFound
      }
    _ -> NotFound
  }
}

fn init(snippets) {
  let model =
    Model(
      snippets: snippets,
      current_snippet: None,
      current_route: Home,
      saving: False,
      error: None,
    )
  #(model, effect.none())
}

type Msg {
  ServerSavedSnippet(Result(Response(String), rsvp.Error))
  UserClickedSnippet
  UserCreateSnippet(title: String, content: String)
}

fn update(model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserCreateSnippet(title:, content:) -> {
      let snippet = CreateSnippet(title:, content:)
      #(Model(..model, saving: True), save_snippet(snippet))
    }

    ServerSavedSnippet(_) -> #(
      Model(..model, error: option.Some("failed to save snippet")),
      effect.none(),
    )
    UserClickedSnippet -> {
      let snippet =
        document.query_selector("#model")
        |> result.map(plinth_element.inner_text)
        |> result.try(fn(json) {
          json.parse(json, shared.snippet_decoder())
          |> result.replace_error(Nil)
        })
      case snippet {
        Ok(snippet) -> #(
          Model(
            ..model,
            current_snippet: option.Some(snippet),
            current_route: todo,
          ),
          effect.none(),
        )
        Error(_) -> #(
          Model(..model, current_route: todo, current_snippet: None),
          effect.none(),
        )
      }
    }
  }
}

pub type CreateSnippet {
  CreateSnippet(title: String, content: String)
}

fn create_snippet_to_json(create_snippet: CreateSnippet) -> json.Json {
  let CreateSnippet(title:, content:) = create_snippet
  json.object([
    #("title", json.string(title)),
    #("content", json.string(content)),
  ])
}

fn save_snippet(snippet) -> Effect(Msg) {
  let body = create_snippet_to_json(snippet)
  let url = "/api/snippets"

  rsvp.post(url, body, rsvp.expect_ok_response(ServerSavedSnippet))
}

fn view(model: Model) -> Element(Msg) {
  case model.current_route {
    Index ->
      html.div([], [
        html.h1([attribute.class("text-blue-500 text-2xl")], [
          html.text("Snippet List"),
        ]),
        view_snippet_list(model.snippets),
      ])
    SnippetDetail ->
      html.div([], [
        html.h1([attribute.class("text-blue-500 text-2xl")], [
          html.text("Snippet"),
        ]),
        // view_snippet_list(model.snippets),
      ])
  }
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
                attribute.class("hover:text-red-500"),
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
