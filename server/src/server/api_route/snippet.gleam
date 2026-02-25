import gleam/dynamic/decode.{type Decoder}
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import server/context.{type Context}
import server/error.{BadRequest}
import server/helper
import server/model/snippet
import shared
import validator/validator
import wisp.{type Request}

pub fn get_snippet(ctx: Context, req: Request, id: String) {
  let result = {
    use id <- result.try(
      int.parse(id) |> result.replace_error(BadRequest("invalid id")),
    )

    snippet.get_snippet(ctx, id)
  }

  case result {
    Ok(snippet) ->
      helper.json_response(["snippet"], [shared.snippet_to_json(snippet)], 200)
    Error(err) ->
      case err {
        _ -> error.handle_error(req, err)
      }
  }
}

pub fn list_snippets(ctx: Context, req: Request) {
  let result = {
    let queries = wisp.get_query(req)
    let limit = helper.query_to_int(queries, "limit", 20)
    let offset = helper.query_to_int(queries, "offset", 0)

    use count <- result.try(snippet.get_snippet_count(ctx))
    use snippets <- result.try(snippet.list_snippets(ctx, limit, offset))

    Ok(#(snippets, count))
  }

  case result {
    Ok(#(snippets, count)) ->
      helper.json_response(
        ["snippets", "count"],
        [json.array(snippets, shared.snippet_to_json), json.int(count)],
        200,
      )
    Error(err) -> error.handle_error(req, err)
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
        use _ <- result.try(
          validator.new()
          |> snippet.validate_title(input.title)
          |> snippet.validate_content(input.content)
          |> snippet.validate_ttl(input.ttl)
          |> validator.valid,
        )

        let expires_at =
          timestamp.add(timestamp.system_time(), duration.hours(input.ttl))

        snippet.create_snippet(ctx, input.title, input.content, expires_at)
      },
    )
  }

  case result {
    Ok(_) ->
      helper.json_response(["message"], [json.string("snippet created")], 201)
    Error(err) -> error.handle_error(req, err)
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

    use _ <- result.try(
      case input.title, input.content {
        Some(title), Some(content) ->
          validator.new()
          |> snippet.validate_title(title)
          |> snippet.validate_content(content)
        Some(title), None ->
          validator.new()
          |> snippet.validate_title(title)
        None, Some(content) ->
          validator.new()
          |> snippet.validate_content(content)
        None, None -> validator.new()
      }
      |> validator.valid,
    )

    use id <- result.try(
      int.parse(id) |> result.replace_error(BadRequest("invalid id")),
    )

    snippet.update_snippet(ctx, input.title, input.content, id)
  }

  case result {
    Ok(row) ->
      case row.count {
        1 ->
          helper.json_response(
            ["message"],
            [json.string("snippet updated")],
            200,
          )
        _ -> helper.error_response("edit conflict", 409)
      }
    Error(err) -> error.handle_error(req, err)
  }
}

pub fn delete_snippet(ctx: Context, req: Request, id: String) {
  let result = {
    use id <- result.try(
      int.parse(id) |> result.replace_error(BadRequest("invalid id")),
    )

    snippet.delete_snippet(ctx, id)
  }

  case result {
    Ok(_) ->
      helper.json_response(["message"], [json.string("snippet deleted")], 200)
    Error(err) -> error.handle_error(req, err)
  }
}
