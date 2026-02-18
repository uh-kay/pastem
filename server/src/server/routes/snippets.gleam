import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import server/context.{type Context}
import server/errors.{BadRequest}
import server/helpers
import server/models/snippets
import shared
import validator/validator
import wisp.{type Request}

pub fn get_snippet(ctx: Context, req: Request, id: String) {
  let result = {
    use id <- result.try(parse_id(id))

    snippets.get_snippet(ctx, id)
  }

  case result {
    Ok(snippet) ->
      snippet
      |> shared.snippet_to_json
      |> helpers.json_response("snippet", 200)
    Error(err) ->
      case err {
        _ -> errors.handle_error(req, err)
      }
  }
}

pub fn list_snippets(ctx: Context, req: Request) {
  let result = {
    let queries = wisp.get_query(req)
    let limit = query_to_int(queries, "limit", 20)
    let offset = query_to_int(queries, "offset", 0)

    snippets.list_snippets(ctx, limit, offset)
  }

  case result {
    Ok(snippets) -> {
      snippets
      |> json.array(shared.snippet_to_json)
      |> helpers.json_response("snippets", 200)
    }
    Error(err) -> errors.handle_error(req, err)
  }
}

pub type StoreSnippet {
  StoreSnippet(title: String, content: String, ttl: Int)
}

pub fn store_snippet_to_json(store_snippet: StoreSnippet) -> json.Json {
  let StoreSnippet(title:, content:, ttl:) = store_snippet
  json.object([
    #("title", json.string(title)),
    #("content", json.string(content)),
    #("ttl", json.int(ttl)),
  ])
}

pub fn store_snippet_decoder() -> Decoder(StoreSnippet) {
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  use ttl <- decode.field("ttl", decode.int)
  decode.success(StoreSnippet(title:, content:, ttl:))
}

pub fn store_snippet(ctx: Context, req: Request) {
  use json <- wisp.require_json(req)

  let result = {
    result.try(
      decode.run(json, store_snippet_decoder())
        |> result.replace_error(BadRequest("missing title, content, or ttl")),
      fn(input) {
        let _ =
          validator.new()
          |> snippets.validate_title(input.title)
          |> snippets.validate_content(input.content)
          |> snippets.validate_ttl(input.ttl)
          |> validator.valid

        let expires_at =
          timestamp.add(timestamp.system_time(), duration.hours(input.ttl))

        snippets.create_snippet(ctx, input.title, input.content, expires_at)
      },
    )
  }

  case result {
    Ok(_) -> helpers.message_response("snippet created", 201)
    Error(err) -> errors.handle_error(req, err)
  }
}

type UpdateSnippet {
  UpdateSnippet(title: Option(String), content: Option(String))
}

fn update_snippet_decoder() -> Decoder(UpdateSnippet) {
  use title <- decode.optional_field(
    "title",
    None,
    decode.map(decode.string, Some),
  )
  use content <- decode.optional_field(
    "content",
    None,
    decode.map(decode.string, Some),
  )
  decode.success(UpdateSnippet(title:, content:))
}

pub fn update_snippet(ctx: Context, req: Request, id: String) {
  use json <- wisp.require_json(req)

  let result = {
    use input <- result.try(
      decode.run(json, update_snippet_decoder())
      |> result.replace_error(BadRequest("missing title and content")),
    )

    let _ =
      case input.title, input.content {
        Some(title), Some(content) -> {
          validator.new()
          |> snippets.validate_title(title)
          |> snippets.validate_content(content)
        }
        Some(title), None -> {
          validator.new()
          |> snippets.validate_title(title)
        }
        None, Some(content) -> {
          validator.new()
          |> snippets.validate_content(content)
        }
        None, None -> validator.new()
      }
      |> validator.valid

    use id <- result.try(parse_id(id))

    snippets.update_snippet(ctx, input.title, input.content, id)
  }

  case result {
    Ok(row) ->
      case row.count {
        1 -> helpers.message_response("snippet updated", 200)
        _ -> helpers.error_response("edit conflict", 409)
      }
    Error(err) -> errors.handle_error(req, err)
  }
}

pub fn delete_snippet(ctx: Context, req: Request, id: String) {
  let result = {
    use id <- result.try(parse_id(id))

    snippets.delete_snippet(ctx, id)
  }

  case result {
    Ok(_) -> helpers.message_response("snippet deleted", 200)
    Error(err) -> errors.handle_error(req, err)
  }
}

fn parse_id(id: String) {
  case int.parse(id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(BadRequest("invalid id"))
  }
}

fn query_to_int(queries, key, fallback) {
  list.key_find(queries, key)
  |> result.unwrap("")
  |> int.parse()
  |> result.unwrap(fallback)
}
