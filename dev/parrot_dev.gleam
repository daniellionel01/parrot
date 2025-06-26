//// Basically a scratch pad to test out different functions while developing them

import parrot/internal/shellout

pub fn main() {
  let _ =
    shellout.command(run: "pg_dump", with: ["--version"], in: ".", opt: [])
    |> echo

  shellout.command(
    run: "./sqlc",
    with: ["version"],
    in: "./integration_test/sqlite/build/.parrot/",
    opt: [],
  )
  |> echo
}
