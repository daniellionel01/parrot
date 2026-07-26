import gleam/bit_array
import gleam/crypto
import gleam/io
import gleam/list
import gleam/string
import parrot/internal/sqlc

pub const binaries = [
  "_darwin_arm64.tar.gz",
  "_darwin_amd64.tar.gz",
  "_linux_arm64.tar.gz",
  "_linux_amd64.tar.gz",
  "_windows_arm64.tar.gz",
  "_windows_amd64.tar.gz",
]

pub fn main() {
  list.each(binaries, fn(path) {
    let download_path = sqlc.download_base <> path

    let assert Ok(tarball) = sqlc.download_zip(download_path)

    let assert Ok(bin) = sqlc.extract_sqlc_binary(tarball)

    let hash = crypto.hash(crypto.Sha256, bin)
    let hash_string =
      bit_array.base16_encode(hash)
      |> string.lowercase

    io.println(path <> ": " <> hash_string)
  })
}
