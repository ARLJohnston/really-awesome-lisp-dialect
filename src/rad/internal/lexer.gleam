import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import rad/internal/tokens.{type Token}

pub type LexError {
  InvalidExpression(String)
}

pub const unterminated_string_error: LexError = InvalidExpression(
  "Did you forget to close your string there bud?",
)

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
    [" ", ..rest] -> lex_chars(rest, acc)
    ["\"", ..rest] -> {
      result.try(lex_string(rest, []), fn(res) {
        let #(str, rest) = res
        lex_chars(rest, [tokens.Str(str), ..acc])
      })
    }

    _ -> {
      let #(token_chars, rest) = split_at_delim(chars, [])
      let token_str = string.join(token_chars, "")

      let token = case float.parse(token_str) {
        Ok(n) -> tokens.Floating(n)
        Error(_) ->
          case int.parse(token_str) {
            Ok(n) -> tokens.Integer(n)
            Error(_) -> tokens.Symbol(token_str)
          }
      }

      lex_chars(rest, [token, ..acc])
    }
  }
}

pub fn lex_string(chars, acc) -> Result(#(String, List(String)), LexError) {
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
    [" ", ..rest] -> #(list.reverse(acc), rest)
    ["(", ..rest] -> #(list.reverse(acc), ["(", ..rest])
    [")", ..rest] -> #(list.reverse(acc), [")", ..rest])
    [char, ..rest] -> split_at_delim(rest, [char, ..acc])
    [] -> #(list.reverse(acc), [])
  }
}
