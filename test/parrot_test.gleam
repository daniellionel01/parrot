import gleeunit
import parrot/internal/sqlc

pub fn main() {
  // so individual tests stay within gleeunit's timeout
  let assert Ok(_) = sqlc.download_binary()

  gleeunit.main()
}

pub fn os_cpu_test() {
  // just calling these functions to make sure they're accessible
  // and ffi is setup correctly
  //
  sqlc.get_os()
  sqlc.get_cpu()
}
