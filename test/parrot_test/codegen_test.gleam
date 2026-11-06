//// Review snapshots with `gleam run -m birdie`.
////
//// With `gleam test integration`, every fixture's schema is also loaded into
//// a real database and fetching it from there has to generate the same
//// module.

import argv
import birdie
import gleam/list
import gleam/string
import parrot/internal/codegen/runtime
import parrot/internal/database.{Mysql, Postgresql, Sqlite}
import parrot/internal/error
import parrot_test/tooling/fixture
import parrot_test/tooling/pipeline.{type Fixture, Fixture}
import parrot_test/tooling/summary
import parrot_test/tooling/test_database

pub fn sqlite_basic_test() {
  check(fixture.sqlite_basic())
}

pub fn sqlite_column_types_test() {
  check(fixture.sqlite_column_types())
}

pub fn sqlite_named_and_slice_params_test() {
  check(fixture.sqlite_named_and_slice_params())
}

pub fn sqlite_keywords_test() {
  check(fixture.sqlite_keywords())
}

pub fn sqlite_app_test() {
  check(fixture.sqlite_app())
}

pub fn sqlite_no_optional_test() {
  check(fixture.sqlite_no_optional())
}

pub fn postgres_enums_test() {
  check(fixture.postgres_enums())
}

pub fn postgres_arrays_test() {
  check(fixture.postgres_arrays())
}

pub fn postgres_column_types_test() {
  check(fixture.postgres_column_types())
}

pub fn postgres_joins_and_commands_test() {
  check(fixture.postgres_joins_and_commands())
}

pub fn postgres_app_test() {
  check(fixture.postgres_app())
}

pub fn mysql_column_types_test() {
  check(fixture.mysql_column_types())
}

pub fn mysql_app_test() {
  check(fixture.mysql_app())
}

// === ERRORS ===============================================================

pub fn sqlite_postgres_style_parameter_error_test() {
  error_fixture(
    Sqlite,
    schema: "create table users (id integer primary key);",
    queries: "
-- name: GetUser :one
select * from users where id = $1;",
  )
  |> snap_error(title: "sqlite postgres style param")
}

pub fn postgres_unknown_table_error_test() {
  error_fixture(
    Postgresql,
    schema: "create table users (id serial primary key);",
    queries: "
-- name: GetPost :one
select * from posts where id = $1;",
  )
  |> snap_error(title: "unknown table")
}

pub fn enum_and_query_name_collision_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create type status as enum ('open', 'closed');
create table tickets (id serial primary key, status status not null);",
    queries: "
-- name: Status :many
select status from tickets;",
  )
  |> snap_error(title: "enum and query name clash")
}

pub fn empty_enum_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create type nothing as enum ();
create table things (id serial primary key, value nothing not null);",
    queries: "
-- name: GetThings :many
select value from things;",
  )
  |> snap_error(title: "empty enum")
}

pub fn duplicate_enum_value_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create type ticket_status as enum ('open', 'closed');
create type door_status as enum ('open', 'locked');
create table tickets (id serial primary key, status ticket_status not null);
create table doors (id serial primary key, status door_status not null);",
    queries: "
-- name: TicketStatuses :many
select status from tickets;

-- name: DoorStatuses :many
select status from doors;",
  )
  |> snap_error(title: "duplicate enum value")
}

pub fn enum_values_colliding_in_pascal_case_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create type ticket_status as enum ('open', 'OPEN', 'closed');
create table tickets (id serial primary key, status ticket_status not null);",
    queries: "
-- name: TicketStatuses :many
select status from tickets;",
  )
  |> snap_error(title: "enum values clash in pascal case")
}

pub fn enum_value_and_row_type_collision_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create type ticket_status as enum ('open', 'closed');
create table tickets (id serial primary key, status ticket_status not null);",
    queries: "
-- name: Open :many
select id, status from tickets where status = 'open';",
  )
  |> snap_error(title: "enum value and row type clash")
}

pub fn enum_value_and_runtime_collision_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create type event_kind as enum ('date', 'meeting');
create table events (id serial primary key, kind event_kind not null);",
    queries: "
-- name: GetEvents :many
select kind from events;",
  )
  |> snap_error(title: "enum value and runtime clash")
}

