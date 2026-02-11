import gleam/dict
import gleam/regexp
import server/errors

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
    False -> Error(errors.ValidationError(validator.errors))
  }
}

pub fn add_error(validator: Validator, key: String, message: String) {
  validator.errors |> dict.insert(key, message)
}

pub fn check(validator: Validator, ok: Bool, key: String, message: String) {
  case !ok {
    True -> Validator(errors: dict.insert(validator.errors, key, message))
    False -> validator
  }
}

pub fn matches(value: String, rx: regexp.Regexp) {
  regexp.check(with: rx, content: value)
}
