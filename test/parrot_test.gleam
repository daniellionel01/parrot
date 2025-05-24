import gleeunit
import gleeunit/should
import parrot/internal/project

pub fn main() {
  gleeunit.main()
}

pub fn parrot_test() {
  project.project_name()
  |> should.equal("parrot")
}
