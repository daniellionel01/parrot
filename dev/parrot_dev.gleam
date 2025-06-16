import gleam/dynamic
import simplifile

pub fn main() {
  let assert Ok(tarball) =
    download_zip("https://downloads.sqlc.dev/sqlc_1.29.0_darwin_arm64.tar.gz")
  let assert Ok(binary) = extract_sqlc_binary(tarball)
  let assert Ok(_) = simplifile.write_bits("./sqlc", binary)
}

@external(erlang, "parrot_ffi", "download_zip")
fn download_zip(url: String) -> Result(BitArray, dynamic.Dynamic)

@external(erlang, "parrot_ffi", "extract_sqlc_binary")
fn extract_sqlc_binary(tarball: BitArray) -> Result(BitArray, dynamic.Dynamic)
