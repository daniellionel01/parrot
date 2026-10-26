//// Snapshot tests for code generation. No database connection is needed:
//// sqlc parses the schema on its own (see `parrot_test/pipeline`).
////
//// Every codegen snapshot contains the input schema and queries, a summary
//// of what sqlc made of them and the generated gleam module. Every generated
//// module is also compiled (see `parrot_test/compile_check`).
////
//// Review new or changed snapshots with `gleam run -m birdie`.
////

import birdie
import gleam/string
import parrot/error
import parrot/internal/codegen
import parrot/internal/sqlc
import parrot_test/compile_check
import parrot_test/pipeline.{type Fixture, Fixture}
import parrot_test/summary

// === SQLITE ===============================================================

pub fn sqlite_basic_test() {
  fixture(
    sqlc.SQLite,
    schema: "
create table users (
  id integer primary key autoincrement,
  username text not null unique
);",
    queries: "
-- name: CountUsers :one
select count(*) from users;

-- name: CreateUser :exec
insert into users (username) values (?);

-- name: ListUsers :many
select * from users;",
  )
  |> snap_codegen(title: "sqlite basic queries")
}

pub fn sqlite_column_types_test() {
  fixture(
    sqlc.SQLite,
    schema: "
create table things (
  id integer primary key autoincrement,
  name text not null,
  nickname text,
  score real not null,
  data blob,
  active boolean not null,
  born date,
  created_at datetime not null,
  price numeric
);",
    queries: "
-- name: GetThing :one
select * from things where id = ?;

-- name: InsertThing :exec
insert into things (name, nickname, score, data, active, born, created_at, price)
values (?, ?, ?, ?, ?, ?, ?, ?);",
  )
  |> snap_codegen(title: "sqlite column types and nullability")
}

pub fn sqlite_named_and_slice_params_test() {
  fixture(
    sqlc.SQLite,
    schema: "
create table things (
  id integer primary key autoincrement,
  name text not null
);",
    queries: "
-- name: ThingsByIds :many
select id, name from things where id in (sqlc.slice('ids'));

-- name: RenameThing :exec
update things set name = sqlc.arg(new_name) where id = sqlc.arg(id);

-- name: ThingsByName :many
select id from things where name = @name;",
  )
  |> snap_codegen(title: "sqlite named and slice parameters")
}

pub fn sqlite_app_fixture_test() {
  pipeline.from_files("sqlite_app", sqlc.SQLite)
  |> snap_codegen(title: "sqlite app fixture")
}

pub fn sqlite_no_optional_fixture_test() {
  pipeline.from_files("sqlite_no_optional", sqlc.SQLite)
  |> snap_codegen(title: "sqlite fixture without optional columns")
}

// === POSTGRESQL ===========================================================

pub fn postgres_enums_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "
create type user_role as enum ('admin', 'regular_user', 'guest');

create table users (
  id serial primary key,
  username text not null,
  role user_role not null,
  previous_role user_role
);",
    queries: "
-- name: GetUserRoles :many
select role, previous_role from users;

-- name: SetRole :exec
update users set role = $1 where id = $2;

-- name: UsersWithRole :many
select id, username from users where role = $1;",
  )
  |> snap_codegen(title: "postgres enums as columns and parameters")
}

pub fn postgres_arrays_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "
create table posts (
  id serial primary key,
  tags text[] not null,
  scores int[],
  matrix int[][]
);",
    queries: "
-- name: GetPost :one
select * from posts where id = $1;

-- name: PostsWithTag :many
select id from posts where sqlc.arg(tag)::text = any(tags);

-- name: InsertPost :exec
insert into posts (tags, scores) values ($1, $2);",
  )
  |> snap_codegen(title: "postgres array columns and parameters")
}

pub fn postgres_column_types_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "
create table events (
  id bigserial primary key,
  happened_at timestamp not null,
  happened_at_tz timestamptz,
  day date not null,
  starts time,
  duration interval,
  payload jsonb not null,
  external_id uuid not null,
  ip inet,
  amount numeric(10, 2),
  ratio double precision not null,
  is_public boolean not null,
  raw bytea
);",
    queries: "
-- name: GetEvent :one
select * from events where id = $1;

-- name: InsertEvent :exec
insert into events (happened_at, day, payload, external_id, ratio, is_public)
values ($1, $2, $3, $4, $5, $6);",
  )
  |> snap_codegen(title: "postgres column types including unsupported ones")
}

