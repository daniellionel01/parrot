import shork

pub fn main() {
  let _connection =
    shork.default_config()
    |> shork.user("root")
    |> shork.password("daniel")
    |> shork.database("parrot")
    |> shork.port(3309)
    |> shork.connect

  // list.each(sql, fn(statement) {
  //   let assert Ok(_) =
  //     shork.query(statement)
  //     |> shork.execute(connection)
  //     |> echo
  // })

  Ok(Nil)
}
