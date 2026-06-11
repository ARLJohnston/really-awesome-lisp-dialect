import gleam/list
import gleam/string
import gleeunit
import rad/internal/lexer
import rad/internal/tokens

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

type LexTable {
  LexTable(input: String, want: Result(List(tokens.Token), lexer.LexError))
}

type CommentTable {
  CommentTable(input: List(String), want: #(String, List(String)))
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

    // -- escapes
    // \n is translated to a real newline. graphemes: ["a", "\\", "n", "\""]
    StringTable(string.to_graphemes("a\\n\""), Ok(#("a\n", []))),
    // \t is translated to a real tab. graphemes: ["a", "\\", "t", "\""]
    StringTable(string.to_graphemes("a\\t\""), Ok(#("a\t", []))),
    // escaped quote: \" stores a literal " and does NOT close the string
    // the second quote closes it. graphemes: ["b","a","z","\\","\"","\""]
    StringTable(string.to_graphemes("baz\\\"\""), Ok(#("baz\"", []))),
    // escaped backslash: \\ stores a single literal backslash.
    // graphemes: ["\\", "\\", "\""]
    StringTable(string.to_graphemes("\\\\\""), Ok(#("\\", []))),
    // unknown escape is lenient: \q just yields q, no error.
    // graphemes: ["\\", "q", "\""]
    StringTable(string.to_graphemes("\\q\""), Ok(#("q", []))),

    // -- delimiters are literal inside a string
    StringTable(string.to_graphemes("a b\""), Ok(#("a b", []))),
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

pub fn lex_comment_test() {
  // NB: the `;` is already consumed by lex_chars before lex_comment is called
  let tables = [
    // runs to EOF with no newline: whole input is the comment, nothing left
    CommentTable(string.to_graphemes("a comment"), #("a comment", [])),
    // newline terminates the comment and is consumed; the rest is handed back
    CommentTable(
      string.to_graphemes("a comment\nfoo"),
      #("a comment", ["f", "o", "o"]),
    ),
    // bare `;` at EOF -> empty comment, nothing left over
    CommentTable(string.to_graphemes(""), #("", [])),
    // bare `;` then newline -> empty comment, rest after the newline
    CommentTable(string.to_graphemes("\nfoo"), #("", ["f", "o", "o"])),
    // the comment body is literal text: parens, quotes, ; don't re-trigger lexing
    CommentTable(string.to_graphemes("; (a) \"x"), #("; (a) \"x", [])),
  ]

  tables
  |> list.each(fn(table) {
    let got = lexer.lex_comment(table.input, [])

    assert got == table.want
  })
}

pub fn lex_test() {
  let tables = [
    // empty / whitespace-only input lexes to no tokens
    LexTable("", Ok([])),
    LexTable("   ", Ok([])),
    // leading/trailing whitespace is trimmed off before lexing
    LexTable("  (a)  ", Ok([tokens.LParen, tokens.Symbol("a"), tokens.RParen])),

    // newline, tab, return treated as whitespace
    LexTable(
      "(a\n\t\rb)",
      Ok([tokens.LParen, tokens.Symbol("a"), tokens.Symbol("b"), tokens.RParen]),
    ),

    // -- float, then int, then symbol
    LexTable("42", Ok([tokens.Integer(42)])),
    LexTable("-7", Ok([tokens.Integer(-7)])),
    LexTable("3.14", Ok([tokens.Floating(3.14)])),
    LexTable("foo", Ok([tokens.Symbol("foo")])),
    LexTable("+", Ok([tokens.Symbol("+")])),

    // -- lists
    LexTable(
      "(foo bar)",
      Ok([
        tokens.LParen,
        tokens.Symbol("foo"),
        tokens.Symbol("bar"),
        tokens.RParen,
      ]),
    ),
    LexTable("(foo)", Ok([tokens.LParen, tokens.Symbol("foo"), tokens.RParen])),
    LexTable(
      "(a (b c))",
      Ok([
        tokens.LParen,
        tokens.Symbol("a"),
        tokens.LParen,
        tokens.Symbol("b"),
        tokens.Symbol("c"),
        tokens.RParen,
        tokens.RParen,
      ]),
    ),
    // every token kind
    LexTable(
      "(+ 1 2.0 \"hi\")",
      Ok([
        tokens.LParen,
        tokens.Symbol("+"),
        tokens.Integer(1),
        tokens.Floating(2.0),
        tokens.Str("hi"),
        tokens.RParen,
      ]),
    ),
    // a string with spaces inside stays a single `Str` token
    LexTable(
      "(echo \"a b\")",
      Ok([
        tokens.LParen,
        tokens.Symbol("echo"),
        tokens.Str("a b"),
        tokens.RParen,
      ]),
    ),

    // -- quote
    // no space case: ' against a symbol splits cleanly
    LexTable("'foo", Ok([tokens.Quote, tokens.Symbol("foo")])),
    // split case: ' against a list
    LexTable(
      "'(a b)",
      Ok([
        tokens.Quote,
        tokens.LParen,
        tokens.Symbol("a"),
        tokens.Symbol("b"),
        tokens.RParen,
      ]),
    ),
    // nested quoting just works: '' is two Quote tokens
    LexTable("''foo", Ok([tokens.Quote, tokens.Quote, tokens.Symbol("foo")])),

    // -- comments
    // a whole-line comment lexes to a single Comment token
    LexTable(";comment", Ok([tokens.Comment("comment")])),
    // mid-list: comment ends at the newline and does NOT swallow `b`
    LexTable(
      "(a ; hi\n b)",
      Ok([
        tokens.LParen,
        tokens.Symbol("a"),
        tokens.Comment(" hi"),
        tokens.Symbol("b"),
        tokens.RParen,
      ]),
    ),
    // bare `;` at EOF -> empty Comment
    LexTable("foo ;", Ok([tokens.Symbol("foo"), tokens.Comment("")])),

    // -- error propagation
    LexTable("(foo \"bar)", Error(lexer.unterminated_string_error)),
  ]

  tables
  |> list.each(fn(table) {
    let got = lexer.lex(table.input)

    assert got == table.want
  })
}