pub fn postgres_joins_and_commands_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "
create table authors (
  id serial primary key,
  name text not null
);

create table books (
  id serial primary key,
  author_id int references authors (id),
  title text not null
);",
    queries: "
-- name: BooksWithAuthors :many
select books.title, authors.name
from books left join authors on authors.id = books.author_id;

-- name: CountBooks :one
select count(*) from books;

-- name: CreateBook :one
insert into books (title, author_id)
values ($1, sqlc.narg(author_id))
returning id;

-- name: DeleteBook :exec
delete from books where id = $1;

-- name: DeleteBooksByAuthor :execresult
delete from books where author_id = $1;",
  )
  |> snap_codegen(title: "postgres left joins narg and query commands")
}

pub fn postgres_app_fixture_test() {
  pipeline.from_files("postgres_app", sqlc.PostgreSQL)
  |> snap_codegen(title: "postgres app fixture")
}

// === MYSQL ================================================================

pub fn mysql_column_types_test() {
  fixture(
    sqlc.MySQL,
    schema: "
create table accounts (
  id int unsigned not null auto_increment primary key,
  email varchar(255) not null,
  status enum('active', 'suspended') not null,
  is_verified tinyint(1) not null,
  balance decimal(10, 2),
  created_at datetime not null,
  last_login timestamp null,
  birthday date
);",
    queries: "
-- name: GetAccount :one
select * from accounts where id = ?;

-- name: CreateAccount :exec
insert into accounts (email, status, is_verified, created_at)
values (?, ?, ?, ?);

-- name: AccountsByIds :many
select id, email from accounts where id in (sqlc.slice('ids'));",
  )
  |> snap_codegen(title: "mysql column types enums and slices")
}

pub fn mysql_app_fixture_test() {
  pipeline.from_files("mysql_app", sqlc.MySQL)
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
  |> snap_error(title: "sqlite rejects postgres style parameters")
}

pub fn postgres_unknown_table_error_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "create table users (id serial primary key);",
    queries: "
-- name: GetPost :one
select * from posts where id = $1;",
  )
  |> snap_error(title: "postgres query on a table that does not exist")
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
  |> snap_error(title: "enum and query with the same name")
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
  |> snap_error(title: "enum without any values")
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
  |> snap_error(title: "two enums sharing a value")
}

pub fn postgres_unnamed_parameter_error_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "create table posts (id serial primary key, tags text[] not null);",
    queries: "
-- name: PostsWithTag :many
select id from posts where $1::text = any(tags);",
  )
  |> snap_error(title: "postgres parameter without a name")
}

pub fn execrows_unsupported_error_test() {
  fixture(
    sqlc.PostgreSQL,
    schema: "create table books (id serial primary key);",
    queries: "
-- name: DeleteBook :execrows
delete from books where id = $1;",
  )
  |> snap_error(title: "unsupported execrows annotation")
}

pub fn execlastid_unsupported_error_test() {
  fixture(
    sqlc.MySQL,
    schema: "create table books (id int not null auto_increment primary key, title text not null);",
    queries: "
-- name: CreateBook :execlastid
insert into books (title) values (?);",
  )
  |> snap_error(title: "unsupported execlastid annotation")
}

// === SEED CODE ============================================================

pub fn seed_code_test() {
  codegen.output_gleam_module_seed_code
  |> string.trim
  |> birdie.snap(title: "seed code")
}

// === HELPERS ==============================================================

/// The fixture's name is filled in from the snapshot title by the
/// `snap_*` functions.
///
fn fixture(
  engine: sqlc.Engine,
  schema schema: String,
  queries queries: String,
) -> Fixture {
  Fixture(name: "", engine:, schema:, queries:)
}

fn snap_codegen(fixture: Fixture, title title: String) -> Nil {
  let fixture = Fixture(..fixture, name: slug(title))
  let assert Ok(output) = pipeline.run(fixture)

  case compile_check.check(output.module) {
    Ok(Nil) -> Nil
    Error(output) ->
      panic as { "generated module does not compile:\n" <> output }
  }

  [
    section("schema.sql", fixture.schema),
    section("queries.sql", fixture.queries),
    section("sqlc", summary.render(output.context)),
    section("sql.gleam", output.module_without_seed),
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
