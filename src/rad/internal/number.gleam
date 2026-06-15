import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type InvalidNumberError {
  MissingDot
  TooManyDots
  IntegerPart(DigitGroupError)
  FractionalPart(DigitGroupError)
}

pub fn describe_number(e: InvalidNumberError) -> String {
  case e {
    MissingDot -> "a float must have a decimal point"
    TooManyDots -> "cannot have more than one decimal point"
    IntegerPart(g) -> "integer part: " <> describe_group(g)
    FractionalPart(g) -> "fractional part: " <> describe_group(g)
  }
}

pub type DigitGroupError {
  ConsecutiveUnderscore
  StartingUnderscore
  TrailingUnderscore
  InvalidChars
  EmptyString
}

pub fn describe_group(g: DigitGroupError) -> String {
  case g {
    ConsecutiveUnderscore -> "cannot contain consecutive underscores"
    StartingUnderscore -> "cannot start with an underscore"
    TrailingUnderscore -> "cannot end with an underscore"
    InvalidChars -> "can only contain digits and underscores"
    EmptyString -> "is empty"
  }
}

pub fn parse_to_int(num_str: String) -> Result(Int, DigitGroupError) {
  let #(sign, digits) = separate_sign(num_str)
  use _ <- result.try(validate_digit_group(digits))

  let assert Ok(n) =
    digits
    |> string.replace("_", "")
    |> int.parse
    as "validation guarantees non-empty, digits-only string"

  Ok(case sign {
    Positive -> n
    Negative -> int.negate(n)
  })
}

pub fn parse_to_float(num_str: String) -> Result(Float, InvalidNumberError) {
  let #(sign, digits) = separate_sign(num_str)
  use _ <- result.try(validate_float_str(digits))

  let assert Ok(n) =
    digits
    |> string.replace("_", "")
    |> float.parse
    as "validation guarantees non-empty, digits-only string"

  Ok(case sign {
    Positive -> n
    Negative -> float.negate(n)
  })
}

type Sign {
  Positive
  Negative
}

fn separate_sign(num_str: String) -> #(Sign, String) {
  use <- bool.guard(string.starts_with(num_str, "+"), #(
    Positive,
    string.drop_start(num_str, 1),
  ))
  use <- bool.guard(string.starts_with(num_str, "-"), #(
    Negative,
    string.drop_start(num_str, 1),
  ))
  #(Positive, num_str)
}

fn validate_digit_group(num_str: String) -> Result(Nil, DigitGroupError) {
  let chars = string.to_graphemes(num_str)

  case list.first(chars), list.last(chars) {
    Ok(first), Ok(last) -> {
      let starts_with_digit = first != "_"
      let ends_with_digit = last != "_"

      let no_double_underscore =
        chars
        |> list.window_by_2()
        |> list.all(fn(chars) {
          case chars {
            #("_", "_") -> False
            _ -> True
          }
        })

      let only_digits_and_underscore =
        list.all(chars, fn(c) { c == "_" || is_digit(c) })

      use <- bool.guard(!only_digits_and_underscore, Error(InvalidChars))
      use <- bool.guard(!starts_with_digit, Error(StartingUnderscore))
      use <- bool.guard(!ends_with_digit, Error(TrailingUnderscore))
      use <- bool.guard(!no_double_underscore, Error(ConsecutiveUnderscore))

      Ok(Nil)
    }

    _, _ -> Error(EmptyString)
  }
}

fn validate_float_str(num_str: String) -> Result(Nil, InvalidNumberError) {
  case string.split(num_str, ".") {
    [_] -> Error(MissingDot)

    [lhs, rhs] -> {
      use _ <- result.try(validate_part(lhs, IntegerPart))
      validate_part(rhs, FractionalPart)
    }

    _ -> Error(TooManyDots)
  }
}

fn validate_part(
  part: String,
  side_wrapper: fn(DigitGroupError) -> InvalidNumberError,
) -> Result(Nil, InvalidNumberError) {
  validate_digit_group(part)
  |> result.map_error(side_wrapper)
}

fn is_digit(char: String) -> Bool {
  case char {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}

pub fn is_number_start(str: String) -> Bool {
  // a number is an optional sign followed by a digit
  let unsigned = case string.pop_grapheme(str) {
    Ok(#("+", rest)) | Ok(#("-", rest)) -> rest
    _ -> str
  }

  case string.pop_grapheme(unsigned) {
    Ok(#(c, _)) -> is_digit(c)
    Error(_) -> False
  }
}
