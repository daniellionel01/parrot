import filepath
import gleam/list
import parrot/internal/project
import parrot_test/tooling/pipeline
import simplifile
import tom

// https://github.com/daniellionel01/parrot/issues/101
pub fn sql_files_test() {
  let src = filepath.join(pipeline.scratch_dir("sql_files"), "src")
  let files = ["b/sql/2.sql", "b/sql/1.sql", "a/sql/1.sql", "a/sql/notes.txt"]
  list.each(["c/not_sql/1.sql", "a/1.sql", ..files], fn(file) {
    let path = filepath.join(src, file)
    let assert Ok(_) =
      simplifile.create_directory_all(filepath.directory_name(path))
    let assert Ok(_) = simplifile.write(path, "")
  })

  assert project.sql_files(src)
    == Ok(
      list.map(["a/sql/1.sql", "b/sql/1.sql", "b/sql/2.sql"], filepath.join(
        src,
        _,
      )),
    )
}

pub fn find_root_test() {
  let root = pipeline.scratch_dir("find_root")
  let nested = filepath.join(root, "src/app/sql")
  let assert Ok(_) = simplifile.create_directory_all(nested)
  let assert Ok(_) = simplifile.write(filepath.join(root, "gleam.toml"), "")

  assert project.find_root(nested) == Ok(root)
  assert project.find_root(root) == Ok(root)
}

pub fn parrot_is_dependency_test() {
  let assert Ok(toml) = tom.parse("[dependencies]\nparrot = \">= 3.0.0\"\n")
  assert project.parrot_is_dependency(toml)

  let assert Ok(toml) = tom.parse("[dev-dependencies]\nparrot = \">= 3.0.0\"\n")
  assert !project.parrot_is_dependency(toml)
}
