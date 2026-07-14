# Notes

## Add Type Mappings to Readme

- Markdown Table can be generated with this tool: https://www.tablesgenerator.com/markdown_tables
- https://dev.mysql.com/doc/refman/8.4/en/data-types.html
- https://sqlite.org/datatype3.html
- https://www.postgresql.org/docs/current/datatype.html

- [ ] add section to readme and link document containing table
- [ ] add ToC to type mappings document

| Sqlite  | Encoded as | Decoded as |
| ------- | ---------- | ---------- |
| INTEGER | Int        | Int        |

## Add custom decoder & encoder for JSON columns

## Enable managed db

https://docs.sqlc.dev/en/latest/howto/managed-databases.html

## Test more platforms in CI

Inspiration: https://github.com/gleam-lang/gleam/blob/main/.github/workflows/ci.yaml

## Automatically Update sqlc Hashes & Changelog

When bumping the sqlc version it should also update the latest hashes and update the changelog

## Improve Container

- [x] use podman instead of docker
- [ ] use obscure ports so they dont get occupied by other dev projects

## Integrate Birdie Snapshot Tests

Right now we mostly test happy paths and not many edge cases. Birdie would definitely help to improve that:
https://github.com/giacomocavalieri/birdie/

## Create autocast ascii terminal demo

https://github.com/k9withabone/autocast

## Setup Wizard

Store configuration in gleam.toml and when we first run parrot they can do an interactive walkthrough such as choosing the database engine, sqlc binary, etc.
