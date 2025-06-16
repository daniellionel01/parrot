import gleeunit
import gleeunit/should
import parrot/internal/project
import parrot/internal/sqlc

pub fn main() {
  gleeunit.main()
}

pub fn parrot_test() {
  project.project_name()
  |> should.equal("parrot")
}

pub fn os_cpu_test() {
  // just calling these functions to make sure they're accessible
  sqlc.get_os()
  sqlc.get_cpu()
}