pub fn enum_and_query_function_collision_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create type status as enum ('open', 'closed');
create table tickets (id serial primary key, status status not null);",
    queries: "
-- name: GetTickets :many
select status from tickets;

-- name: StatusToString :exec
delete from tickets;",
  )
  |> snap_error(title: "enum and query function clash")
}

pub fn query_function_collision_error_test() {
  error_fixture(
    Postgresql,
    schema: "create table users (id serial primary key);",
    queries: "
-- name: GetUser :exec
select id from users;

-- name: get_user :exec
select id from users;",
  )
  |> snap_error(title: "query function clash")
}

pub fn postgres_unnamed_parameter_error_test() {
  error_fixture(
    Postgresql,
    schema: "create table posts (id serial primary key, tags text[] not null);",
    queries: "
-- name: PostsWithTag :many
select id from posts where $1::text = any(tags);",
  )
  |> snap_error(title: "unnamed param")
}

pub fn embed_unsupported_error_test() {
  error_fixture(
    Postgresql,
    schema: "
create table authors (id serial primary key, name text not null);
create table books (id serial primary key, author_id int not null, title text not null);",
    queries: "
-- name: BooksWithAuthors :many
select sqlc.embed(books), sqlc.embed(authors)
from books join authors on authors.id = books.author_id;",
  )
  |> snap_error(title: "embed")
}

pub fn execrows_unsupported_error_test() {
  error_fixture(
    Postgresql,
    schema: "create table books (id serial primary key);",
    queries: "
-- name: DeleteBook :execrows
delete from books where id = $1;",
  )
  |> snap_error(title: "execrows")
}

pub fn execlastid_unsupported_error_test() {
  error_fixture(
    Mysql,
    schema: "create table books (id int not null auto_increment primary key, title text not null);",
    queries: "
-- name: CreateBook :execlastid
insert into books (title) values (?);",
  )
  |> snap_error(title: "execlastid")
}

// === HELPERS ==============================================================

fn error_fixture(
  engine: database.Engine,
  schema schema: String,
  queries queries: String,
) -> Fixture {
  Fixture(name: "", engine:, schema:, queries:)
}

/// Snapshots the module generated from `fixture`.
fn check(fixture: Fixture) -> Nil {
  let assert Ok(output) = pipeline.run(fixture)

  [
    section("schema.sql", fixture.schema),
    section("queries.sql", fixture.queries),
    section("sqlc", summary.render(output.sqlc)),
    section("unknown types", string.join(output.unknown_types, "\n")),
    section("sql.gleam", without_runtime(output.module)),
  ]
  |> string.join("\n\n")
  |> birdie.snap(title: string.replace(fixture.name, "_", " "))

  case list.contains(argv.load().arguments, "integration") {
    False -> Nil
    True -> {
      let assert Ok(url) = test_database.create(fixture)
      let assert Ok(schema) =
        database.fetch_schema(fixture.engine, url, in: ".")
      let assert Ok(fetched) =
        pipeline.run(
          Fixture(..fixture, name: fixture.name <> "_fetched", schema:),
        )
        as { "could not generate code from the fetched schema:\n" <> schema }
      assert fetched.module == output.module
    }
  }
}

fn snap_error(fixture: Fixture, title title: String) -> Nil {
  let fixture = Fixture(..fixture, name: slug(title))
  let assert Error(error) = pipeline.run(fixture)

  [
    section("schema.sql", fixture.schema),
    section("queries.sql", fixture.queries),
    section("error", error.to_string(error)),
  ]
  |> string.join("\n\n")
  |> birdie.snap(title:)
}

/// The runtime code is the same in every module.
fn without_runtime(module: String) -> String {
  string.replace(
    in: module,
    each: string.trim(runtime.code),
    with: "// <runtime code>",
  )
}

fn section(name: String, content: String) -> String {
  "-- "
  <> name
  <> " "
  <> string.repeat("-", 76 - string.length(name))
  <> "\n\n"
  <> string.trim(content)
}

fn slug(title: String) -> String {
  title
  |> string.lowercase
  |> string.replace(" ", "_")
  |> string.replace(",", "")
}
