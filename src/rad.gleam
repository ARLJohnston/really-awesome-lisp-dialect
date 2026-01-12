import gleam/io
import gleam/result
import gleam/string
import lib/lexer
import simplifile

pub fn main() -> Nil {
  let result = {
    use input <- result.try(
      simplifile.read("source.rad") |> result.map_error(string.inspect),
    )

    use tokens <- result.try(
      lexer.lex(input) |> result.map_error(string.inspect),
    )

    Ok(tokens)
  }

  case result {
    Ok(schedule) -> io.println(string.inspect(schedule))
    Error(msg) -> io.println(msg)
  }
}
