import child_process.{type Builder}
import child_process/stdio
import gleam/int
import gleam/string

/// Runs a command for its output, f.e. a schema dump. Warnings and errors
/// on stderr go to the terminal instead of into the output.
///
pub fn output(command: Builder) -> Result(String, String) {
  case run_capturing(command, stderr: False) {
    Error("exited with status " <> _ as e) ->
      Error(e <> ", see its errors above")
    result -> result
  }
}

/// Runs a command for its effect. Errors with everything it printed if it
/// does not exit successfully.
///
pub fn run(command: Builder) -> Result(String, String) {
  run_capturing(command, stderr: True)
}

fn run_capturing(
  command: Builder,
  stderr stderr: Bool,
) -> Result(String, String) {
  case child_process.run(command, stdio.capture(stderr)) {
    Ok(child_process.Output(status_code: 0, output:)) -> Ok(output)
    Ok(child_process.Output(status_code:, output:)) ->
      case string.trim(output) {
        "" -> Error("exited with status " <> int.to_string(status_code))
        output -> Error(output)
      }
    Error(e) -> Error(child_process.describe_start_error(e))
  }
}
