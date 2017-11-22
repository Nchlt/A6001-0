{

  open Lexing
  open SourceParser

  let id_or_keyword =
    let h = Hashtbl.create 17 in
    List.iter (fun (s, k) -> Hashtbl.add h s k)
      [ "true",     CONST_BOOL(true);
	"false",    CONST_BOOL(false);
	"while",    WHILE;
	"if",       IF;
	"then",     THEN;
	"else",     ELSE;
	"integer",  INT;
	"boolean",  BOOL;
	"print",    PRINT;
	"main",     MAIN;
	"var",      VAR;
  "for",      FOR;
  "to",       TO
      ] ;
    fun s ->
      try  Hashtbl.find h s
      with Not_found -> IDENT(s)

}

let digit = ['0'-'9']
let alpha = ['a'-'z' 'A'-'Z']
let ident = ['a'-'z' '_'] (alpha | '_' | '\'' | digit)*

rule token = parse
  | ['\n' ' ' '\t' '\r']+
      { token lexbuf }
  | "(*"
      { comment lexbuf; token lexbuf }
  | digit+
      { CONST_INT (int_of_string (lexeme lexbuf)) }
  | ident
      { id_or_keyword (lexeme lexbuf) }
  | "("
      { BEGIN }
  | ")"
      { END }
  | ";"
      { SEMI }
  | ":="
      { SET }
  | "+"
      { PLUS }
  | "-"
      { MINUS }
  | "*"
      { STAR }
  | "=="
      { EQUAL }
  | "!="
      { NEQ }
  | "="
      { EQUAL_STRUCT }
  | "<"
      { LT }
  | "<="
      { LE }
  | "&&"
      { AND }
  | "||"
      { OR }
  | "["
      { OPEN_BRACKET }
  | "]"
      { CLOSE_BRACKET }
  | "{"
      { OPEN_CBRACKET }
  | "}"
      { CLOSE_CBRACKET }
  | _
      { failwith ("Unknown character : " ^ (lexeme lexbuf)) }
  | eof
      { EOF }

and comment = parse
  | "(*"
      { comment lexbuf; comment lexbuf }
  | "*)"
      { () }
  | _
      { comment lexbuf }
  | eof
      { failwith "Unterminated comment" }
