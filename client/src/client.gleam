import client/route.{type Route, Home, NotFound, ShowSnippet}
import gleam/http/response.{type Response}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp
import shared.{type Snippet}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", [])

  Nil
}

fn fetch_snippets() {
  let url = "/api/snippets"
  let handler =
    rsvp.expect_json(shared.snippet_list_decoder(), ApiReturnedSnippetList)

  rsvp.get(url, handler)
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

fn init(snippets) {
  let model =
    Model(
      snippets: snippets,
      current_snippet: None,
      current_route: Home,
      saving: False,
      error: None,
    )

  let initial_items = fetch_snippets()

  #(model, initial_items)
}

type Msg {
  ServerSavedSnippet(Result(Response(String), rsvp.Error))
  ApiReturnedSnippetList(Result(List(Snippet), rsvp.Error))
  ApiReturnedSnippet(Result(Snippet, rsvp.Error))
  UserClickedSnippet(id: Int)
  UserCreateSnippet(title: String, content: String)
}

fn update(model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserCreateSnippet(title:, content:) -> {
      let snippet = CreateSnippet(title:, content:)
      #(Model(..model, saving: True), save_snippet(snippet))
    }
    ApiReturnedSnippetList(res) ->
      case res {
        Ok(snippets) -> #(Model(..model, snippets: snippets), effect.none())
        Error(_) -> #(
          Model(..model, error: Some("failed to get snippets")),
          effect.none(),
        )
      }
    ApiReturnedSnippet(res) ->
      case res {
        Ok(snippet) -> #(
          Model(..model, current_snippet: Some(snippet)),
          effect.none(),
        )
        Error(err) -> {
          echo err
          #(Model(..model, error: Some("failed to get snippet")), effect.none())
        }
      }
    ServerSavedSnippet(_) -> #(
      Model(..model, error: Some("failed to save snippet")),
      effect.none(),
    )
    UserClickedSnippet(id) -> {
      let snippet = fetch_snippet(id)
      #(
        Model(..model, current_route: ShowSnippet(id), current_snippet: None),
        snippet,
      )
    }
  }
}

fn fetch_snippet(id) {
  let url = "/api/snippets/" <> int.to_string(id)
  let handler =
    rsvp.expect_json(shared.snippet_item_decoder(), ApiReturnedSnippet)

  rsvp.get(url, handler)
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
    Home ->
      html.div([], [
        html.h1([attribute.class("text-blue-500 text-2xl")], [
          html.text("Snippet List"),
        ]),
        view_snippet_list(model.snippets),
      ])
    ShowSnippet(id) ->
      case model.current_snippet {
        Some(snippet) ->
          html.div([], [
            html.h1([attribute.class("text-blue-500 text-2xl")], [
              html.text("Snippet"),
            ]),
            html.p([], [html.text(int.to_string(id))]),
            html.p([], [html.text(snippet.title)]),
            // view_snippet_list(model.snippets),
          ])
        None -> html.p([], [html.text("not found")])
      }

    NotFound -> element.none()
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
                // event.on_click(UserClickedSnippet(item.id)),
                event.prevent_default(
                  event.on_click(UserClickedSnippet(item.id)),
                ),
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
