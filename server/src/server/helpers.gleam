import gleam/time/timestamp

pub fn current_time() -> Int {
  let #(now, _) =
    timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds()
  now
}
