import gleam/crypto.{Sha256}
import gleam/http/request
import gleam/int
import gleam/option.{None, Some}
import gleam/result
import server/context.{type Context, Context}
import server/errors.{type AppError, NotFound}
import server/model/roles
import server/model/snippets
import server/model/users
import wisp.{type Request, type Response}

pub fn middleware(
  req: Request,
  static_directory: String,
  handle_request: fn(Request) -> Response,
) -> Response {
  let req = wisp.method_override(req)
  use <- log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: static_directory)
  use req <- wisp.csrf_known_header_protection(req)

  handle_request(req)
}

pub fn log_request(req: Request, handler: fn() -> Response) -> Response {
  let res = handler()
  errors.format_log(req, Some(res), "")
  |> wisp.log_info
  res
}

pub fn require_auth(
  req: Request,
  ctx: Context,
  next: fn(Request, Context) -> Response,
) -> Response {
  let token = request.get_header(req, "Authorization")

  case token {
    Ok("Bearer " <> t) -> {
      let token = crypto.hash(Sha256, <<t:utf8>>)
      case users.get_user_by_token(ctx, token) {
        Ok(user) -> {
          let new_ctx = Context(..ctx, user: Some(user))
          next(req, new_ctx)
        }
        Error(err) -> {
          case err {
            NotFound(_) -> wisp.response(401)
            _ -> errors.handle_error(req, err)
          }
        }
      }
    }
    _ -> {
      wisp.log_warning("missing auth token")
      wisp.response(401)
    }
  }
}

pub fn require_permission(
  req: Request,
  ctx: Context,
  role_name: String,
  next: fn(Request, Context) -> Response,
) {
  let is_owner = check_owner(ctx) |> result.unwrap(False)
  let is_admin = check_role_level(ctx, role_name) |> result.unwrap(False)

  case is_owner || is_admin {
    True -> next(req, ctx)
    False -> wisp.response(401)
  }
}

pub fn snippet_context_middleware(
  ctx: Context,
  req: Request,
  id: String,
  next: fn(Request, Context) -> Response,
) -> Response {
  case result.replace_error(int.parse(id), errors.BadRequest("invalid id")) {
    Ok(id) ->
      case snippets.get_snippet(ctx, id) {
        Ok(snippet) -> {
          let new_ctx = Context(..ctx, snippet: Some(snippet))
          next(req, new_ctx)
        }
        Error(err) -> errors.handle_error(req, err)
      }
    Error(err) -> errors.handle_error(req, err)
  }
}

fn check_owner(ctx: Context) -> Result(Bool, AppError) {
  case ctx.snippet {
    Some(snippet) ->
      case ctx.user {
        Some(user) -> Ok({ user.id == snippet.author_id })
        None -> Error(NotFound("user"))
      }
    None -> Error(NotFound("snippet"))
  }
}

fn check_role_level(ctx: Context, role_name: String) -> Result(Bool, AppError) {
  use role <- result.try(roles.get_role(ctx, role_name))

  case ctx.user {
    Some(user) -> Ok({ user.role_level >= role.level })
    None -> Error(NotFound("user"))
  }
}

pub fn authenticate_client(req: Request) -> Request {
  case wisp.get_cookie(req, "auth_token", wisp.Signed) {
    Ok(cookie) ->
      request.prepend_header(req, "authorization", "Bearer " <> cookie)
    Error(_) -> req
  }
}

pub fn require_admin_or_owner(
  req: Request,
  ctx: Context,
  id: String,
  next: fn(Request, Context) -> Response,
) -> Response {
  use req, ctx <- require_auth(req, ctx)
  use req, ctx <- snippet_context_middleware(ctx, req, id)
  use req, ctx <- require_permission(req, ctx, "admin")
  next(req, ctx)
}
