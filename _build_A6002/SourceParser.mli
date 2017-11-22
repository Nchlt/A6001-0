
(* The type of tokens. *)

type token = 
  | WHILE
  | VAR
  | TO
  | THEN
  | STAR
  | SET
  | SEMI
  | PRINT
  | PLUS
  | OR
  | OPEN_CBRACKET
  | OPEN_BRACKET
  | NEQ
  | MINUS
  | MAIN
  | LT
  | LE
  | INT
  | IF
  | IDENT of (string)
  | FOR
  | EQUAL_STRUCT
  | EQUAL
  | EOF
  | END
  | ELSE
  | CONST_INT of (int)
  | CONST_BOOL of (bool)
  | CLOSE_CBRACKET
  | CLOSE_BRACKET
  | BOOL
  | BEGIN
  | AND

(* This exception is raised by the monolithic API functions. *)

exception Error

(* The monolithic API. *)

val main: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> (SourceAst.main)
