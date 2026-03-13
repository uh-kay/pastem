import gleam/dict
import gleam/list
import gleam/regexp
import gleam/string
import server/error
import server/helper
import wisp

pub type ValidationError {
  ValidationError(dict.Dict(String, String))
}

pub type Validator {
  Validator(errors: dict.Dict(String, String))
}

pub fn new() -> Validator {
  Validator(errors: dict.new())
}

pub fn email_rx() {
  let assert Ok(re) =
    regexp.from_string(
      "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
    )
  re
}

pub fn valid(validator: Validator) {
  case dict.is_empty(validator.errors) {
    True -> Ok(Nil)
    False -> Error(ValidationError(validator.errors))
  }
}

pub fn add_error(validator: Validator, key: String, message: String) {
  validator.errors |> dict.insert(key, message)
}

pub fn check(validator: Validator, ok: Bool, key: String, message: String) {
  case ok {
    True -> Validator(errors: dict.insert(validator.errors, key, message))
    False -> validator
  }
}

pub fn matches(value: String, rx: regexp.Regexp) {
  regexp.check(with: rx, content: value)
}

pub fn handle_error(req, err: ValidationError) {
  case err {
    ValidationError(err) -> {
      let msg = validation_error_to_string(err)
      error.format_log(req, msg) |> wisp.log_warning()
      helper.error_response(msg, 400)
    }
  }
}

fn validation_error_to_string(err) {
  "validation error: "
  <> dict.to_list(err)
  |> list.map(fn(pair) {
    let #(k, v) = pair
    k <> ": " <> v
  })
  |> string.join(",")
}
