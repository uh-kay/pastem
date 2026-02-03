import gleam/crypto
import gleam/http/request
import gleam/option
import gleam/result
import server/context
import server/db/roles
import server/db/users
import server/errors
import wisp

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use req <- wisp.csrf_known_header_protection(req)

  handle_request(req)
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
  case check_role_level(ctx, role_name) {
    Ok(match) -> {
      case match {
        True -> next(req, ctx)
        False -> wisp.response(403)
      }
    }
    Error(err) -> errors.handle_error(req, err)
  }
}

fn snippet_context_middleware() {
  todo
}

fn check_role_level(
  ctx: context.Context,
  role_name: String,
) -> Result(Bool, errors.AppError) {
  let result = {
    use role <- result.try(roles.get_role(ctx, role_name))

    case ctx.user {
      option.Some(user) -> Ok({ user.role_level >= role.level })
      option.None -> Error(errors.NotFound("user"))
    }
  }
  case result {
    Ok(match) -> Ok(match)
    Error(err) -> Error(err)
  }
}

pub fn require_admin(req, ctx, next) {
  use req, ctx <- require_auth(req, ctx)
  use req, ctx <- require_permission(req, ctx, "admin")
  next(req, ctx)
}
