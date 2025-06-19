# 🦜 Parrot / type-safe SQL in gleam

[![Package Version](https://img.shields.io/hexpm/v/parrot)](https://hex.pm/packages/parrot)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/parrot/)
![erlang](https://img.shields.io/badge/target-erlang-a2003e)

## Features

*Most of the heavy lifting features are provided by / built into sqlc, so I do not aim to take credit for them.*

✅ Supports Sqlite, PostgreSQL and MySQL.<br />
✅ Named parameters.<sup>*1</sup> <br />
✅ Multiple queries per file.<br />
✅ Utility wrappers for popular gleam database libraries ([lpil/sqlight](https://github.com/lpil/sqlight), [lpil/pog](https://github.com/lpil/pog)).<br />
✅ Automatically pulls schema of your database.<br />
✅ Automatically downloads [sqlc](https://sqlc.dev/) binary.

<sup>*1</sup>: meaning that it infers the names of the parameters from your sql queries in the gleam function you
call. f.e. `WHERE username = $1` can yield `sql.get_user(username:)`. if you have multiple parameters of the same
data types this can avoid confusion and bugs.

## Usage / Getting Started

### Installation
```sh
$ gleam add parrot
```

### If you target JavaScript

So here is the catch: you can only execute parrot in an erlang gleam application.
However the generated code will also run in a javascript environment.
So if you need parrot for a javascript project, you can create a separate package and
copy over the generated module and that will work.

### Define your Queries
- Parrot will look for all *.sql files in any sql directory under your project's src directory.
- Each *.sql file can contain as many SQL queries as you want.
- All of the queries will compile into a single `src/[project name]/sql.gleam` module.

Here are some links to help you start out, if you are unfamiliar with the [sqlc](https://sqlc.dev/) annotation syntax:
- [Getting started with MySQL](https://docs.sqlc.dev/en/stable/tutorials/getting-started-mysql.html#schema-and-queries)
- [Getting started with PostgreSQL](https://docs.sqlc.dev/en/stable/tutorials/getting-started-postgresql.html#schema-and-queries)
- [Getting started with Sqlite](https://docs.sqlc.dev/en/stable/tutorials/getting-started-sqlite.html#schema-and-queries)

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

# see all options
$ gleam run -m parrot help
```

If you use MySQL, you also need [mysqldump](https://dev.mysql.com/doc/refman/9.0/en/mysqldump.html) (comes by default if you have a mysql client installed)

If you use PostgreSQL, you also need [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) (comes by default if you have a postgresql client installed)

### Run it!

You now have type safe access to your sql queries. You might have to write 1-2 wrapper functions for the database client library
of your choice.

If you are using [lpil/pog](https://github.com/lpil/pog) or [lpil/sqlight](https://github.com/lpil/sqlight), you are in luck!
You can find functions to copy & paste into your codebase here: [wrappers](./docs/wrappers.md)

An example with [lpil/sqlight](https://github.com/lpil/sqlight):
```gleam
import app/sql
import parrot/dev

fn parrot_to_sqlight(param: dev.Param) -> sqlight.Value {
  // ...
}

pub fn main() {
  // ...

  let #(sql, with, expecting) = sql.get_user_by_username("alice")
  let with = parrot_to_sqlight(with)
  let row = sqlight.query(sql, on:, with:, expecting:)

  // ...
}
```

## Examples

If you want to see how this library works in action, take a look at the integration tests:
- PostgreSQL: [./integration_test/psql](./integration_test/psql)
- MySQL: [./integration_test/mysql](./integration_test/mysql)
- Sqlite: [./integration_test/sqlite](./integration_test/sqlite)

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
would be MySQL, PostgreSQL and Sqlite.

You can read more on language & SQL support here:
https://docs.sqlc.dev/en/stable/reference/language-support.html

### What sqlc features are not supported?
- embeddeding structs (https://docs.sqlc.dev/en/stable/howto/embedding.html)

## Future Work

Here are some ideas and thoughts on how you might develop this library further:
* automatic pull request for new sqlc versions
* support more complex postgres data types (`path`, `point`, `polygon`)
* provide way to configure custom decoders for json columns
* use glance for codegen
* remove unused imports / types in generated sql.gleam module
* provide config for custom include / exclude patterns of *.sql query files
* improve codebase structure and adding opaque types
* handle more query annotations cmd syntaxes
  https://docs.sqlc.dev/en/stable/reference/query-annotations.html

Contributions are welcomed!

## Acknowledgements
- This project was heavily inspired by `squirrel` ([Hex](https://hex.pm/packages/squirrel), [GitHub](https://github.com/giacomocavalieri/squirrel)). Thank you [@giacomocavalieri](https://github.com/giacomocavalieri)!
- Thank you to `sqlc` ([GitHub](https://github.com/sqlc-dev/sqlc), [Website](https://sqlc.dev/))
