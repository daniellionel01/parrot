import exception
import filepath
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn sqlite_test() {
  // let path = filepath.join(".", "integration_test_project")
  // use <- exception.defer(fn() { todo as "cleanup" })

  todo as "scaffold gleam project"
  todo as "create sqlc files"
  todo as "create main.gleam for codegen"
  todo as "gen code"
  todo as "test generated code"
}

const project_toml = "name = \"integration_test_project\"
version = \"1.0.0\"

[dependencies]
sqlc_gen_gleam = { path = \"../..\" }
"

fn scaffold_project() {
  todo
}
