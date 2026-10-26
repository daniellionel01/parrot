import gleeunit
import parrot/internal/project
import parrot/internal/sqlc
import parrot_test/compile_check

pub fn main() {
  // Done once up front, so the individual tests stay within
  // gleeunit's timeout.
  let assert Ok(_) = sqlc.download_binary()
  let assert Ok(_) = compile_check.setup()

  gleeunit.main()
}

pub fn project_name_test() {
  assert project.name() == "parrot"
}

pub fn os_cpu_test() {
  // just calling these functions to make sure they're accessible
  // and ffi is setup correctly
  //
  sqlc.get_os()
  sqlc.get_cpu()
}
