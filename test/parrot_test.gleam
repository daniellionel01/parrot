import gleeunit
import parrot/internal/project
import parrot/internal/sqlc

pub fn main() {
  gleeunit.main()
}

pub fn parrot_test() {
  assert project.project_name() == "parrot"
}

pub fn os_cpu_test() {
  // just calling these functions to make sure they're accessible
  echo sqlc.get_os()
  echo sqlc.get_cpu()
}
