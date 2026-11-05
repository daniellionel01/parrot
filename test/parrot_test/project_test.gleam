import gleam/dict
import parrot/internal/project

pub fn name_test() {
  assert project.name() == Ok("parrot")
}

// https://github.com/daniellionel01/parrot/issues/101
pub fn sql_files_are_sorted_test() {
  let walked =
    dict.from_list([
      #("src/b/sql", ["src/b/sql/2.sql", "src/b/sql/1.sql"]),
      #("src/a/sql", ["src/a/sql/1.sql"]),
    ])

  assert project.sql_files(walked)
    == ["src/a/sql/1.sql", "src/b/sql/1.sql", "src/b/sql/2.sql"]
}
