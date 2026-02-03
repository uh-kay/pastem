import gleam/bit_array
import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type Snippet {
  Snippet(
    id: Int,
    author: Int,
    title: String,
    content: String,
    expires_at: Int,
    updated_at: Int,
    created_at: Int,
  )
}

pub fn snippet_to_json(snippet: Snippet) -> json.Json {
  let Snippet(
    id:,
    author:,
    title:,
    content:,
    expires_at:,
    updated_at:,
    created_at:,
  ) = snippet
  json.object([
    #("id", json.int(id)),
    #("author", json.int(author)),
    #("title", json.string(title)),
    #("content", json.string(content)),
    #("expires_at", json.int(expires_at)),
    #("updated_at", json.int(updated_at)),
    #("created_at", json.int(created_at)),
  ])
}

pub fn snippet_decoder() -> decode.Decoder(Snippet) {
  use id <- decode.field("id", decode.int)
  use author <- decode.field("author", decode.int)
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  use expires_at <- decode.field("expires_at", decode.int)
  use updated_at <- decode.field("updated_at", decode.int)
  use created_at <- decode.field("created_at", decode.int)
  decode.success(Snippet(
    id:,
    author:,
    title:,
    content:,
    expires_at:,
    updated_at:,
    created_at:,
  ))
}

pub type User {
  User(
    id: Int,
    username: String,
    email: String,
    password: BitArray,
    role_level: Int,
    created_at: Int,
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
    #("created_at", json.int(created_at)),
  ])
}

pub fn user_decoder() -> decode.Decoder(User) {
  use id <- decode.field("id", decode.int)
  use username <- decode.field("username", decode.string)
  use email <- decode.field("email", decode.string)
  use password <- decode.field("password", decode.bit_array)
  use role_level <- decode.field("role_level", decode.int)
  use created_at <- decode.field("created_at", decode.int)
  decode.success(User(
    id:,
    username:,
    email:,
    password:,
    role_level:,
    created_at:,
  ))
}

pub fn bitarray_encoder(bit_array: BitArray) {
  case bit_array.to_string(bit_array) {
    Ok(text) -> json.string(text)
    Error(_) -> json.string("Invalid UTF-8 Data")
  }
}

pub type Role {
  Role(
    id: Int,
    name: String,
    level: Int,
    description: option.Option(String),
    created_at: Int,
  )
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
    #("created_at", json.int(created_at)),
  ])
}

pub fn role_decoder() -> decode.Decoder(Role) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use level <- decode.field("level", decode.int)
  use description <- decode.field("description", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.int)
  decode.success(Role(id:, name:, level:, description:, created_at:))
}
