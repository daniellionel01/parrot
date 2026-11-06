# 🦜 Parrot / type-safe SQL in [Gleam](https://gleam.run/)

[![Package Version](https://img.shields.io/hexpm/v/parrot)](https://hex.pm/packages/parrot)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://parrot.hexdocs.pm/)
![erlang](https://img.shields.io/badge/target-erlang-a2003e)

> 🚨 **Exciting News**<br />
> Parrot got listed a community project on the sqlc website! 🦜🎉<br />
> Check it out here: https://docs.sqlc.dev/en/latest/reference/language-support.html

## Table of Contents

- [🦜 Parrot / type-safe SQL in gleam](#)
  - [Features](#features)
  - [Code Showcase](#code-showcase)
  - [Usage / Getting Started](#usage--getting-started)
  - [Development](#development)
  - [Quirks](#quirks)
  - [FAQ](#faq)
  - [Future Work](#future-work)
  - [Acknowledgements](#acknowledgements)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

## Features

**Most of the heavy lifting features are provided by / built into sqlc, I do not aim to take credit for them.**

☑️ Supports SQlite, PostgreSQL and MySQL.<br />
☑️ Multiple queries per file.<br />
☑️ Database client agnostic.<br />
☑️ Utility wrappers for popular gleam database libraries ([lpil/sqlight](https://github.com/lpil/sqlight), [lpil/pog](https://github.com/lpil/pog), [ninanomenon/shork](https://github.com/ninanomenon/shork)).<br />
☑️ Automatically pulls the schema of your database.<br />
☑️ Automatically downloads [sqlc](https://sqlc.dev/) binary.<br />
☑️ Named parameters.<sup>*1</sup> <br />

<sup>*1</sup>: Meaning that it infers the names of the parameters from your sql queries in the gleam function you call. for example for a query called `FindUser`, defined as `SELECT * FROM user WHERE username = $1`, parrot will produce a function where the arguments match those column names: `pub fn find_user(username: String) { ... }`. If you have multiple parameters of the same data types this can avoid confusion and bugs.

<details>

<summary>

## Code Showcase

</summary>

Given this SQL:

```sql
-- name: CreateUserWithRole :exec
insert into
  users (username, role)
values
  ($1, $2)
returning id;

-- name: GetUserByUsername :one
select
  id,
  username,
  created_at,
  date_of_birth,
  profile,
  extra_info,
  favorite_numbers,
  role,
  document
from
  users
where
  username = $1
limit
  1;
```

Parrot will generate gleam code with matching types, decoders and argument names for you:

```gleam
pub type CreateUserWithRole {
  CreateUserWithRole(id: Int)
}

pub fn create_user_with_role(
  username username: String,
  role role: Option(UserRole),
) {
  let sql =
    "insert into
  users (username, role)
values
  ($1, $2)
returning id"
  #(sql, [
    ParamString(username),
    ParamNullable(
      option.map(role, fn(v) { ParamString(user_role_to_string(v)) }),
    ),
  ])
}

pub fn create_user_with_role_decoder() -> decode.Decoder(CreateUserWithRole) {
  use id <- decode.field(0, decode.int)
  decode.success(CreateUserWithRole(id:))
}

pub type GetUserByUsername {
  GetUserByUsername(
    id: Int,
    username: String,
    created_at: Option(Timestamp),
    date_of_birth: Option(Date),
    profile: Option(String),
    extra_info: Option(String),
    favorite_numbers: Option(List(Int)),
    role: Option(UserRole),
    document: Option(BitArray),
  )
}

pub fn get_user_by_username(username username: String) {
  let sql =
    "select
  id,
  username,
  created_at,
  date_of_birth,
  profile,
  extra_info,
  favorite_numbers,
  role,
  document
from
  users
where
  username = $1
limit
  1"
  #(sql, [ParamString(username)], get_user_by_username_decoder())
}

pub fn get_user_by_username_decoder() -> decode.Decoder(GetUserByUsername) {
  use id <- decode.field(0, decode.int)
  use username <- decode.field(1, decode.string)
  use created_at <- decode.field(2, decode.optional(datetime_decoder()))
  use date_of_birth <- decode.field(
    3,
    decode.optional(calendar_date_decoder()),
  )
  use profile <- decode.field(4, decode.optional(decode.string))
  use extra_info <- decode.field(5, decode.optional(decode.string))
  use favorite_numbers <- decode.field(
    6,
    decode.optional(decode.list(of: decode.int)),
  )
  use role <- decode.field(7, decode.optional(user_role_decoder()))
  use document <- decode.field(8, decode.optional(decode.bit_array))
  decode.success(GetUserByUsername(
    id:,
    username:,
    created_at:,
    date_of_birth:,
    profile:,
    extra_info:,
    favorite_numbers:,
    role:,
    document:,
  ))
}
```

More examples: [snapshot tests](./test/birdie_snapshots)

</details>

## Usage / Getting Started

### Installation

```sh
$ gleam add --dev parrot
```

### Define your Queries

- Parrot will look for all *.sql files in any sql directory under your project's src directory.
- Each *.sql file can contain as many SQL queries as you want.
- All of the queries will compile into a single `src/[project name]/sql.gleam` module.

Here are some links to help you start out, if you are unfamiliar with the [sqlc](https://sqlc.dev/) annotation syntax:

- [Getting started with MySQL](https://docs.sqlc.dev/en/stable/tutorials/getting-started-mysql.html#schema-and-queries)
- [Getting started with PostgreSQL](https://docs.sqlc.dev/en/stable/tutorials/getting-started-postgresql.html#schema-and-queries)
- [Getting started with SQlite](https://docs.sqlc.dev/en/stable/tutorials/getting-started-sqlite.html#schema-and-queries)

Here is an example of the file structure:

```sh
├── gleam.toml
├── README.md
├── src
│   ├── app.gleam
│   └── sql
│       ├── auth.sql
│       └── posts.sql
└── test
   └── app_test.gleam
```

### Code Generation

```sh
# automatically detects database & engine from env (DATABASE_URL by default)
$ gleam run -m parrot

# provide connection string from different environment variable
$ gleam run -m parrot -- -e PG_DATABASE_URL

# specify sqlite file
$ gleam run -m parrot -- --sqlite <file_path>

# schema or migration files instead of a database
$ gleam run -m parrot -- --schema priv/migrations --engine postgresql

# see all options
$ gleam run -m parrot help
```

All options can also be set in `gleam.toml`: [TOML reference](./pages/toml-reference.md)

If you use SQLite, you also need to have installed [sqlite3](https://sqlite.org/index.html).

If you use MySQL, you also need to have installed [mysqldump](https://dev.mysql.com/doc/refman/9.0/en/mysqldump.html) (comes by default if you have a mysql client installed).

If you use PostgreSQL, you also need to have installed [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) (comes by default if you have a postgresql client installed).

### Run it!

You now have type safe access to your sql queries.

Wrappers for [pog](https://github.com/lpil/pog), [sqlight](https://github.com/lpil/sqlight) and [shork](https://github.com/ninanomenon/shork): [wrappers](https://github.com/daniellionel01/parrot/blob/main/pages/wrappers.md)

An example with [lpil/sqlight](https://github.com/lpil/sqlight):

```gleam
import app/sql

fn to_sqlight(param: sql.Param) -> sqlight.Value {
  // ...
}

pub fn main() {
  // ...

  let #(sql, with, expecting) = sql.get_user_by_username("alice")
  let with = list.map(with, to_sqlight)
  let row = sqlight.query(sql, on:, with:, expecting:)

  // ...
}
```

## Examples

Schema, queries and generated code:

- PostgreSQL: [postgres_app_fixture](https://github.com/daniellionel01/parrot/blob/main/test/birdie_snapshots/postgres_app_fixture.accepted)
- MySQL: [mysql_app_fixture](https://github.com/daniellionel01/parrot/blob/main/test/birdie_snapshots/mysql_app_fixture.accepted)
- SQlite: [sqlite_app_fixture](https://github.com/daniellionel01/parrot/blob/main/test/birdie_snapshots/sqlite_app_fixture.accepted)

Database driver wrappers: [wrappers.md](https://github.com/daniellionel01/parrot/blob/main/pages/wrappers.md)

## Quirks

As with everything in software, there are some quirks with this library, due to
the nature of your database of choice and sqlc.

### Functions

Wether it be custom or built-in functions in postgres, sqlc struggles to infer types
for those types of queries. Luckily sqlc provides a way to annotate columns directly.
Parrot will soon provide support for direct database connections. Until then,
you will have to annotate the type of those columns.

Overview over all types can be found here:

- Postgres: https://github.com/sqlc-dev/sqlc/blob/main/internal/codegen/golang/postgresql_type.go
- MySQL: https://github.com/sqlc-dev/sqlc/blob/main/internal/codegen/golang/mysql_type.go
- SQlite: https://github.com/sqlc-dev/sqlc/blob/main/internal/codegen/golang/sqlite_type.go

You can annotate column types like so:

```sql
-- name: GetTournamentChampionBets :many
SELECT id::uuid,
       created_by::uuid,
       updated_by::uuid,
       updated_at::timestamp,
       tournament_name::text,
       team_name::text
FROM get_tournament_champion_bets_safe();
```

### Multidimensional Arrays

If you have an `INTEGER[][]` column in Postgres, `pg_dump` does not correctly identify
the column as a two-dimensional array and therefore only gives you a `List(Int)` instead
of a `List(List(Int))`. If this is a problem for you, you can raise an issue and
we might come up with a solution or workaround.

### Dynamic Data Types

There are a couple of complex data types that are explictly made `dynamic`
since they are too complex to handle with the current implementation.
There is a plan for a better and more flexible implementation. Until then,
it will be wrapped in a dynamic type.

Postgres: `timetz`, `macaddr8`, ranges, geometric types, `hstore`, `tsvector`, `tsquery`, …

Workaround: cast them in the query, f.e. `select value::text`.

### Targetting JavaScript

So here is the catch: you can only execute parrot in an erlang gleam application.
However the generated code will also run in a javascript environment.
So if you need parrot for a javascript project, you can create a separate package and
copy over the generated module and that will work.

## FAQ

### What flavour of SQL does parrot support?

This library supports everything that [sqlc](https://sqlc.dev/) supports. As the time of this writing that
would be MySQL, PostgreSQL and SQlite.

You can read more on language & SQL support here:
https://docs.sqlc.dev/en/stable/reference/language-support.html

### What sqlc features are not supported?

- embeddeding structs (https://docs.sqlc.dev/en/stable/howto/embedding.html)

- Certain query annotations are not supported and will panic the process: `:execrows`, `:execlastid`, `:batchexec`, `:batchone`, `:batchmany`, `:copyfrom`.
  You can read more about those operations here: https://docs.sqlc.dev/en/stable/reference/query-annotations.html.
  Most of those operations are only supported when outputting Go code and are simply not necessary in Gleam.

## Future Work

Ideas and actionable tasks are collected and organised here: https://github.com/daniellionel01/parrot/issues

Contributions are welcomed!

## Development

[mise](https://mise.jdx.dev) is used to run project commands.

### Tests

```sh
$ gleam test
$ gleam run -m birdie # review snapshots
```

Integration tests (requires `sqlite3`, `psql`, `pg_dump`, `mysql`, `mysqldump`):

```sh
$ mise run db-up
$ mise run test-integration
$ mise run db-down
```

## Acknowledgements

- This project was heavily inspired by `squirrel` ([Hex](https://hex.pm/packages/squirrel), [GitHub](https://github.com/giacomocavalieri/squirrel)). Thank you [@giacomocavalieri](https://github.com/giacomocavalieri)!
- Thank you to `sqlc` ([GitHub](https://github.com/sqlc-dev/sqlc), [Website](https://sqlc.dev/))
