import gleam/dynamic/decode
import gleam/http
import gleam/int
import gleam/json
import gleam/option
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import server/context
import server/db/snippets
import server/errors
import server/middleware
import shared
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
      use req, ctx <- middleware.require_auth(req, ctx)
      update_snippet(ctx, req, id)
    }
    http.Delete, id -> {
      use req, ctx <- middleware.require_admin(req, ctx)
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
      |> json.to_string
      |> wisp.json_response(200)
    Error(err) ->
      case err {
        _ -> errors.handle_error(req, err)
      }
  }
}

fn list_snippets(ctx: context.Context, req: wisp.Request) {
  case snippets.list_snippets(ctx) {
    Ok(snippets) -> {
      snippets
      |> json.array(shared.snippet_to_json)
      |> json.to_string
      |> wisp.json_response(200)
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

    let expires_at =
      timestamp.add(timestamp.system_time(), duration.hours(input.ttl))

    snippets.create_snippet(ctx, input.title, input.content, expires_at)
  }

  case result {
    Ok(_) -> wisp.created()
    Error(err) -> errors.handle_error(req, err)
  }
}

type UpdateSnippet {
  UpdateSnippet(title: option.Option(String), content: option.Option(String))
}

fn update_snippet_decoder() -> decode.Decoder(UpdateSnippet) {
  use title <- decode.optional_field(
    "title",
    option.None,
    decode.optional(decode.string),
  )
  use content <- decode.optional_field(
    "content",
    option.None,
    decode.optional(decode.string),
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

    use id <- result.try(parse_id(id))

    use existing_snippet <- result.try(snippets.get_snippet(ctx, id))

    snippets.update_snippet(
      ctx,
      input.title,
      input.content,
      existing_snippet.title,
      existing_snippet.content,
      id,
    )
  }

  case result {
    Ok(_) -> wisp.no_content()
    Error(err) -> errors.handle_error(req, err)
  }
}

fn delete_snippet(ctx: context.Context, req: wisp.Request, id: String) {
  let result = {
    use id <- result.try(parse_id(id))

    snippets.delete_snippet(ctx, id)
  }

  case result {
    Ok(_) -> wisp.no_content()
    Error(err) -> errors.handle_error(req, err)
  }
}

fn parse_id(id: String) {
  case int.parse(id) {
    Ok(id) -> Ok(id)
    Error(_) -> Error(errors.BadRequest("invalid id"))
  }
}
