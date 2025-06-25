# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2025-06-20

- Decodes `JSON`, `JSONB`, `MONEY` (not `Dynamic` anymore)
- Support for Postgres & MySQL `ENUM` (creates a custom type)
- Improved testing for all databases
- Use of `assert` syntax (instead of `gleeunit/should`)

## [1.0.1] - 2025-06-19

- Provide empty list instead of `Nil` when there are no parameters for a consistent return type

## [1.0.0] - 2025-06-19

- 🦜 Initial Release!
