import gleam/bit_array
import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}

pub type Snippet {
  Snippet(
    id: Int,
    author: Int,
    title: String,
    content: String,
    expires_at: Timestamp,
    created_at: Timestamp,
  )
}

pub fn snippet_to_json(snippet: Snippet) -> json.Json {
  let Snippet(id:, author:, title:, content:, expires_at:, created_at:) =
    snippet
  json.object([
    #("id", json.int(id)),
    #("author", json.int(author)),
    #("title", json.string(title)),
    #("content", json.string(content)),
    #("expired", timestamp_encoder(expires_at)),
    #("created_at", timestamp_encoder(created_at)),
  ])
}

pub fn snippet_decoder() -> decode.Decoder(Snippet) {
  use id <- decode.field("id", decode.int)
  use author <- decode.field("author", decode.int)
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  use expires_at <- decode.field("expired", timestamp_decoder())
  use created_at <- decode.field("created_at", timestamp_decoder())
  decode.success(Snippet(
    id:,
    author:,
    title:,
    content:,
    expires_at:,
    created_at:,
  ))
}

fn timestamp_encoder(timestamp: Timestamp) {
  timestamp |> timestamp.to_rfc3339(calendar.utc_offset) |> json.string
}

fn timestamp_decoder() {
  use val <- decode.then(decode.string)
  case timestamp.parse_rfc3339(val) {
    Ok(ts) -> decode.success(ts)
    Error(_) -> decode.failure(timestamp.from_unix_seconds(0), "timestamp")
  }
}

pub type User {
  User(
    id: Int,
    username: String,
    email: String,
    password: BitArray,
    role_level: Int,
    created_at: Timestamp,
  )
}

pub fn user_to_json(user: User) -> json.Json {
  let User(id:, username:, email:, password:, role_level:, created_at:) = user
  json.object([
    #("id", json.int(id)),
    #("username", json.string(username)),
    #("email", json.string(email)),
    #("password", bitarray_encoder(password)),
    #("role_level", json.int(role_level)),
    #("created_at", timestamp_encoder(created_at)),
  ])
}

pub fn bitarray_encoder(bit_array: BitArray) {
  case bit_array.to_string(bit_array) {
    Ok(text) -> json.string(text)
    Error(_) -> json.string("Invalid UTF-8 Data")
  }
}

pub fn bitarray_decoder() {
  use val <- decode.then(decode.string)
  decode.success(bit_array.from_string(val))
}

pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use username <- decode.field("username", decode.string)
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", bitarray_decoder())
  use role_level <- decode.field("role_level", decode.int)
  use created_at <- decode.field("created_at", timestamp_decoder())
  decode.success(User(
    id:,
    username:,
    email:,
    password:,
    role_level:,
    created_at:,
  ))
}

pub type Role {
  Role(
    id: Int,
    name: String,
    level: Int,
    description: option.Option(String),
    created_at: Timestamp,
  )
}

pub fn role_decoder() -> decode.Decoder(Role) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use level <- decode.field("level", decode.int)
  use description <- decode.field("description", decode.optional(decode.string))
  use created_at <- decode.field("created_at", timestamp_decoder())
  decode.success(Role(id:, name:, level:, description:, created_at:))
}

pub fn role_to_json(role: Role) -> json.Json {
  let Role(id:, name:, level:, description:, created_at:) = role
  json.object([
    #("id", json.int(id)),
    #("name", json.string(name)),
    #("level", json.int(level)),
    #("description", case description {
      option.None -> json.null()
      option.Some(value) -> json.string(value)
    }),
    #("created_at", timestamp_encoder(created_at)),
  ])
}
