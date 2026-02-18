import gleam/http.{Delete, Get, Patch, Post}
import server/context.{type Context}
import server/middleware
import server/page/home
import server/page/snippet_page
import server/routes/auth
import server/routes/health
import server/routes/snippets
import wisp.{type Request, type Response}

pub fn handle_request(
  ctx: Context,
  static_directory: String,
  req: Request,
) -> Response {
  use req <- middleware.middleware(req, static_directory)

  case req.method, wisp.path_segments(req) {
    _, ["v1", ..rest] -> api_routes(ctx, req, rest)

    Get, ["snippets", "create"] -> snippet_page.create()
    Post, ["snippets", "create"] -> snippet_page.create_snippet_submit(req)
    _, ["snippets", "create"] -> wisp.method_not_allowed([Get, Post])

    Get, ["snippets", id] -> snippet_page.show(id)

    Get, _ -> home.home_page()

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
