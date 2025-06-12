import sqlight

pub fn main() -> Result(Nil, String) {
  use conn <- sqlight.with_connection("file.db")

  let sql =
    "
  CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at DATETIME NOT NULL,
    name TEXT NOT NULL,
    bio TEXT
  );

  CREATE TABLE posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    author_id INTEGER NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    FOREIGN KEY (author_id) REFERENCES authors (id)
  );
  "
  let assert Ok(Nil) = sqlight.exec(sql, conn)

  Ok(Nil)
}
