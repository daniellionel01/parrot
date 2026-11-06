import gleeunit
import parrot/internal/project
import parrot/internal/sqlc

pub fn main() -> Nil {
  // so the download does not count towards a test's timeout
  let assert Ok(_) =
    sqlc.managed_binary(in: project.work_directory(project.root()))
  gleeunit.main()
}
