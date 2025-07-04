# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2025-07-01

- Only issue a warning when download of sqlc binary was not successfull. This makes parrot
  work without an internet connection if sqlc is already downloaded or installed system wide.
- Use system wide sqlc binary as fallback, if local sqlc binary throws an error. This
  is an edge case on MacOS.

## [1.1.2] - 2025-06-26

- Bug Fix: `sqlc generate` fails due to incorrect path resolution on Linux

## [1.1.1] - 2025-06-26

- Output debugging information, when sqlc binary download fails

## [1.1.0] - 2025-06-25

- Support `List` columns in Postgres.<br />
  **Requires handling `dev.ParamList` in wrapper**
- Decodes `JSON`, `JSONB`, `MONEY`
  (not `Dynamic` anymore)
- Support for Postgres & MySQL `ENUM`
  (creates a custom type)
- Improved testing for all databases
  (more data types & operations)
- Use of `assert` syntax
  (instead of `gleeunit/should`)

## [1.0.1] - 2025-06-19

- Provide empty list instead of `Nil` when there are no parameters for a consistent return type

## [1.0.0] - 2025-06-19

- 🦜 Initial Release!
