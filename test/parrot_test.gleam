import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn parrot_test() {
  1 |> should.equal(1)
}
