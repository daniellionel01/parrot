import gleeunit
import parrot/internal/project
import parrot/internal/sqlc

pub fn main() {
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
