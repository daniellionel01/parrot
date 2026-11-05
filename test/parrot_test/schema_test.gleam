//// Fetching the schema from a database generates the same module as the
//// fixture's schema. Only runs with `gleam test integration`.

import argv
import gleam/list
import parrot/internal/database
import parrot_test/fixtures
import parrot_test/pipeline.{type Fixture, Fixture}
import parrot_test/test_database

pub fn sqlite_schema_test() {
  check(fixtures.sqlite())
}

pub fn postgres_schema_test() {
  check(fixtures.postgres())
}

pub fn mysql_schema_test() {
  check(fixtures.mysql())
}

fn check(fixtures: List(Fixture)) -> Nil {
  case list.contains(argv.load().arguments, "integration") {
    False -> Nil
    True -> list.each(fixtures, check_fixture)
  }
}

fn check_fixture(fixture: Fixture) -> Nil {
  let assert Ok(url) = test_database.create(fixture)
  let assert Ok(schema) =
    database.fetch_schema(fixture.engine, database.connection_string(url))

  let assert Ok(expected) = pipeline.run(fixture)
  let assert Ok(actual) =
    pipeline.run(Fixture(..fixture, name: fixture.name <> "_fetched", schema:))
    as { "could not generate code from the fetched schema:\n" <> schema }

  assert actual.module_without_seed == expected.module_without_seed
}
