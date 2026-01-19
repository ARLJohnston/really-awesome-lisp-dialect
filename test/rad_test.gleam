import gleam/list
import gleeunit
import rad/internal/lexer

pub fn main() -> Nil {
  gleeunit.main()
}

type DelimTable {
  DelimTable(input: List(String), want: #(List(String), List(String)))
}

pub fn split_at_delim_test() {
  let tables = [DelimTable(["hello"], #(["hello"], []))]

  tables
  |> list.each(fn(table) {
    let got = lexer.split_at_delim(table.input, [])

    assert got == table.want
  })
}
