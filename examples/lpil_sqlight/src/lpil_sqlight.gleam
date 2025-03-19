import gleam/list
import lpil_sqlight/sql
import parrot/sql as parrot
import simplifile
import sqlight

pub fn params_to_sqlight(args: List(parrot.Param)) -> List(sqlight.Value) {
  list.map(args, fn(arg) {
    case arg {
      parrot.ParamInt(a) -> sqlight.int(a)
      parrot.ParamBool(a) -> sqlight.bool(a)
      parrot.ParamFloat(a) -> sqlight.float(a)
      parrot.ParamString(a) -> sqlight.text(a)
    }
  })
}

pub fn main() {
  use conn <- sqlight.with_connection(":memory:")

  let assert Ok(schema) = simplifile.read("sql/schema.sql")
  let sql = schema <> "
  insert into cats (name, age) values
  ('Nubi', 4),
  ('Biffy', 10),
  ('Ginny', 6);
  "
  let assert Ok(Nil) = sqlight.exec(sql, conn)

  let #(raw_sql, args) = sql.get_cats_by_age(7)

  echo sqlight.query(
    raw_sql,
    on: conn,
    with: params_to_sqlight(args),
    expecting: sql.get_cats_by_age_decoder(),
  )
}
