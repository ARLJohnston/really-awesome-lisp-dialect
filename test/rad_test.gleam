import gleam/list
import gleam/string
import gleeunit
import rad/internal/lexer

pub fn main() -> Nil {
  gleeunit.main()
}

type DelimTable {
  DelimTable(input: List(String), want: #(List(String), List(String)))
}

type StringTable {
  StringTable(
    input: List(String),
    want: Result(#(String, List(String)), lexer.LexError),
  )
}

pub fn split_at_delim_test() {
  let tables = [
    // no delimiter: consume everything, nothing left over
    DelimTable(["hello"], #(["hello"], [])),
    // space delimiter: consumed (dropped), the rest continues after it
    DelimTable(["a", "b", " ", "c"], #(["a", "b"], ["c"])),
    // "(" delimiter: NOT consumed, kept at the head of the remainder
    DelimTable(["a", "b", "(", "c"], #(["a", "b"], ["(", "c"])),
    // ")" delimiter: likewise kept in the remainder
    DelimTable(["f", "o", "o", ")"], #(["f", "o", "o"], [")"])),
    // leading delimiter: empty token, delimiter still kept for the caller
    DelimTable(["(", "a"], #([], ["(", "a"])),
    // empty input: empty token, nothing left over
    DelimTable([], #([], [])),
  ]

  tables
  |> list.each(fn(table) {
    let got = lexer.split_at_delim(table.input, [])

    assert got == table.want
  })
}

pub fn lex_string_test() {
  // NB: the opening `"` is already consumed by lex_chars before lex_string is
  // called, so these inputs omit the opening quote but include the closing one.
  // NB2: \\\I\\\hate\\\strings\\\
  let tables = [
    // happy path: accumulate chars until the closing quote, nothing left over
    StringTable(string.to_graphemes("hello\""), Ok(#("hello", []))),
    // remainder: anything after the closing quote is handed back untouched
    StringTable(string.to_graphemes("hi\")"), Ok(#("hi", [")"]))),
    // empty string: just a closing quote -> empty contents
    StringTable(string.to_graphemes("\""), Ok(#("", []))),

    // -- escapes (input has a real backslash so the escape branch fires)
    // \n is translated to a real newline. graphemes: ["a", "\\", "n", "\""]
    StringTable(string.to_graphemes("a\\n\""), Ok(#("a\n", []))),
    // \t is translated to a real tab. graphemes: ["a", "\\", "t", "\""]
    StringTable(string.to_graphemes("a\\t\""), Ok(#("a\t", []))),
    // escaped quote: \" stores a literal " and does NOT close the string;
    // the second quote closes it. graphemes: ["b","a","z","\\","\"","\""]
    StringTable(string.to_graphemes("baz\\\"\""), Ok(#("baz\"", []))),
    // escaped backslash: \\ stores a single literal backslash.
    // graphemes: ["\\", "\\", "\""]
    StringTable(string.to_graphemes("\\\\\""), Ok(#("\\", []))),
    // unknown escape is lenient: \q just yields q, no error.
    // graphemes: ["\\", "q", "\""]
    StringTable(string.to_graphemes("\\q\""), Ok(#("q", []))),

    // -- delimiters are literal inside a string (unlike split_at_delim)
    // spaces are kept, not treated as separators
    StringTable(string.to_graphemes("a b\""), Ok(#("a b", []))),
    // parens are kept as ordinary characters, not tokenised
    StringTable(string.to_graphemes("(x)\""), Ok(#("(x)", []))),

    // unterminated: input runs out before a closing quote
    StringTable(
      string.to_graphemes("eof"),
      Error(lexer.unterminated_string_error),
    ),
    // trailing backslash at EOF: the escape has no following char
    // so input runs out unterminated. graphemes: ["\\"]
    StringTable(
      string.to_graphemes("\\"),
      Error(lexer.unterminated_string_error),
    ),
  ]

  tables
  |> list.each(fn(table) {
    let got = lexer.lex_string(table.input, [])

    assert got == table.want
  })
}
// todo: integration tests for `lex`
