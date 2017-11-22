%{

  open SourceAst

%}

%token <int> CONST_INT
%token PLUS MINUS STAR
%token <bool> CONST_BOOL
%token AND OR
%token EQUAL NEQ LT LE
%token <string> IDENT
%token BEGIN END
%token IF THEN ELSE
%token WHILE
%token SEMI COMMA
%token SET
%token VAR
%token INT BOOL
%token PRINT
%token EOF
%token MAIN

%left AND OR
%left LE LT EQUAL NEQ
%left PLUS MINUS
%left STAR

%start prog
%type <SourceAst.program> prog

%%

prog:
| l=list(fun_decl) {
    let info = {
      return=Some(TypInteger);
      formals=[TypInteger; TypInteger];
      locals=Symb_Tbl.empty;
      code=[]
    } in

    Symb_Tbl.singleton "id" info

  } (* initialisation des Symb_Tbl *)

/*main:
| MAIN; BEGIN; INT; x=IDENT; END;
  BEGIN; vds=var_decls; is=instructions; END; EOF  {
    let infox = { typ=TypInteger; kind=FormalX } in
    let init  = Symb_Tbl.singleton x infox in
    let merge_vars _ v1 v2 = match v1, v2 with
      | _, Some(v) -> Some v
      | Some(v), _ -> Some v
      | _, _       -> None
    in
    let locals = Symb_Tbl.merge merge_vars init vds in
    {locals = locals; code=is} }
;*/

var_decls:
| (* empty *)                      { Symb_Tbl.empty                            }
| vd=var_decl; SEMI; vds=var_decls { let (id, t) = vd in
				     let info = { typ=t; kind=Local } in
				     Symb_Tbl.add id info vds }
;

var_decl:
| VAR; tid=typed_ident  { tid }
;

typed_ident:
| t=typ; id=IDENT  { (id, t) }
;

typ:
| INT   { TypInteger }
| BOOL  { TypBoolean }
;

instructions:
| (* empty *)                              { []      }
| i=instruction; SEMI; is=instructions     { i :: is }
;

instruction:
| l=location; SET; e=expression                     { Set(l, e)     }
| WHILE; e=expression; b=block                      { While(e, b)   }
| IF; e=expression; THEN; b1=block; ELSE; b2=block  { If(e, b1, b2) }
| PRINT; BEGIN; e=expression; END                   { Print(e)      }
| c=call                                            { ProcCall(c)   }
;

block:
| BEGIN; is=instructions; END        { is }
;

expression:
| lit=literal                             { Literal(lit)      }
| loc=location                            { Location(loc)     }
| BEGIN; e=expression; END                { e                 }
| e1=expression; op=binop; e2=expression  { Binop(op, e1, e2) }
| c=call                                  { FunCall(c)        }
;

literal:
| i=CONST_INT   { Int i  }
| b=CONST_BOOL  { Bool b }
;

location:
| id=IDENT  { Identifier id }
;

call:
| id=IDENT; BEGIN; args=arguments; END  { id, args }
;

arguments:
| al=separated_list(COMMA, expression)  { al }
;

parameters:
| pl=separated_list(COMMA, parameter)   { pl }
;

parameter:
| typ; IDENT {}
;

fun_decl:
| typ; IDENT; BEGIN; parameters; END; BEGIN; var_decls; instructions; END
  { }
| IDENT; BEGIN; parameters; END; BEGIN; var_decls; instructions; END
  { }
;

%inline binop:
| PLUS   { Add  }
| MINUS  { Sub  }
| STAR   { Mult }
| EQUAL  { Eq   }
| NEQ    { Neq  }
| LT     { Lt   }
| LE     { Le   }
| AND    { And  }
| OR     { Or   }
;
