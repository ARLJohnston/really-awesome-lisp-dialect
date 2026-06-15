import gleam/list
import rad/internal/number

type IntTable {
  IntTable(input: String, want: Result(Int, number.DigitGroupError))
}

pub fn parse_num_int_test() {
  let tables = [
    IntTable("42", Ok(42)),
    IntTable("-7", Ok(-7)),

    // underscores are stripped before parsing, anywhere in the string
    IntTable("1_000", Ok(1000)),
    IntTable("10_00", Ok(1000)),
    IntTable("_100", Error(number.StartingUnderscore)),
    // this should probably be a symbol?
    IntTable("100_", Error(number.TrailingUnderscore)),
    IntTable("1__0", Error(number.ConsecutiveUnderscore)),
    IntTable("1_0_0_______", Error(number.TrailingUnderscore)),

    // a float string is not a valid int
    IntTable("3.14", Error(number.InvalidChars)),
    // non-numeric input fails
    IntTable("foo", Error(number.InvalidChars)),
    // empty input fails
    IntTable("", Error(number.EmptyString)),
    // underscores-only strips to "" -> fails
    IntTable("___", Error(number.StartingUnderscore)),
  ]

  tables
  |> list.each(fn(table) {
    let got = number.parse_to_int(table.input)
    assert got == table.want
  })
}

type FloatTable {
  FloatTable(input: String, want: Result(Float, number.InvalidNumberError))
}

pub fn parse_num_float_test() {
  let tables = [
    FloatTable("3.14", Ok(3.14)),
    FloatTable("-2.0", Ok(-2.0)),

    // underscores are stripped here too
    FloatTable("1_000.5", Ok(1000.5)),

    // float.parse wants digits on BOTH sides of the dot
    FloatTable("42", Error(number.MissingDot)),
    FloatTable(".5", Error(number.IntegerPart(number.EmptyString))),
    FloatTable("5.", Error(number.FractionalPart(number.EmptyString))),

    // non-numeric input fails
    FloatTable("foo", Error(number.MissingDot)),
    FloatTable("", Error(number.MissingDot)),
  ]

  tables
  |> list.each(fn(table) {
    let got = number.parse_to_float(table.input)
    assert got == table.want
  })
}
