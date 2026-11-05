//// Review snapshots with `gleam run -m birdie`.

import birdie
import gleam/string
import parrot/error
import parrot/internal/codegen
import parrot/internal/sqlc
import parrot_test/compile_check
import parrot_test/fixtures
import parrot_test/pipeline.{type Fixture, Fixture}
import parrot_test/summary

// === SQLITE ===============================================================

pub fn sqlite_basic_test() {
  fixtures.sqlite_basic()
  |> snap_codegen(title: "sqlite basic queries")
}

pub fn sqlite_column_types_test() {
  fixtures.sqlite_column_types()
  |> snap_codegen(title: "sqlite column types")
}

pub fn sqlite_named_and_slice_params_test() {
  fixtures.sqlite_named_and_slice_params()
  |> snap_codegen(title: "sqlite named and slice params")
}

pub fn sqlite_app_fixture_test() {
  fixtures.sqlite_app_fixture()
  |> snap_codegen(title: "sqlite app fixture")
}

pub fn sqlite_no_optional_fixture_test() {
  fixtures.sqlite_no_optional_fixture()
  |> snap_codegen(title: "sqlite no optional fixture")
}

// === POSTGRESQL ===========================================================

pub fn postgres_enums_test() {
  fixtures.postgres_enums()
  |> snap_codegen(title: "postgres enums")
}

pub fn postgres_arrays_test() {
  fixtures.postgres_arrays()
  |> snap_codegen(title: "postgres arrays")
}

pub fn postgres_column_types_test() {
  fixtures.postgres_column_types()
  |> snap_codegen(title: "postgres column types")
}

pub fn postgres_joins_and_commands_test() {
  fixtures.postgres_joins_and_commands()
  |> snap_codegen(title: "postgres joins")
}

pub fn postgres_app_fixture_test() {
  fixtures.postgres_app_fixture()
  |> snap_codegen(title: "postgres app fixture")
}

// === MYSQL ================================================================

pub fn mysql_column_types_test() {
  fixtures.mysql_column_types()
  |> snap_codegen(title: "mysql column types")
}

pub fn mysql_app_fixture_test() {
  fixtures.mysql_app_fixture()
  |> snap_codegen(title: "mysql app fixture")
}

// === ERRORS ===============================================================

pub fn sqlite_postgres_style_parameter_error_test() {
  fixture(
    sqlc.SQLite,
    schema: "create table users (id integer primary key);",
    queries: "
-- name: GetUser :one
select * from users where id = $1;",
  )
  |> snap_error(title: "sqlite postgres style param")
}

pub fn postgres_unknown_table_error_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "create table users (id serial primary key);",
    queries: "
-- name: GetPost :one
select * from posts where id = $1;",
  )
  |> snap_error(title: "unknown table")
}

pub fn enum_and_query_name_collision_error_test() {
  fixture(
    sqlc.PostgreSQL,
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
  fixture(
    sqlc.PostgreSQL,
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
  fixture(
    sqlc.PostgreSQL,
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
  fixture(
    sqlc.PostgreSQL,
    schema: "
create type ticket_status as enum ('open', 'OPEN', 'closed');
create table tickets (id serial primary key, status ticket_status not null);",
    queries: "
-- name: TicketStatuses :many
select status from tickets;",
  )
  |> snap_error(title: "enum values clash in pascal case")
}

pub fn postgres_unnamed_parameter_error_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "create table posts (id serial primary key, tags text[] not null);",
    queries: "
-- name: PostsWithTag :many
select id from posts where $1::text = any(tags);",
  )
  |> snap_error(title: "unnamed param")
}

pub fn execrows_unsupported_error_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "create table books (id serial primary key);",
    queries: "
-- name: DeleteBook :execrows
delete from books where id = $1;",
  )
  |> snap_error(title: "execrows")
}

pub fn execlastid_unsupported_error_test() {
  fixture(
    sqlc.MySQL,
    schema: "create table books (id int not null auto_increment primary key, title text not null);",
    queries: "
-- name: CreateBook :execlastid
insert into books (title) values (?);",
  )
  |> snap_error(title: "execlastid")
}

// === SEED CODE ============================================================

pub fn seed_code_test() {
  codegen.output_gleam_module_seed_code
  |> string.trim
  |> birdie.snap(title: "seed code")
}

// === HELPERS ==============================================================

fn fixture(
  engine: sqlc.Engine,
  schema schema: String,
  queries queries: String,
) -> Fixture {
  Fixture(name: "", engine:, schema:, queries:)
}

fn snap_codegen(fixture: Fixture, title title: String) -> Nil {
  let assert Ok(output) = pipeline.run(fixture)

  let assert Ok(Nil) = compile_check.check(output.module)

  [
    section("schema.sql", fixture.schema),
    section("queries.sql", fixture.queries),
    section("sqlc", summary.render(output.context)),
    section("sql.gleam", without_seed(output.module)),
  ]
  |> string.join("\n\n")
  |> birdie.snap(title:)
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

/// The seed code is the same in every module and has its own snapshot.
fn without_seed(module: String) -> String {
  string.replace(
    in: module,
    each: string.trim(codegen.output_gleam_module_seed_code),
    with: "// <seed code, see the `seed code` snapshot>",
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
