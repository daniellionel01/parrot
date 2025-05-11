import gleam/list
import shork

pub fn main() {
  let connection =
    shork.default_config()
    |> shork.user("root")
    |> shork.password("daniel")
    |> shork.database("parrot")
    |> shork.port(3309)
    |> shork.connect

  let sql = [
    "DROP TABLE posts;", "DROP TABLE authors;",
    "CREATE TABLE authors (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        name text NOT NULL,
        bio text
      );",
    "CREATE TABLE posts (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        author_id BIGINT NOT NULL,
        title VARCHAR(255) NOT NULL,
        body TEXT,

        FOREIGN KEY (author_id) REFERENCES authors (id)
      );",
  ]

  list.each(sql, fn(statement) {
    let assert Ok(_) =
      shork.query(statement)
      |> shork.execute(connection)
      |> echo
  })

  Ok(Nil)
}
