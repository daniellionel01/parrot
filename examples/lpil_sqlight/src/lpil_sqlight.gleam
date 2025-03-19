import gleam/dynamic/decode
import lpil_sqlight/sql
import simplifile
import sqlight

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

  // let cat_decoder = {
  //   use name <- decode.field(0, decode.string)
  //   use age <- decode.field(1, decode.int)
  //   decode.success(#(name, age))
  // }
  let cat_decoder = sql.get_cats_by_age_decoder()

  let sql =
    "
  select name, age from cats
  where age < ?
  "

  echo sqlight.query(
    sql,
    on: conn,
    with: [sqlight.int(7)],
    expecting: cat_decoder,
  )
}
