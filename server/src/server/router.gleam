import gleam/http.{Delete, Get, Patch, Post}
import server/api_route/auth
import server/api_route/health
import server/api_route/snippets
import server/context.{type Context}
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

    _, rest -> client_routes(req, rest)
  }
}

fn client_routes(req: Request, segments) {
  let req = middleware.authenticate_client(req)

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
    _, _ -> wisp.not_found()
  }
}

fn api_routes(ctx: Context, req: Request, segments: List(String)) -> Response {
  case req.method, segments {
    Get, ["health"] -> health.health()
    Post, ["register"] -> auth.register(ctx, req)
    Post, ["tokens"] -> auth.tokens(ctx, req)

    Get, ["snippets"] -> snippets.list_snippets(ctx, req)
    Post, ["snippets"] -> {
      use req, ctx <- middleware.require_auth(req, ctx)
      snippets.store_snippet(ctx, req)
    }
    _, ["snippets"] -> wisp.method_not_allowed([Get, Post])

    Get, ["snippets", id] -> snippets.get_snippet(ctx, req, id)
    Patch, ["snippets", id] -> {
      use req, ctx <- middleware.require_admin_or_owner(req, ctx, id)
      snippets.update_snippet(ctx, req, id)
    }
    Delete, ["snippets", id] -> {
      use req, ctx <- middleware.require_admin_or_owner(req, ctx, id)
      snippets.delete_snippet(ctx, req, id)
    }
    _, ["snippets", _] -> wisp.method_not_allowed([Get, Patch, Delete])

    _, _ -> wisp.not_found()
  }
}
