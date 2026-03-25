# Plans V3

- [ ] **toml based config**
       inspiration from lustre dev tools.

- [ ] **provide better decoder for dynamic columns**
       right now the dynamic parameter does not provide any information what column or table it belongs to. giving it access to that information would allow the user to (relatively) easily spin up custom decoders for complex data types where there is no one-way to do it and different database clients might have different ways of handling things (i.e. timestamps, geometric columns)

- [ ] **support more complex postgres columns**
  There are lots of data types in postgres that currently default to dynamic:
  set, hstore,  network address types (inet, cidr, macaddr, macaddr8), int4range, tsrange, geometric (point, polygon), interval, tsvector, tsquery

- [ ] **improved code generation**
       use `glance` for code generation, Only generate necessary `Param` types (f.e. a lot of incompatible params for sqlite)

- [ ] **clearer internal workings**
       Right now parrot is basically an orchestration between `GleamType`, `GleamParam` and `SQLC` column types.
       I think better documented and/or better named types would be helpful in maintaining and continuously developing this library. One should also study the squirrel codebase, since it is a lot maturer.

- [ ] **name conflicts between schemas**
       Something that has not come up in production yet, but is a possible edge case, is that you can define many different schemas in databases such as Postgres and MySQL so having same-named enums of tables will lead to naming conflicts in a resulting gleam file. We could prefix them with the table name since those are always unique.

- [ ] **dev dependency**
       allow parrot to be solely a dev dependency, by putting the `parrot/dev` module code inside of the generated `sql.gleam` module. (https://github.com/daniellionel01/parrot/issues/58)

- [ ] **generate wrappers**
       we can detect if the project has `pog` or `sqlight` as a dependency and prompt the user (also enable via cli flag) if they want us to generate the mapping function from `dev.Param` to `pog.Value` automatically.

- [x] **remove tui spinners**
        simply not necessary. codegen is quite fast so we do not need to show much progress indication. it also messes with the formatting quite a bit, which is irritating.

- [ ] **test failing paths, not just successfull runs**
       current integration tests are very limited!

- [ ] **v2 -> v3 migration guide**

- [ ] **sqlc embed**
