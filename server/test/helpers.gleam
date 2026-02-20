import gleam/dynamic
import gleam/list
import pog
import server/db
import server/helpers
import server/sql
import shared

pub fn snippet_to_dynamic(snippets: List(shared.Snippet)) {
  list.map(snippets, fn(snippet) {
    dynamic.array([
      dynamic.int(snippet.id),
      dynamic.int(snippet.author),
      dynamic.string(snippet.title),
      dynamic.string(snippet.content),
      dynamic.int(snippet.expires_at),
      dynamic.int(snippet.updated_at),
      dynamic.int(snippet.created_at),
    ])
  })
}

// pub fn token_to_dynamic(token: tokens.Token) {
//   dynamic.array([
//     dynamic.string(token.plaintext),
//     dynamic.bit_array(token.hash),
//     dynamic.int(token.user_id),
//     dynamic.int(token.expiry),
//     dynamic.string(token.scope),
//   ])
// }

pub fn user_to_dynamic(user: shared.User) {
  dynamic.array([
    dynamic.int(user.id),
    dynamic.string(user.username),
    dynamic.string(user.email),
    dynamic.bit_array(user.password),
    dynamic.int(user.role_level),
    dynamic.int(user.created_at),
  ])
}

pub const user = shared.User(
  id: 1,
  username: "test user",
  email: "user@example.com",
  password: <<>>,
  role_level: 1,
  created_at: 100,
)

// pub fn get_test_token() {
//   tokens.Token(
//     plaintext: "test",
//     hash: bit_array.from_string("test"),
//     user_id: 1,
//     expiry: 1,
//     scope: tokens.scope_authentication,
//   )
// }

pub const snippet = [
  shared.Snippet(
    id: 1,
    author: 1,
    title: "Test Snippet",
    content: "Hello World",
    version: 1,
    expires_at: 100,
    updated_at: 100,
    created_at: 100,
  ),
  shared.Snippet(
    id: 2,
    author: 1,
    title: "Test Snippet 2",
    content: "Hello World 2",
    version: 1,
    expires_at: 100,
    updated_at: 100,
    created_at: 100,
  ),
]

pub fn mock_query(result result: Result(Int, pog.QueryError)) -> db.Connection {
  use query, _params <- db.Mock
  let list_query_sql =
    sql.get_snippets(expires_at: helpers.current_time(), limit: 0, offset: 0).0
  let get_snippet_sql =
    sql.get_snippet(id: 0, expires_at: helpers.current_time()).0
  let get_user_by_token_sql = sql.get_user_by_token(<<>>).0
  let #(create_snippet_sql, _params) =
    sql.create_snippet(
      author: 1,
      title: "test title",
      content: "test content",
      expires_at: 100,
      updated_at: 100,
      created_at: 100,
    )

  case query {
    q if q == list_query_sql || q == get_snippet_sql || q == create_snippet_sql -> {
      case result {
        Ok(0) -> Ok(pog.Returned(0, []))
        Ok(count) -> Ok(pog.Returned(count, snippet_to_dynamic(snippet)))
        Error(err) -> Error(err)
      }
    }
    q if q == get_user_by_token_sql -> {
      case result {
        Ok(count) -> Ok(pog.Returned(count, [user_to_dynamic(user)]))
        Error(err) -> Error(err)
      }
    }
    _ -> panic as { "Unexpected query: " <> query }
  }
}
// pub fn mock_user(result result: Result(Int, pog.QueryError)) -> db.Connection {
//   use query, _params <- db.Mock
//   let hash =
//     tokens.generate_token(1, duration.hours(1), tokens.scope_authentication)
//   let #(create_new_token_sql, _params) =
//     sql.create_new_token(
//       hash: hash.hash,
//       user_id: hash.user_id,
//       expiry: hash.expiry,
//       scope: hash.scope,
//     )

//   case query {
//     q if q == create_new_token_sql -> {
//       case result {
//         Ok(0) -> Ok(pog.Returned(0, []))
//         Ok(count) ->
//           Ok(pog.Returned(count, [token_to_dynamic(get_test_token())]))
//         Error(err) -> Error(err)
//       }
//     }
//     _ -> panic as { "Unexpected query: " <> query }
//   }
// }
