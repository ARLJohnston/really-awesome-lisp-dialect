pub type Token {
  LParen
  RParen

  Dot
  Quote

  Symbol(String)

  Integer(Int)
  Floating(Float)

  Str(String)
  Comment(String)
}
