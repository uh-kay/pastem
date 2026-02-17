import formal/form.{type Form}
import gleam/dynamic/decode.{type Decoder}
import gleam/http.{Post}
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string_tree
import gleam/time/duration
import gleam/time/timestamp
import lustre/attribute
import lustre/element
import lustre/element/html
import server/context.{type Context}
import server/errors.{BadRequest, InternalServerError, NotFound, Unauthorized}
import server/helpers
import server/models/snippets
import shared.{type Snippet}
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

type StoreSnippet {
  StoreSnippet(title: String, content: String, ttl: Int)
}

fn store_snippet_to_json(store_snippet: StoreSnippet) -> json.Json {
  let StoreSnippet(title:, content:, ttl:) = store_snippet
  json.object([
    #("title", json.string(title)),
    #("content", json.string(content)),
    #("ttl", json.int(ttl)),
  ])
}

fn store_snippet_decoder() -> Decoder(StoreSnippet) {
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

pub fn create_snippet_submit(req) {
  use formdata <- wisp.require_form(req)

  let form = create_snippet_form() |> form.add_values(formdata.values)

  case form.run(form) {
    Ok(data) -> {
      let result = {
        use api_req <- result.try(
          request.to("http://localhost:8000/v1/snippets")
          |> result.replace_error(InternalServerError("internal server error")),
        )

        let body = store_snippet_to_json(data) |> json.to_string

        api_req
        |> request.set_method(Post)
        |> request.set_header("content-type", "application/json")
        |> request.set_body(body)
        |> httpc.send()
        |> result.replace_error(InternalServerError("internal server error"))
      }
      case result {
        Ok(_) -> wisp.redirect("/")
        Error(err) -> {
          echo err
          wisp.internal_server_error()
        }
      }
    }
    Error(err) -> {
      echo err
      wisp.internal_server_error()
    }
  }
}

fn create_snippet_form() {
  form.new({
    use title <- form.field("title", form.parse_string)
    use content <- form.field("content", form.parse_string)
    use ttl <- form.field("ttl", form.parse_int)

    form.success(StoreSnippet(title:, content:, ttl:))
  })
}

pub fn create_snippet_page() {
  let form = create_snippet_form()

  create_snippet_page_view(form)
  |> string_tree.to_string
  |> wisp.html_response(200)
}

fn create_snippet_page_view(form) {
  html.form([attribute.method("post"), attribute.class("flex flex-col")], [
    field_input(form, "title", "text", "Title"),
    html.label([], [
      html.text("Content"),
      html.textarea([attribute.name("content"), attribute.class("border")], ""),
    ]),
    field_input(form, "ttl", "number", "TTL"),
    html.button([attribute.type_("submit")], [html.text("Submit")]),
  ])
  |> page_layout_view("Create Snippet", _)
}

fn field_input(form: Form(t), name: String, kind: String, label: String) {
  let errors = form.field_error_messages(form, name)

  html.label([], [
    html.text(label),
    html.input([
      attribute.class("border"),
      attribute.type_(kind),
      attribute.name(name),
      attribute.value(form.field_value(form, name)),
      case errors {
        [] -> attribute.none()
        _ -> attribute.aria_invalid("true")
      },
    ]),
    ..list.map(errors, fn(msg) { html.small([], [element.text(msg)]) })
  ])
}

fn page_layout_view(title, content) {
  html.html([], [
    html.head([], [
      html.title([], "Create Snippet"),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/server/output.css"),
      ]),
      html.script(
        [attribute.type_("module"), attribute.src("/static/client.js")],
        "",
      ),
    ]),
    html.body([], [
      html.h1([], [html.text(title)]),
      content,
    ]),
  ])
  |> element.to_document_string_tree
}

pub fn snippet_page(id) {
  let result = {
    use api_req <- result.try(
      request.to("http://localhost:8000/v1/snippets/" <> id)
      |> result.replace_error(InternalServerError("invalid URL")),
    )

    use res <- result.try(
      httpc.send(api_req)
      |> result.replace_error(InternalServerError("API connection failed")),
    )

    case res.status >= 200 && res.status < 300 {
      False ->
        case res.status {
          404 -> Error(NotFound("snippet"))
          _ -> Error(InternalServerError("internal server error"))
        }
      True -> {
        json.parse(res.body, shared.snippet_item_decoder())
        |> result.replace_error(InternalServerError("Failed to decode snippet"))
      }
    }
  }

  case result {
    Ok(snippet) -> {
      snippet_page_view(snippet)
      |> string_tree.to_string
      |> wisp.html_response(200)
    }
    Error(err) -> {
      case err {
        BadRequest(_) -> helpers.html_error_response(400)
        NotFound(_) -> helpers.html_error_response(404)
        Unauthorized -> helpers.html_error_response(401)
        _ -> wisp.internal_server_error()
      }
    }
  }
}

fn snippet_page_view(snippet: Snippet) {
  html.div([], [
    html.p([], [html.text(int.to_string(snippet.id))]),
    html.p([], [html.text(snippet.title)]),
  ])
  |> element.to_document_string_tree
}
