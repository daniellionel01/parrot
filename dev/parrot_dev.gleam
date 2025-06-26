//// Basically a scratch pad to test out different functions while developing them

import filepath
import gleam/io
import parrot/internal/errors
import parrot/internal/lib
import parrot/internal/project
import parrot/internal/sqlc
import simplifile

pub fn main() {
  // let assert Ok(tarball) =
  //   sqlc.download_zip(
  //     "https://downloads.sqlc.dev/sqlc_1.29.0_darwin_arm64.tar.gz",
  //   )
  // let assert Ok(binary) = sqlc.extract_sqlc_binary(tarball)
  // let assert Ok(_) = simplifile.write_bits("./sqlc", binary)

  let assert Error(e) = sqlc.verify_binary()
  io.println(lib.red("Error: " <> errors.err_to_string(e)))
}
