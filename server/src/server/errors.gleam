import argus
import gleam/dict
import gleam/http
import gleam/int
import gleam/list
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import pog
import wisp

pub type AppError {
  InternalServerError(String)
  Unauthorized
  BadRequest(String)
  NotFound(String)
  DatabaseError(pog.QueryError)
  HashError(argus.HashError)
  ValidationError(dict.Dict(String, String))
}

pub fn handle_error(req: wisp.Request, err: AppError) -> wisp.Response {
  let message = app_error_to_string(err)

  case err {
    NotFound(_) -> {
      format_log(req, message) |> wisp.log_warning()
      wisp.not_found()
    }
    Unauthorized -> {
      format_log(req, message) |> wisp.log_warning()
      wisp.response(401)
    }
    InternalServerError(_) | DatabaseError(_) | HashError(_) -> {
      format_log(req, message) |> wisp.log_error()
      wisp.internal_server_error()
    }
    BadRequest(_) -> {
      format_log(req, message) |> wisp.log_warning()
      wisp.bad_request("bad request")
    }
    ValidationError(_) -> {
      format_log(req, message) |> wisp.log_warning()
      wisp.bad_request(message)
    }
  }
}

pub fn format_log(req: wisp.Request, message: String) {
  timestamp.to_rfc3339(timestamp.system_time(), calendar.local_offset())
  <> " | "
  <> http_method_to_string(req.method)
  <> " | "
  <> req.path
  <> " | "
  <> message
}

fn http_method_to_string(method: http.Method) {
  case method {
    http.Get -> "GET"
    http.Post -> "POST"
    http.Head -> "HEAD"
    http.Put -> "PUT"
    http.Delete -> "DELETE"
    http.Trace -> "TRACE"
    http.Connect -> "CONNECT"
    http.Options -> "OPTIONS"
    http.Patch -> "PATCH"
    http.Other(_) -> "OTHER"
  }
}

pub fn app_error_to_string(err: AppError) {
  case err {
    InternalServerError(err) -> err
    Unauthorized -> "unauthorized"
    BadRequest(err) -> err
    NotFound(val) -> val <> " not found"
    DatabaseError(err) -> pog_error_to_string(err)
    HashError(err) -> argus_error_to_string(err)
    ValidationError(err) ->
      "validation error: "
      <> {
        err
        |> dict.to_list
        |> list.map(fn(pair) { pair.0 <> ": " <> pair.1 })
        |> string.join(", ")
      }
  }
}

fn pog_error_to_string(err: pog.QueryError) {
  case err {
    pog.ConstraintViolated(message:, constraint:, detail:) ->
      "constraint violated: { message:"
      <> message
      <> " constraint: "
      <> constraint
      <> " detail: "
      <> detail
      <> " }"
    pog.PostgresqlError(code:, name:, message:) ->
      "postgresql error: { code: "
      <> code
      <> " name: "
      <> name
      <> " message: "
      <> message
      <> " }"
    pog.UnexpectedArgumentCount(expected:, got:) ->
      "unexpected argument count: { expected: "
      <> int.to_string(expected)
      <> " got: "
      <> int.to_string(got)
      <> " }"
    pog.UnexpectedArgumentType(expected:, got:) ->
      "unexpected argument type: { expected: "
      <> expected
      <> " got: "
      <> got
      <> " }"
    pog.UnexpectedResultType(_) -> "unexpected result type"
    pog.QueryTimeout -> "query timeout"
    pog.ConnectionUnavailable -> "connection unavailable"
  }
}

fn argus_error_to_string(err: argus.HashError) {
  case err {
    argus.OutputPointerIsNull -> "output pointer is null"
    argus.OutputTooShort -> "output too short"
    argus.OutputTooLong -> "output too long"
    argus.PasswordTooShort -> "password too short"
    argus.PasswordTooLong -> "password too long"
    argus.SaltTooShort -> "salt too short"
    argus.SaltTooLong -> "salt too long"
    argus.AssociatedDataTooShort -> "associated data too short"
    argus.AssociatedDataTooLong -> "associated data too long"
    argus.SecretTooShort -> "secret too short"
    argus.SecretTooLong -> "secret too long"
    argus.TimeCostTooSmall -> "time cost too small"
    argus.TimeCostTooLarge -> "time cost too large"
    argus.MemoryCostTooSmall -> "memory cost too small"
    argus.MemoryCostTooLarge -> "memory cost too large"
    argus.TooFewLanes -> "too few lanes"
    argus.TooManyLanes -> "too many lanes"
    argus.PasswordPointerMismatch -> "password pointer mismatch"
    argus.SaltPointerMismatch -> "salt pointer mismatch"
    argus.SecretPointerMismatch -> "secret pointer mismatch"
    argus.AssociatedDataPointerMismatch -> "associated data pointer mismatch"
    argus.MemoryAllocationError -> "memory allocation error"
    argus.FreeMemoryCallbackNull -> "free memory callback null"
    argus.AllocateMemoryCallbackNull -> "allocate memory callback null"
    argus.IncorrectParameter -> "incorrect parameter"
    argus.IncorrectType -> "incorrect type"
    argus.InvalidAlgorithm -> "invalid algorithm"
    argus.OutputPointerMismatch -> "output pointer mismatch"
    argus.TooFewThreads -> "too few threads"
    argus.TooManyThreads -> "too many threads"
    argus.NotEnoughMemory -> "not enough memory"
    argus.EncodingFailed -> "encoding failed"
    argus.DecodingFailed -> "decoding failed"
    argus.ThreadFailure -> "thread failure"
    argus.DecodingLengthFailure -> "decoding length failure"
    argus.VerificationFailure -> "verification failure"
    argus.UnknownErrorCode -> "unknown error code"
  }
}
