import argv
import gleam/io
import gleam/result
import gleam/string
import rad/internal/lexer
import simplifile

pub fn main() -> Int {
  let args = argv.load().arguments

  case args {
    ["run", source] -> {
      run(source)
    }
    ["repl"] -> {
      repl()
    }
    _ -> {
      help()
      1
    }
  }
}

pub fn run(source: String) -> Int {
  let result = {
    use input <- result.try(
      simplifile.read(source) |> result.map_error(string.inspect),
    )

    use tokens <- result.try(
      lexer.lex(input) |> result.map_error(string.inspect),
    )

    Ok(tokens)
  }

  case result {
    Ok(schedule) -> {
      io.println(string.inspect(schedule))
      0
    }
    Error(msg) -> {
      io.println(msg)
      1
    }
  }
}

pub fn repl() -> Int {
  todo
}

pub fn help() -> Nil {
  io.println("Must be run with either run or repl")
}
