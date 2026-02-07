import gleam/dynamic
import gleam/dynamic/decode
import gleam/list
import parrot/dev
import pog

pub type Connection {
  Pog(pog.Connection)
  Mock(
    fn(String, List(dev.Param)) ->
      Result(pog.Returned(dynamic.Dynamic), pog.QueryError),
  )
}

pub fn parrot_to_pog(param: dev.Param) -> pog.Value {
  case param {
    dev.ParamDynamic(_) -> panic as "dynamic parameter need to be implemented"
    dev.ParamBool(x) -> pog.bool(x)
    dev.ParamFloat(x) -> pog.float(x)
    dev.ParamInt(x) -> pog.int(x)
    dev.ParamString(x) -> pog.text(x)
    dev.ParamBitArray(x) -> pog.bytea(x)
    dev.ParamList(x) -> pog.array(parrot_to_pog, x)
    dev.ParamNullable(x) -> pog.nullable(fn(a) { parrot_to_pog(a) }, x)
    dev.ParamDate(x) -> pog.calendar_date(x)
    dev.ParamTimestamp(x) -> pog.timestamp(x)
  }
}

pub fn query(db: Connection, b: #(String, List(dev.Param), decode.Decoder(a))) {
  let query_string = b.0
  let params = b.1
  let decoder = b.2

  case db {
    Pog(conn) -> {
      query_string
      |> pog.query()
      |> pog.returning(decoder)
      |> list.fold(params, _, fn(acc, param) {
        let param = parrot_to_pog(param)
        pog.parameter(acc, param)
      })
      |> pog.execute(conn)
    }
    Mock(handler) -> {
      case handler(query_string, params) {
        Ok(returned) -> {
          let rows =
            list.try_map(returned.rows, fn(row) { decode.run(row, decoder) })
          case rows {
            Ok(rows) -> Ok(pog.Returned(returned.count, rows))
            Error(_) -> panic as "Mock decoding failed"
          }
        }
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn exec(db: Connection, b: #(String, List(dev.Param))) {
  let query_string = b.0
  let params = b.1

  case db {
    Pog(conn) -> {
      query_string
      |> pog.query()
      |> list.fold(params, _, fn(acc, param) {
        let param = parrot_to_pog(param)
        pog.parameter(acc, param)
      })
      |> pog.execute(conn)
    }
    Mock(handler) -> {
      case handler(query_string, params) {
        Ok(returned) -> Ok(pog.Returned(returned.count, []))
        Error(err) -> Error(err)
      }
    }
  }
}
