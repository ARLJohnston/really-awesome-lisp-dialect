import gleam/bool
import gleam/list
import gleam/result
import gleam/string
import rad/internal/number
import rad/internal/tokens.{type Token}

pub type LexError {
  InvalidExpression(String)
}

pub const unterminated_string_error: LexError = InvalidExpression(
  "Did you forget to close your string there bud?",
)

fn number_error(str: String, reason: String) -> LexError {
  InvalidExpression("invalid number `" <> str <> "`: " <> reason)
}

pub fn lex(input: String) -> Result(List(Token), LexError) {
  input
  |> string.trim
  |> string.to_graphemes
  |> lex_chars([])
}

fn lex_chars(
  chars: List(String),
  acc: List(Token),
) -> Result(List(Token), LexError) {
  case chars {
    [] -> Ok(list.reverse(acc))

    ["(", ..rest] -> lex_chars(rest, [tokens.LParen, ..acc])
    [")", ..rest] -> lex_chars(rest, [tokens.RParen, ..acc])

    ["'", ..rest] -> lex_chars(rest, [tokens.Quote, ..acc])

    [";", ..rest] -> {
      let #(comment, rest) = lex_comment(rest, [])
      lex_chars(rest, [tokens.Comment(comment), ..acc])
    }

    ["\"", ..rest] -> {
      result.try(lex_string(rest, []), fn(res) {
        let #(str, rest) = res
        lex_chars(rest, [tokens.Str(str), ..acc])
      })
    }

    [char, ..rest] -> {
      use <- bool.guard(is_whitespace(char), lex_chars(rest, acc))

      let #(token_chars, rest) = split_at_delim(chars, [])

      case string.join(token_chars, "") {
        "." -> lex_chars(rest, [tokens.Dot, ..acc])

        str -> {
          use <- bool.guard(
            !number.is_number_start(str),
            lex_chars(rest, [tokens.Symbol(str), ..acc]),
          )

          use token <- result.try(case string.contains(str, ".") {
            True -> {
              number.parse_to_float(str)
              |> result.map_error(fn(e) {
                number_error(str, number.describe_number(e))
              })
              |> result.map(tokens.Floating)
            }

            False -> {
              number.parse_to_int(str)
              |> result.map_error(fn(e) {
                number_error(str, number.describe_group(e))
              })
              |> result.map(tokens.Integer)
            }
          })

          lex_chars(rest, [token, ..acc])
        }
      }
    }
  }
}

pub fn lex_string(
  chars: List(String),
  acc: List(String),
) -> Result(#(String, List(String)), LexError) {
  case chars {
    [] -> Error(unterminated_string_error)

    ["\"", ..rest] -> {
      let str = acc |> list.reverse() |> string.join("")
      Ok(#(str, rest))
    }

    ["\\", next_char, ..rest] -> {
      case next_char {
        "n" -> lex_string(rest, ["\n", ..acc])
        "t" -> lex_string(rest, ["\t", ..acc])
        "r" -> lex_string(rest, ["\r", ..acc])
        "f" -> lex_string(rest, ["\f", ..acc])
        other_char -> lex_string(rest, [other_char, ..acc])
      }
    }

    [char, ..rest] -> lex_string(rest, [char, ..acc])
  }
}

pub fn split_at_delim(
  chars: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case chars {
    ["(", ..rest] -> #(list.reverse(acc), ["(", ..rest])
    [")", ..rest] -> #(list.reverse(acc), [")", ..rest])
    [char, ..rest] ->
      case is_whitespace(char) {
        True -> #(list.reverse(acc), rest)
        False -> {
          split_at_delim(rest, [char, ..acc])
        }
      }
    [] -> #(list.reverse(acc), [])
  }
}

pub fn is_whitespace(char: String) -> Bool {
  case char {
    " " | "\n" | "\r" | "\t" -> True
    _ -> False
  }
}

pub fn lex_comment(
  chars: List(String),
  acc: List(String),
) -> #(String, List(String)) {
  case chars {
    [] -> {
      let comment = acc |> list.reverse() |> string.join("")
      #(comment, [])
    }
    ["\n", ..rest] -> {
      let comment = acc |> list.reverse() |> string.join("")
      #(comment, rest)
    }
    [char, ..rest] -> lex_comment(rest, [char, ..acc])
  }
}
