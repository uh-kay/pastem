import server/context
import server/middleware
import server/routes/auth
import server/routes/health
import server/routes/snippets
import wisp.{type Request, type Response}

pub fn handle_request(ctx: context.Context, req: Request) -> Response {
  use req <- middleware.middleware(req)

  case wisp.path_segments(req) {
    ["api", "health"] -> health.health()
    ["api", "register"] -> auth.register(ctx, req)
    ["api", "tokens"] -> auth.tokens(ctx, req)
    ["api", "snippets"] -> snippets.snippets(ctx, req, "")
    ["api", "snippets", id] -> snippets.snippets(ctx, req, id)
    _ -> wisp.not_found()
  }
}
