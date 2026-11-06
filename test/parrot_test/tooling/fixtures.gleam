import parrot/internal/database.{MySQL, PostgreSQL, SQLite}
import parrot_test/tooling/pipeline.{type Fixture, Fixture}

pub fn sqlite_basic() -> Fixture {
  Fixture(
    name: "sqlite_basic",
    engine: SQLite,
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
}

pub fn sqlite_column_types() -> Fixture {
  Fixture(
    name: "sqlite_column_types",
    engine: SQLite,
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
}

pub fn sqlite_named_and_slice_params() -> Fixture {
  Fixture(
    name: "sqlite_named_and_slice_params",
    engine: SQLite,
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
}

pub fn postgres_enums() -> Fixture {
  Fixture(
    name: "postgres_enums",
    engine: PostgreSQL,
    schema: "
create type user_role as enum ('admin', 'regular_user', 'guest');

create table users (
  id serial primary key,
  username text not null,
  role user_role not null,
  previous_role user_role,
  past_roles user_role[] not null
);",
    queries: "
-- name: GetPastRoles :one
select past_roles from users where id = $1;

-- name: SetPastRoles :exec
update users set past_roles = $1 where id = $2;

-- name: GetUserRoles :many
select role, previous_role from users;

-- name: SetRole :exec
update users set role = $1 where id = $2;

-- name: UsersWithRole :many
select id, username from users where role = $1;",
  )
}

pub fn postgres_arrays() -> Fixture {
  Fixture(
    name: "postgres_arrays",
    engine: PostgreSQL,
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
}

pub fn postgres_column_types() -> Fixture {
  Fixture(
    name: "postgres_column_types",
    engine: PostgreSQL,
    schema: "
create table events (
  id bigserial primary key,
  happened_at timestamp not null,
  happened_at_tz timestamptz,
  day date not null,
  starts time,
  starts_tz timetz,
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
}

pub fn postgres_joins_and_commands() -> Fixture {
  Fixture(
    name: "postgres_joins_and_commands",
    engine: PostgreSQL,
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
}

pub fn mysql_column_types() -> Fixture {
  Fixture(
    name: "mysql_column_types",
    engine: MySQL,
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
}

pub fn sqlite_app() -> Fixture {
  pipeline.from_files("sqlite_app", SQLite)
}

pub fn sqlite_no_optional() -> Fixture {
  pipeline.from_files("sqlite_no_optional", SQLite)
}

pub fn postgres_app() -> Fixture {
  pipeline.from_files("postgres_app", PostgreSQL)
}

pub fn mysql_app() -> Fixture {
  pipeline.from_files("mysql_app", MySQL)
}

pub fn sqlite_keywords() -> Fixture {
  Fixture(
    name: "sqlite_keywords",
    engine: SQLite,
    schema: "
create table things (
  id integer primary key autoincrement,
  type text not null
);",
    queries: "
-- name: Type :many
select type from things where type = sqlc.arg(type);",
  )
}
