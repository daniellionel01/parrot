const red_color = "\u{001b}[31m"

const green_color = "\u{001b}[32m"

const yellow_color = "\u{001b}[33m"

const colorless = "\u{001b}[0m"

pub fn green(text: String) {
  green_color <> text <> colorless
}

pub fn red(text: String) {
  red_color <> text <> colorless
}

pub fn yellow(text: String) {
  yellow_color <> text <> colorless
}
