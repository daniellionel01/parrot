import gleam/list
import gleam/result
import pog

pub fn main() {
  let database_url = "postgresql://daniel:parrot@127.0.0.1:5432/parrot"
  use config <- result.try(pog.url_config(database_url))

  let sql = [
    "DROP TABLE IF EXISTS posts;", "DROP TABLE IF EXISTS authors;",
    "CREATE TABLE authors (
      id BIGSERIAL PRIMARY KEY,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      name text NOT NULL,
      bio text
    );",
    "CREATE TABLE posts (
      id BIGSERIAL PRIMARY KEY,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      author_id BIGINT NOT NULL,
      title VARCHAR(255) NOT NULL,
      body TEXT,
      FOREIGN KEY (author_id) REFERENCES authors (id)
    );",
  ]

  let db = pog.connect(config)

  list.each(sql, fn(sql) {
    pog.query(sql)
    |> pog.execute(db)
    |> echo
  })

  Ok(Nil)
}
