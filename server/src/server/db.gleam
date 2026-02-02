import gleam/dynamic/decode
import gleam/list
import parrot/dev
import pog

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

pub fn query(
  db: pog.Connection,
  b: #(String, List(dev.Param), decode.Decoder(a)),
) {
  b.0
  |> pog.query()
  |> pog.returning(b.2)
  |> list.fold(b.1, _, fn(acc, param) {
    let param = parrot_to_pog(param)
    pog.parameter(acc, param)
  })
  |> pog.execute(db)
}

pub fn exec(db: pog.Connection, b: #(String, List(dev.Param))) {
  b.0
  |> pog.query()
  |> list.fold(b.1, _, fn(acc, param) {
    let param = parrot_to_pog(param)
    pog.parameter(acc, param)
  })
  |> pog.execute(db)
}
