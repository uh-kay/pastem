import gleam/crypto
import gleam/http/request
import gleam/int
import gleam/option
import gleam/result
import server/context
import server/errors
import server/models/roles
import server/models/snippets
import server/models/users
import wisp

pub fn middleware(
  req: wisp.Request,
  static_directory: String,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: static_directory)
  use req <- wisp.csrf_known_header_protection(req)

  handle_request(req)
}

pub fn log_request(
  req: wisp.Request,
  handler: fn() -> wisp.Response,
) -> wisp.Response {
  let res = handler()
  errors.format_log(req, option.Some(res), "")
  |> wisp.log_info
  res
}

pub fn require_auth(
  req: wisp.Request,
  ctx: context.Context,
  next: fn(wisp.Request, context.Context) -> wisp.Response,
) -> wisp.Response {
  let token = request.get_header(req, "Authorization")

  case token {
    Ok("Bearer " <> t) -> {
      let token = crypto.hash(crypto.Sha256, <<t:utf8>>)
      case users.get_user_by_token(ctx, token) {
        Ok(user) -> {
          let new_ctx = context.Context(..ctx, user: option.Some(user))
          next(req, new_ctx)
        }
        Error(err) -> {
          case err {
            errors.NotFound(_) -> wisp.response(401)
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
  req: wisp.Request,
  ctx: context.Context,
  role_name: String,
  next: fn(wisp.Request, context.Context) -> wisp.Response,
) {
  let is_owner = check_owner(ctx) |> result.unwrap(False)
  let is_admin = check_role_level(ctx, role_name) |> result.unwrap(False)

  case is_owner || is_admin {
    True -> next(req, ctx)
    False -> wisp.response(401)
  }
}

pub fn snippet_context_middleware(
  ctx: context.Context,
  req: wisp.Request,
  id: String,
  next: fn(wisp.Request, context.Context) -> wisp.Response,
) -> wisp.Response {
  case result.replace_error(int.parse(id), errors.BadRequest("invalid id")) {
    Ok(id) -> {
      case snippets.get_snippet(ctx, id) {
        Ok(snippet) -> {
          let new_ctx = context.Context(..ctx, snippet: option.Some(snippet))
          next(req, new_ctx)
        }
        Error(err) -> errors.handle_error(req, err)
      }
    }
    Error(err) -> errors.handle_error(req, err)
  }
}

fn check_owner(ctx: context.Context) -> Result(Bool, errors.AppError) {
  case ctx.snippet {
    option.Some(snippet) ->
      case ctx.user {
        option.Some(user) -> Ok({ user.id == snippet.author })
        option.None -> Error(errors.NotFound("user"))
      }
    option.None -> Error(errors.NotFound("snippet"))
  }
}

fn check_role_level(
  ctx: context.Context,
  role_name: String,
) -> Result(Bool, errors.AppError) {
  use role <- result.try(roles.get_role(ctx, role_name))

  case ctx.user {
    option.Some(user) -> Ok({ user.role_level >= role.level })
    option.None -> Error(errors.NotFound("user"))
  }
}

pub fn require_admin_or_owner(req, ctx, id, next) {
  use req, ctx <- require_auth(req, ctx)
  use req, ctx <- snippet_context_middleware(ctx, req, id)
  use req, ctx <- require_permission(req, ctx, "admin")
  next(req, ctx)
}
