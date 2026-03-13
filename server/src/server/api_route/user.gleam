import gleam/result
import server/helper
import server/model/user
import shared
import wisp

type UserError {
  UserError(user.UserError)
  MissingCookieError
}

pub fn get_current_user(ctx, req) {
  let result = {
    use token <- result.try(
      wisp.get_cookie(req, "auth_token", wisp.Signed)
      |> result.replace_error(MissingCookieError),
    )

    use user <- result.try(
      user.get_user_by_token(ctx, token) |> result.map_error(UserError),
    )

    Ok(user)
  }

  case result {
    Ok(user) -> helper.json_response(["user"], [shared.user_to_json(user)], 200)
    Error(err) -> handle_error(req, err)
  }
}

fn handle_error(req: wisp.Request, err: UserError) {
  case err {
    UserError(err) -> user.handle_error(req, err)
    MissingCookieError -> {
      helper.error_response("unauthorized", 401)
    }
  }
}
