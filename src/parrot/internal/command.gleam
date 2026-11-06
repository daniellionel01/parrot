import child_process.{type Builder}
import child_process/stdio
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/string

pub type CommandError {
  /// It could not be started, f.e. because it is not installed.
  CouldNotStart(reason: child_process.StartError)
  /// It exited with a non-zero `status`. `output` is everything it printed,
  /// or `None` if its errors went straight to the terminal.
  Failed(status: Int, output: Option(String))
}

/// Runs a command for its output, f.e. a schema dump. Warnings and errors
/// on stderr go to the terminal instead of into the output.
///
pub fn output(command: Builder) -> Result(String, CommandError) {
  run_capturing(command, stderr: False)
}

/// Runs a command for its effect. Errors with everything it printed if it
/// does not exit successfully.
///
pub fn run(command: Builder) -> Result(String, CommandError) {
  run_capturing(command, stderr: True)
}

fn run_capturing(
  command: Builder,
  stderr stderr: Bool,
) -> Result(String, CommandError) {
  case child_process.run(command, stdio.capture(stderr)) {
    Ok(child_process.Output(status_code: 0, output:)) -> Ok(output)
    Ok(child_process.Output(status_code:, output:)) ->
      Error(
        Failed(status: status_code, output: case stderr {
          True -> Some(string.trim(output))
          False -> None
        }),
      )
    Error(reason) -> Error(CouldNotStart(reason))
  }
}

pub fn describe_error(error: CommandError) -> String {
  case error {
    CouldNotStart(reason) -> child_process.describe_start_error(reason)
    Failed(status:, output: None) ->
      "exited with status " <> int.to_string(status) <> ", see its errors above"
    Failed(status:, output: Some("")) ->
      "exited with status " <> int.to_string(status)
    Failed(output: Some(output), ..) -> output
  }
}
