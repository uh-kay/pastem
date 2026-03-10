import gleam/crypto
import gleam/result
import server/error
import server/helper
import server/model/user
import shared
import wisp

pub fn get_current_user(ctx, req) {
  let result = {
    use cookie <- result.try(
      wisp.get_cookie(req, "auth_token", wisp.Signed)
      |> result.replace_error(error.Unauthorized),
    )

    let token = crypto.hash(crypto.Sha256, <<cookie:utf8>>)
    use user <- result.try(user.get_user_by_token(ctx, token))

    Ok(user)
  }

  case result {
    Ok(user) -> helper.json_response(["user"], [shared.user_to_json(user)], 200)
    Error(err) -> error.handle_error(req, err)
  }
}
