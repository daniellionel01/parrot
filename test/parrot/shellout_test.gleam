import gleam/dict
import gleam/string
import gleeunit/should
import parrot/internal/shellout.{
  type Lookups, LetBeStderr, LetBeStdout, SetEnvironment,
}

const message = "Howdy!"

const lookups: Lookups = [
  #(
    ["color", "background"],
    [
      #("buttercup", ["252", "226", "174"]),
      #("mint", ["182", "255", "234"]),
      #("pink", ["255", "175", "243"]),
    ],
  ),
]

pub fn arguments_test() {
  shellout.arguments()
  |> should.equal([])
}

pub fn command_test() {
  let print = shellout.command(run: "echo", with: [message], in: ".", opt: _)

  let assert Ok(output) = print([])
  output
  |> should.not_equal("")

  let assert Ok(new_output) = print([LetBeStderr])
  new_output
  |> should.equal(output)

  let assert Error(#(status, message)) =
    shellout.command(run: "dimension_x", with: [], in: ".", opt: [])
  status
  |> should.equal(1)
  message
  |> should.not_equal("")

  let assert Error(#(status, message)) =
    shellout.command(run: "echo", with: [], in: "dimension_x", opt: [])
  status
  |> should.equal(2)
  message
  |> should.not_equal("")
}

pub fn environment_test() {
  let print = fn(env, message) {
    shellout.command(
      run: "sh",
      with: ["-c", string.concat(["printf '%s' \"", message, "\""])],
      in: ".",
      opt: [SetEnvironment(env)],
    )
  }

  print([#("TEST_1", "1"), #("TEST_2", "2")], "$TEST_1 $TEST_2 3")
  |> should.equal(Ok("1 2 3"))

  print([#("PATH", "/bin:/ビン")], "$PATH")
  |> should.equal(Ok("/bin:/ビン"))

  shellout.command(
    run: "sh",
    with: ["-c", "printf '%s' \"$TEST_3 $TEST_2 $TEST_1\""],
    in: ".",
    opt: [
      SetEnvironment([#("TEST_1", "3"), #("TEST_3", "3")]),
      SetEnvironment([#("TEST_1", "1"), #("TEST_2", "2")]),
    ],
  )
  |> should.equal(Ok("3 2 1"))

  let test_var = fn(env, var) {
    shellout.command(
      run: "sh",
      with: ["-c", string.concat(["test -n \"$", var, "\""])],
      in: ".",
      opt: [SetEnvironment(env)],
    )
  }

  test_var([], "HOME")
  |> should.be_ok

  test_var([#("HOME", "")], "HOME")
  |> should.be_error
}

fn should_be_without_stdout(message) {
  // Erlang ports can't separate stderr from stdout; it's all or nothing
  message
  |> should.equal("")
}

pub fn style_test() {
  let styled =
    message
    |> shellout.style(with: shellout.background(["yellow"]), custom: [])
  styled
  |> string.starts_with(message)
  |> should.be_false
  styled
  |> string.ends_with(message)
  |> should.be_false

  let styled =
    message
    |> shellout.style(
      with: shellout.display(["bold", "italic"])
        |> dict.merge(shellout.color(["pink"]))
        |> dict.merge(shellout.background(["brightblack"])),
      custom: lookups,
    )
  styled
  |> string.starts_with(message)
  |> should.be_false
  styled
  |> string.ends_with(message)
  |> should.be_false
}

pub fn which_test() {
  "echo"
  |> shellout.which
  |> should.be_ok

  ""
  |> shellout.which
  |> should.be_error
}
