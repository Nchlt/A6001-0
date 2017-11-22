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

/*prog:
| l=list(fun_decl) {
  let rec init_tbl l =
    match l with
    | [] -> ()
    | t :: s ->
      let id, info = t in
      Symb_Tbl.add id info
}*/

prog:
| EOF { Symb_Tbl.empty }
| fs=fun_decl; p=prog
    {
      let (id, info) = fs in
      Symb_Tbl.add id info p
    }

(*
    {
      return=Some(TypInteger);
      formals=[TypInteger; TypInteger];
      locals=Symb_Tbl.empty;
      code=[]
    } in

    Symb_Tbl.singleton "id" info*)

   (* initialisation des Symb_Tbl *)

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
  {
    let merge_vars k v1 v2 =
        match v1, v2 with
        |Some v1,_ -> Some v1
        |None,Some v2 -> Some v2
        |None,None -> None
        in


      let index = ref 0 in
      let ftl = List.fold_left (fun acc (t,i) ->
        incr index; Symb_Tbl.add i {typ=t; kind=Formal(!index)} acc )
        Symb_Tbl.empty ps in

      let locals = Symb_Tbl.merge merge_vars vds ftl in
      let locals = Symb_Tbl.add "result" { typ=t; kind=Return } locals in
      let formals = List.fold_left (fun acc (t,id) -> (t,id)::acc) [] ps in
      (*On retourne un couple id, infos :*)
      id, {
        return=Some t;
        formals=formals;
        locals=locals;
        code=is
      }
  }
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
