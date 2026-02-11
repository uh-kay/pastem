import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import server/context
import server/errors
import server/helpers
import server/middleware
import server/models/snippets
import shared
import validator/validator
import wisp

pub fn snippets(ctx: context.Context, req: wisp.Request, id: String) {
  case req.method, id {
    http.Get, "" -> list_snippets(ctx, req)
    http.Get, id -> view_snippet(ctx, req, id)

    http.Post, _ -> {
      use req, ctx <- middleware.require_auth(req, ctx)
      create_snippet(ctx, req)
    }
    http.Patch, id -> {
      use req, ctx <- middleware.require_admin_or_owner(req, ctx, id)
      update_snippet(ctx, req, id)
    }
    http.Delete, id -> {
      use req, ctx <- middleware.require_admin_or_owner(req, ctx, id)
      delete_snippet(ctx, req, id)
    }
    _, _ ->
      wisp.method_not_allowed([http.Get, http.Post, http.Patch, http.Delete])
  }
}

fn view_snippet(ctx: context.Context, req: wisp.Request, id: String) {
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

fn list_snippets(ctx: context.Context, req: wisp.Request) {
  let result = {
    let queries = wisp.get_query(req)
    let limit = parse_int_query(queries, "limit", 20)
    let offset = parse_int_query(queries, "offset", 0)

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

type CreateSnippet {
  CreateSnippet(title: String, content: String, ttl: Int)
}

fn create_snippet_decoder() -> decode.Decoder(CreateSnippet) {
  use title <- decode.field("title", decode.string)
  use content <- decode.field("content", decode.string)
  use ttl <- decode.field("ttl", decode.int)
  decode.success(CreateSnippet(title:, content:, ttl:))
}

fn create_snippet(ctx: context.Context, req: wisp.Request) {
  use json <- wisp.require_json(req)

  let result = {
    use input <- result.try(
      decode.run(json, create_snippet_decoder())
      |> result.replace_error(errors.BadRequest(
        "missing title, content, or ttl",
      )),
    )

    let _ =
      validator.new()
      |> snippets.validate_title(input.title)
      |> snippets.validate_content(input.content)
      |> snippets.validate_ttl(input.ttl)
      |> validator.valid

    let expires_at =
      timestamp.add(timestamp.system_time(), duration.hours(input.ttl))

    snippets.create_snippet(ctx, input.title, input.content, expires_at)
  }

  case result {
    Ok(_) -> helpers.message_response("snippet created", 201)
    Error(err) -> errors.handle_error(req, err)
  }
}

type UpdateSnippet {
  UpdateSnippet(title: option.Option(String), content: option.Option(String))
}

fn update_snippet_decoder() -> decode.Decoder(UpdateSnippet) {
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

fn update_snippet(ctx: context.Context, req: wisp.Request, id: String) {
  use json <- wisp.require_json(req)

  let result = {
    use input <- result.try(
      decode.run(json, update_snippet_decoder())
      |> result.replace_error(errors.BadRequest("missing title and content")),
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

fn delete_snippet(ctx: context.Context, req: wisp.Request, id: String) {
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
    Error(_) -> Error(errors.BadRequest("invalid id"))
  }
}

fn parse_int_query(queries, key, fallback) {
  list.key_find(queries, key)
  |> result.unwrap("")
  |> int.parse()
  |> result.unwrap(fallback)
}
