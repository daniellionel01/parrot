import gleam/int.{clamp}

const red_color = "\u{001b}[31m"

const green_color = "\u{001b}[32m"

const yellow_color = "\u{001b}[33m"

const blue_color = "\u{001b}[34m"

const magenta_color = "\u{001b}[35m"

const cyan_color = "\u{001b}[36m"

const colorless = "\u{001b}[0m"

const rgb_color = "\u{001b}[38;2;"

pub fn green(text: String) {
  green_color <> text <> colorless
}

pub fn red(text: String) {
  red_color <> text <> colorless
}

pub fn yellow(text: String) {
  yellow_color <> text <> colorless
}

pub fn blue(text: String) {
  blue_color <> text <> colorless
}

pub fn magenta(text: String) {
  magenta_color <> text <> colorless
}

pub fn cyan(text: String) {
  cyan_color <> text <> colorless
}

pub fn rgb(text: String, r: Int, g: Int, b: Int) -> String {
  rgb_color
  <> int.to_string(clamp(r, 0, 255))
  <> ";"
  <> int.to_string(clamp(g, 0, 255))
  <> ";"
  <> int.to_string(clamp(b, 0, 255))
  <> "m"
  <> text
  <> colorless
}
