import gleam/float
import gleam/int
import gleam/list
import gleam/string
import rad/internal/tokens.{type Token}

pub type LexError {
  InvalidExpression(String)
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
    [" ", ..rest] -> lex_chars(rest, acc)

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
