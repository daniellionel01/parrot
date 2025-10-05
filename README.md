# 🦜 Parrot / type-safe SQL in gleam

[![Package Version](https://img.shields.io/hexpm/v/parrot)](https://hex.pm/packages/parrot)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/parrot/)
![erlang](https://img.shields.io/badge/target-erlang-a2003e)

> 🚨 **Exciting News**<br />
> Parrot got listed a community project on the sqlc website! 🦜🎉<br />
> Check it out here: https://docs.sqlc.dev/en/latest/reference/language-support.html<br />
> <br />
> Oh and we got featured on hackernews!<br />
> https://news.ycombinator.com/item?id=45478033

## Table of Contents
- [🦜 Parrot / type-safe SQL in gleam](#)
  * [Features](#features)
  * [Usage / Getting Started](#usage--getting-started)
  * [Examples](#examples)
  * [Development](#development)
  * [Quirks](#quirks)
  * [FAQ](#faq)
  * [Future Work](#future-work)
  * [Acknowledgements](#acknowledgements)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

## Features

**Most of the heavy lifting features are provided by / built into sqlc, I do not aim to take credit for them.**

☑️ Supports SQlite, PostgreSQL and MySQL.<br />
☑️ Multiple queries per file.<br />
☑️ Database client agnostic.<br />
☑️ Utility wrappers for popular gleam database libraries ([lpil/sqlight](https://github.com/lpil/sqlight), [lpil/pog](https://github.com/lpil/pog)).<br />
☑️ Automatically pulls the schema of your database.<br />
☑️ Automatically downloads [sqlc](https://sqlc.dev/) binary.<br />
☑️ Named parameters.<sup>*1</sup> <br />

<sup>*1</sup>: Meaning that it infers the names of the parameters from your sql queries in the gleam function you call. for example for a query called `FindUser`, defined as `SELECT * FROM user WHERE username = $1`, parrot will produce a function where the arguments match those column names: `pub fn find_user(username: String) { ... }`. If you have multiple parameters of the same data types this can avoid confusion and bugs.

## Usage / Getting Started

### Installation
```sh
$ gleam add parrot
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

# see all options
$ gleam run -m parrot help
```

If you use SQLite, you also need to have installed [sqlite3](https://sqlite.org/index.html).

If you use MySQL, you also need to have installed [mysqldump](https://dev.mysql.com/doc/refman/9.0/en/mysqldump.html) (comes by default if you have a mysql client installed).

If you use PostgreSQL, you also need to have installed [pg_dump](https://www.postgresql.org/docs/current/app-pgdump.html) (comes by default if you have a postgresql client installed).

### Run it!

You now have type safe access to your sql queries.

You might want to write wrapper functions for the database client library of your choice. If you are using [lpil/pog](https://github.com/lpil/pog) or [lpil/sqlight](https://github.com/lpil/sqlight), you are in luck!
You can find functions to copy & paste into your codebase here: [wrappers](https://github.com/daniellionel01/parrot/blob/main/docs/wrappers.md)

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
- PostgreSQL: [integration/psql](https://github.com/daniellionel01/parrot/blob/main/integration/psql)
- MySQL: [integration/mysql](https://github.com/daniellionel01/parrot/blob/main/integration/mysql)
- SQlite: [integration/sqlite](https://github.com/daniellionel01/parrot/blob/main/integration/sqlite)

## Development

[just](https://github.com/casey/just) is used to run project commands.

### Database

There are scripts to spawn a MySQL or PostgreSQL docker container:
-  [MySQL Script](https://github.com/daniellionel01/parrot/blob/main/bin/mysql.sh)
-  [PostgreSQL Script](https://github.com/daniellionel01/parrot/blob/main/bin/psql.sh)

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

## Quirks

As with everything in software, there are some quirks with this library, due to
the nature of your database of choice and sqlc.

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

- Certain query annotations are not supported and will panic the process: `:execrows`, `:execlastid`, `:batchexec`, `:batchone`, `:batchmany`, `:copyfrom`. You can read more about it here: https://docs.sqlc.dev/en/stable/reference/query-annotations.html

## Future Work

Ideas and actionable tasks are collected and organised here: https://github.com/daniellionel01/parrot/issues

Contributions are welcomed!

## Acknowledgements
- This project was heavily inspired by `squirrel` ([Hex](https://hex.pm/packages/squirrel), [GitHub](https://github.com/giacomocavalieri/squirrel)). Thank you [@giacomocavalieri](https://github.com/giacomocavalieri)!
- Thank you to `sqlc` ([GitHub](https://github.com/sqlc-dev/sqlc), [Website](https://sqlc.dev/))
