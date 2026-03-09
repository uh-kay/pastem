import gleam/int
import gleam/uri
import plinth/browser/location
import plinth/browser/window

pub type Route {
  Home
  CreateSnippet
  ShowSnippet(snippet_id: Int)
  Login
  Register
  Logout
  NotFound
}

pub fn get_route() -> Route {
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
