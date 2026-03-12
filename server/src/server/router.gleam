import gleam/http.{Delete, Get, Patch, Post}
import server/api_route/auth
import server/api_route/health
import server/api_route/snippet
import server/api_route/user
import server/context.{type Context}
import server/helper
import server/middleware
import server/page/home
import server/page/login
import server/page/register
import server/page/snippet_page
import wisp.{type Request, type Response}

pub fn handle_request(
  ctx: Context,
  static_directory: String,
  req: Request,
) -> Response {
  use req <- middleware.middleware(req, static_directory)

  case req.method, wisp.path_segments(req) {
    _, ["v1", ..rest] -> api_routes(ctx, req, rest)

    _, rest -> web_routes(req, rest)
    // Get, _ -> serve_index()
    // _, _ -> helper.html_error_response(404)
  }
}

// fn serve_index() -> Response {
//   let html =
//     html.html([], [
//       html.head([], [
//         html.title([], "Pastem"),
//         html.link([
//           attribute.rel("stylesheet"),
//           attribute.href("/static/client.css"),
//         ]),
//         html.script(
//           [attribute.type_("module"), attribute.src("/static/client.js")],
//           "",
//         ),
//       ]),
//       html.body([], [html.div([attribute.id("app")], [])]),
//     ])

//   html
//   |> element.to_document_string
//   |> wisp.html_response(200)
// }

fn web_routes(req: Request, segments) {
  let req = middleware.authenticate_web(req)

  case req.method, segments {
    Get, ["register"] -> register.register_page(req)
    Post, ["register"] -> register.register_submit(req)

    Get, ["login"] -> login.login_page(req)
    Post, ["login"] -> login.login_submit(req)

    Get, ["logout"] -> {
      let res = wisp.redirect("/")
      case wisp.get_cookie(req, "auth_token", wisp.Signed) {
        Ok(value) ->
          wisp.set_cookie(res, req, "auth_token", value, wisp.Signed, 0)
        Error(_) -> res
      }
    }

    Get, ["snippets", "create"] -> snippet_page.create(req)
    Post, ["snippets", "create"] -> snippet_page.create_snippet_submit(req)
    _, ["snippets", "create"] -> wisp.method_not_allowed([Get, Post])

    Get, ["snippets", id] -> snippet_page.show(req, id)

    Get, _ -> home.home_page(req)
    _, _ -> helper.html_error_response(404)
  }
}

fn api_routes(ctx: Context, req: Request, segments: List(String)) -> Response {
  case req.method, segments {
    Get, ["health"] -> health.health()
    Post, ["register"] -> auth.register(ctx, req)
    Post, ["tokens"] -> auth.create_token(ctx, req)
    Delete, ["tokens"] -> auth.delete_token(ctx, req)

    Get, ["users", "me"] -> user.get_current_user(ctx, req)

    Get, ["snippets"] -> snippet.list_snippets(ctx, req)
    Post, ["snippets"] -> {
      use req, ctx <- middleware.require_auth(req, ctx)
      snippet.store_snippet(ctx, req)
    }
    _, ["snippets"] -> wisp.method_not_allowed([Get, Post])

    Get, ["snippets", id] -> snippet.get_snippet(ctx, req, id)
    Patch, ["snippets", id] -> {
      use req, ctx <- middleware.require_admin_or_owner(req, ctx, id)
      snippet.update_snippet(ctx, req, id)
    }
    Delete, ["snippets", id] -> {
      use req, ctx <- middleware.require_admin_or_owner(req, ctx, id)
      snippet.delete_snippet(ctx, req, id)
    }
    _, ["snippets", _] -> wisp.method_not_allowed([Get, Patch, Delete])

    _, _ -> wisp.not_found()
  }
}
