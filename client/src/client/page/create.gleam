import gleam/http/response.{type Response}
import gleam/json
import lustre/effect.{type Effect}
import rsvp

pub type Msg {
  ServerSavedSnippet(Result(Response(String), rsvp.Error))
  UserCreateSnippet(title: String, content: String)
}

pub type CreateSnippet {
  CreateSnippet(title: String, content: String)
}

pub fn create_snippet_to_json(create_snippet: CreateSnippet) -> json.Json {
  let CreateSnippet(title:, content:) = create_snippet
  json.object([
    #("title", json.string(title)),
    #("content", json.string(content)),
  ])
}

pub fn save_snippet(snippet) -> Effect(Msg) {
  let body = create_snippet_to_json(snippet)
  let url = "/api/snippets"

  rsvp.post(url, body, rsvp.expect_ok_response(ServerSavedSnippet))
}
