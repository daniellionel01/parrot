# 🦜 Parrot / type-safe SQL in gleam

[![Package Version](https://img.shields.io/hexpm/v/parrot)](https://hex.pm/packages/parrot)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/parrot/)
![erlang](https://img.shields.io/badge/target-erlang-a2003e)

## Project Status

this project is currently in **alpha**. it will be released under v1.0.0 once ready for usage.

## Usage


```sh
$ gleam add parrot
```

```sh
# automatically detect database & default engine
$ gleam run -m parrot

# specify sqlite file
$ gleam run -m parrot --sqlite <file_path>
`````

For parrot to work you need to make sure you have [sqlc](https://sqlc.dev/) installed ([guide](https://docs.sqlc.dev/en/latest/overview/install.html)).
- If you use MySQL, you also need [mysqldump](https://dev.mysql.com/doc/refman/9.0/en/mysqldump.html) (comes per default if you have mysql installed)
- If you use PostgreSQL, you also need [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) (comes per default if you have postgresql installed)

1. Install
```sh
$ gleam add parrot
```

2. Define your queries

- Parrot will look for all *.sql files in any sql directory under your project's src directory.
- Each *.sql file can contain as many SQL queries as you want.
- All of the queries will compile into a single `src/[project name]/sql.gleam` module.

Here are some links to help you start out, if you are unfamiliar with the [sqlc](https://sqlc.dev/) annotation syntax:
- [Getting started with MySQL](https://docs.sqlc.dev/en/stable/tutorials/getting-started-mysql.html)
- [Getting started with PostgreSQL](https://docs.sqlc.dev/en/stable/tutorials/getting-started-postgresql.html)
- [Getting started with SQlite](https://docs.sqlc.dev/en/stable/tutorials/getting-started-sqlite.html)

2. Generate Gleam code
```sh
$ gleam run -m parrot --sqlite sqlite file.db
$ DATABASE_URL="mysql://user:password@127.0.0.1:3309/db" gleam run -m parrot
$ DATABASE_URL="mysql://user:password@127.0.0.1:3309/db" gleam run -m parrot
```

## How it works

This library makes use of a [sqlc-gen-json plugin](https://github.com/daniellionel01/sqlc-gen-json),
which it then converts into gleam code.

So in a simplified manner, the pipeline looks like this:
```mermaid
graph LR
    SQL[SQL Queries] -- sqlc-gen-json --> JSON[JSON Schema]
    JSON -- parrot --> Gleam[Gleam Code]
```

## An Example

Let's take the following SQL queries as an example:
```sql
-- name: GetAuthor :one
SELECT
  *
FROM
  authors
WHERE
  id = ?
LIMIT
  1;

-- name: ListAuthors :many
SELECT
  *
FROM
  authors
ORDER BY
  name;
```

The `--name: GetAuthor :one` comment is part of [sqlc](https://sqlc.dev/) and will be used to generate the
name and return type of the wrapper.

Given the queries above, the following code will be generated:

```gleam
//// file: src/gen/parrot.gleam

import gleam/option.{type Option}
import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}

// Custom decoders
fn datetime_decoder() -> decode.Decoder(Timestamp) {
  decode.string
  |> decode.then(fn(datetime_str) {
    case timestamp.parse_rfc3339(datetime_str) {
      Ok(ts) -> decode.success(ts)
      Error(_) -> decode.failure(timestamp.from_unix_seconds(0), "Invalid datetime format")
    }
  })
}

pub type GetAuthor {
  GetAuthor(
    id: Int,
    created_at: Timestamp,
    name: String,
    bio: Option(String)
  )
}

pub fn get_author(id: Int){
  let sql = "SELECT
  id, created_at, name, bio
FROM
  authors
WHERE
  id = ?
LIMIT
  1"
  #(sql, [sql.ParamInt(age)])
}

pub fn get_author_decoder() -> decode.Decoder(GetAuthor) {
  use id <- decode.field("id", decode.int)
  use created_at <- decode.field("created_at", datetime_decoder())
  use name <- decode.field("name", decode.string)
  use bio <- decode.field("bio", decode.optional(decode.string))
  decode.success(GetAuthor(id: , created_at: , name: , bio: ))
}

pub type ListAuthors {
  ListAuthors(
    id: Int,
    created_at: Timestamp,
    name: String,
    bio: Option(String)
  )
}

pub fn list_authors(){
  let sql = "SELECT
  id, created_at, name, bio
FROM
  authors
ORDER BY
  name"
  #(sql, Nil)
}

pub fn list_authors_decoder() -> decode.Decoder(ListAuthors) {
  use id <- decode.field("id", decode.int)
  use created_at <- decode.field("created_at", datetime_decoder())
  use name <- decode.field("name", decode.string)
  use bio <- decode.field("bio", decode.optional(decode.string))
  decode.success(ListAuthors(id: , created_at: , name: , bio: ))
}
```

Every SQL statement wrapper follows the schema of `#(String, List(Params))`. The first element is
the raw SQL that can be executed by your database driver and the second element is a
tuple of all of the parameters that you need for this query.

The query parameters are wrapped in a custom type that you can use to map them to your
database driver's types. Here is an example for [lpil/sqlight](https://github.com/lpil/sqlight):
```gleam
import gleam/list
import gleam/time/calendar
import gleam/time/timestamp
import lpil_sqlight/sql
import parrot/sql as parrot
import sqlight

/// Generated sql module by parrot
import parrot/sql

pub fn params_to_sqlight(args: List(parrot.Param)) -> List(sqlight.Value) {
  list.map(args, fn(arg) {
    case arg {
      parrot.ParamInt(a) -> sqlight.int(a)
      parrot.ParamBool(a) -> sqlight.bool(a)
      parrot.ParamFloat(a) -> sqlight.float(a)
      parrot.ParamString(a) -> sqlight.text(a)
      parrot.ParamTimestamp(ts) -> {
        ts
        |> timestamp.to_rfc3339(calendar.utc_offset)
        |> sqlight.text
      }
    }
  })
}

pub fn main() {
  // ... setup database ...

  let #(raw_sql, args) = sql.get_author(7)
  let _ =
    echo sqlight.query(
      raw_sql,
      on: conn,
      with: params_to_sqlight(args),
      expecting: sql.get_author_decoder(),
    )
}
```

## Development

### Database

There are scripts to spawn a MySQL or PostgreSQL docker container:
-  [MySQL Script](./bin/mysql.sh)
-  [PostgreSQL Script](./bin/psql.sh)

For example:
```sh
$ ./bin/mysql.sh
# or
$ ./bin/psql.sh
```

### Integration Test Suite
```sh
$ just test-sqlite
$ just test-mysql
$ just test-psql
```

## FAQ

### What flavour of SQL does parrot support?
This library supports everything that [sqlc](https://sqlc.dev/) supports. As the time of this writing that
would be MySQL, PostgreSQL and SQlite.

You can read more on language & SQL support here:
https://docs.sqlc.dev/en/stable/reference/language-support.html

### What sqlc features are not supported?
- embeddeding structs (https://docs.sqlc.dev/en/stable/howto/embedding.html)

## Acknowledgements
- This project was heavily inspired by `squirrel` ([Hex](https://hex.pm/packages/squirrel), [GitHub](https://github.com/giacomocavalieri/squirrel)). Thank you [@giacomocavalieri](https://github.com/giacomocavalieri)!
- Thank you to `sqlc` ([GitHub](https://github.com/sqlc-dev/sqlc), [Website](https://sqlc.dev/))
