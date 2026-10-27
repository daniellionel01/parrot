import argv
import gleam/int
import gleam/list
import gleam/string
import parrot/error
import parrot/internal/database
import parrot_test/fixtures
import parrot_test/pipeline.{type Fixture, Fixture}
import parrot_test/test_database

// === SQLITE ===============================================================

pub fn sqlite_basic_schema_test() {
  check(fixtures.sqlite_basic())
}

pub fn sqlite_column_types_schema_test() {
  check(fixtures.sqlite_column_types())
}

pub fn sqlite_named_and_slice_params_schema_test() {
  check(fixtures.sqlite_named_and_slice_params())
}

pub fn sqlite_app_fixture_schema_test() {
  check(fixtures.sqlite_app_fixture())
}

pub fn sqlite_no_optional_fixture_schema_test() {
  check(fixtures.sqlite_no_optional_fixture())
}

// === POSTGRESQL ===========================================================

pub fn postgres_enums_schema_test() {
  check(fixtures.postgres_enums())
}

pub fn postgres_arrays_schema_test() {
  check(fixtures.postgres_arrays())
}

pub fn postgres_column_types_schema_test() {
  check(fixtures.postgres_column_types())
}

pub fn postgres_joins_and_commands_schema_test() {
  check(fixtures.postgres_joins_and_commands())
}

pub fn postgres_app_fixture_schema_test() {
  check(fixtures.postgres_app_fixture())
}

// === MYSQL ================================================================

pub fn mysql_column_types_schema_test() {
  check(fixtures.mysql_column_types())
}

pub fn mysql_app_fixture_schema_test() {
  check(fixtures.mysql_app_fixture())
}

// === HELPERS ==============================================================

fn check(fixture: Fixture) -> Nil {
  case list.contains(argv.load().arguments, "integration") {
    False -> Nil
    True -> do_check(fixture)
  }
}

fn do_check(fixture: Fixture) -> Nil {
  let connection_string = case test_database.create(fixture) {
    Ok(connection_string) -> connection_string
    Error(e) -> panic as { "could not set up the test database: " <> e }
  }

  let schema = case
    database.fetch_schema(
      fixture.engine,
      database.connection_string(connection_string),
    )
  {
    Ok(schema) -> schema
    Error(e) -> panic as { "could not fetch schema: " <> error.to_string(e) }
  }

  let assert Ok(expected) = pipeline.run(fixture)
  let fetched = Fixture(..fixture, name: fixture.name <> "_fetched", schema:)
  let actual = case pipeline.run(fetched) {
    Ok(output) -> output
    Error(e) ->
      panic as {
        "could not generate code from the fetched schema: "
        <> error.to_string(e)
        <> "\n\nfetched schema:\n"
        <> schema
      }
  }

  case actual.module_without_seed == expected.module_without_seed {
    True -> Nil
    False ->
      panic as {
        "the module generated from the fetched schema differs:\n"
        <> diff(expected.module_without_seed, actual.module_without_seed)
        <> "\n\nfetched schema:\n"
        <> schema
      }
  }
}

/// A minimal line diff, good enough to point at what changed.
///
fn diff(expected: String, actual: String) -> String {
  let expected = string.split(expected, "\n")
  let actual = string.split(actual, "\n")
  let missing =
    list.filter(expected, fn(line) { !list.contains(actual, line) })
    |> list.map(fn(line) { "- " <> line })
  let added =
    list.filter(actual, fn(line) { !list.contains(expected, line) })
    |> list.map(fn(line) { "+ " <> line })

  [
    "("
      <> int.to_string(list.length(missing))
      <> " lines missing, "
      <> int.to_string(list.length(added))
      <> " lines added)",
    ..list.append(missing, added)
  ]
  |> string.join("\n")
}
