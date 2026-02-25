import birdie
import gleam/string
import server/model/user
import validator/validator

pub fn validate_username_ok_test() {
  let validator = validator.new() |> user.validate_username("foo")

  let assert Ok(_) = validator.valid(validator)
}

pub fn validate_username_empty_test() {
  let validator =
    validator.new()
    |> user.validate_username("")

  validator.valid(validator)
  |> string.inspect()
  |> birdie.snap("validate username empty")
}

pub fn validate_username_too_short_test() {
  let validator = validator.new() |> user.validate_username("f")

  validator.valid(validator)
  |> string.inspect()
  |> birdie.snap("validate username too short")
}

pub fn validate_username_too_long_test() {
  let validator =
    validator.new() |> user.validate_username(string.repeat("k", 256))

  let assert Error(_) = validator.valid(validator)
}
