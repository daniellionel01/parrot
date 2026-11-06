//// Prints the checksum of every platform's sqlc release, for
//// `sqlc.platforms` after bumping `sqlc.sqlc_version`.

import gleam/io
import gleam/list
import parrot/internal/sqlc

pub fn main() {
  use #(platform, _) <- list.each(sqlc.platforms)
  let assert Ok(binary) = sqlc.download_and_extract(platform)
  io.println(platform <> ": " <> sqlc.sha256(binary))
}
