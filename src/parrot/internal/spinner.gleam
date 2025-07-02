//// https://github.com/lpil/spinner/blob/main/src/spinner.gleam

import gleam/io
import glearray.{type Array}
import parrot/internal/lib
import repeatedly.{type Repeater}

fn magenta(text: String) {
  "\u{001b}[35m" <> text <> lib.colorless
}

fn green(text: String) {
  "\u{001b}[32m" <> text <> lib.colorless
}

const clear_line_code = "\u{001b}[2K"

const go_to_start_code = "\r"

pub const clock_frames = [
  "🕛", "🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚",
]

pub const half_circle_frames = ["◐", "◓", "◑", "◒"]

pub const moon_frames = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]

pub const negative_dots_frames = ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"]

pub const snake_frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

pub const triangle_frames = ["◢", "◣", "◤", "◥"]

pub const walking_frames = ["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"]

// ONLY CHANGE: Added current_text field to track the text
pub opaque type Spinner {
  Spinner(
    repeater: Repeater(State),
    frames: Array(String),
    current_text: String,
  )
}

type State {
  State(text: String, colour: fn(String) -> String)
}

pub opaque type Builder {
  Builder(frames: List(String), text: String, colour: fn(String) -> String)
}

/// Start a spinner that runs concurrently in another Erlang process or
/// JavaScript task.
///
pub fn new(text: String) -> Builder {
  Builder(snake_frames, text, magenta)
}

pub fn with_frames(builder: Builder, frames: List(String)) -> Builder {
  Builder(..builder, frames: frames)
}

pub fn with_colour(builder: Builder, colour: fn(String) -> String) -> Builder {
  Builder(..builder, colour: colour)
}

pub fn with_spinner(builder: Builder, context: fn(Spinner) -> a) {
  let spinner = start(builder)

  context(spinner)

  stop(spinner)
}

// ONLY CHANGE: Added current_text to constructor
pub fn start(builder: Builder) -> Spinner {
  let frames = glearray.from_list(builder.frames)
  let repeater =
    repeatedly.call(80, State(builder.text, builder.colour), fn(state, i) {
      print(frames, state, i)
      state
    })
  Spinner(repeater, frames, builder.text)
}

pub fn set_text(spinner: Spinner, text: String) -> Nil {
  repeatedly.update_state(spinner.repeater, fn(state) {
    State(..state, text: text)
  })
}

pub fn set_colour(spinner: Spinner, colour: fn(String) -> String) -> Nil {
  repeatedly.update_state(spinner.repeater, fn(state) {
    State(..state, colour: colour)
  })
}

/// Stop the spinner with a checkmark and move to the next line.
/// This shows completion and prepares for the next task.
///
pub fn complete_and_continue(spinner: Spinner, completed_text: String) -> Nil {
  // Stop the current spinner
  repeatedly.stop(spinner.repeater)

  // Show the completed task with a checkmark
  let checkmark = "✓"
  io.print(
    clear_line_code
    <> go_to_start_code
    <> green(checkmark)
    <> " "
    <> completed_text,
  )
  io.print("\n")
  // Move to next line
}

// NEW FUNCTION: Use current spinner text for completion (intermediate)
pub fn complete_and_continue_current(spinner: Spinner) -> Nil {
  complete_and_continue(spinner, spinner.current_text)
}

pub fn green_checkmark() {
  let checkmark = "✓"
  green(checkmark)
}

pub fn orange_warning() {
  let warning = "⚠️"
  magenta(warning)
}

/// Stop the spinner with a checkmark, showing the completed task.
/// This is useful when you want to show completion without starting a new spinner.
///
pub fn complete(spinner: Spinner, completed_text: String, prefix: String) -> Nil {
  repeatedly.stop(spinner.repeater)

  let show_cursor = "\u{001b}[?25h"
  io.print(
    clear_line_code
    <> go_to_start_code
    <> prefix
    <> " "
    <> completed_text
    <> show_cursor,
  )
  io.print("\n")
  // Move to next line
}

// NEW FUNCTION: Use current spinner text for completion (final)
pub fn complete_current(spinner: Spinner, prefix: String) -> Nil {
  complete(spinner, spinner.current_text, prefix)
  io.print("")
}

/// Stop the spinner with an error mark, showing the failed task.
/// This is useful when you want to show failure.
///
pub fn fail(spinner: Spinner, failed_text: String) -> Nil {
  repeatedly.stop(spinner.repeater)

  let error_mark = "✗"
  let red = fn(text: String) { "\u{001b}[31m" <> text <> lib.colorless }
  let show_cursor = "\u{001b}[?25h"
  io.print(
    clear_line_code
    <> go_to_start_code
    <> red(error_mark)
    <> " "
    <> failed_text
    <> show_cursor,
  )
  io.print("\n")
  // Move to next line
}

/// Stop the spinner, clearing the terminal line and showing the cursor. You
/// may want to print a success message after this.
///
/// This should be called before your program ends to re-enable the terminal
/// cursor.
///
pub fn stop(spinner: Spinner) -> Nil {
  repeatedly.stop(spinner.repeater)
  let show_cursor = "\u{001b}[?25h"
  io.print(clear_line_code <> go_to_start_code <> show_cursor)
}

fn print(frames: Array(String), state: State, index: Int) -> Nil {
  let hide_cursor = "\u{001b}[?25l"
  io.print(
    hide_cursor
    <> clear_line_code
    <> go_to_start_code
    <> state.colour(frame(frames, index))
    <> " "
    <> state.text,
  )
}

fn frame(frames: Array(String), index: Int) -> String {
  let assert Ok(frame) = glearray.get(frames, index % glearray.length(frames))
  frame
}
