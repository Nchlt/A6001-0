open SourceAst

module State = Map.Make(String)
type state = int State.t

let rec eval_main p x d =
  eval_block (State.singleton "x" x) d p.code

(* [eval_block: state -> block -> state] *)
and eval_block env d = function
  | []   -> env
  | i::b -> let env1 = eval_instruction env d i in
    eval_block env1 d b

(* [eval_instruction: state -> instruction -> state] *)
and eval_instruction env d = function
  | Set(Identifier id, e) -> State.add id (eval_expression env e) env
  | While(c, b) as iw ->
    if eval_expression env c <> 0
    then let env = eval_block env d b in
      eval_instruction env d iw
    else env
  | If(c, b1, b2) ->
    if eval_expression env c <> 0
    then eval_block env d b1
    else eval_block env d b2
  | Print(e) ->
    let e = eval_expression env e in
    if d then Printf.printf "(%d)" e;
    Printf.printf "%c" (char_of_int e); env

(* [eval_expression: state -> expression -> int] *)
and eval_expression env = function
  | Literal(lit)  -> eval_literal env lit
  | Location(loc) -> eval_location env loc
  | Binop(op, e1, e2) -> let v1 = eval_expression env e1 in
    let v2 = eval_expression env e2 in
    let op = match op with
      | Add  -> (+)
      | Mult -> ( * )
      | Sub  -> (-)
      | Eq   -> eval_bool_op (=)
      | Neq  -> eval_bool_op (<>)
      | Lt   -> eval_bool_op (<)
      | Le   -> eval_bool_op (<=)
      | And  -> min
      | Or   -> max
    in
    op v1 v2

and eval_bool b = if b then 1 else 0
and eval_bool_op op = fun v1 v2 -> eval_bool (op v1 v2)

and eval_literal env = function
  | Int(i)  -> i
  | Bool(b) -> eval_bool b

and eval_location env = function
  | Identifier(id) -> State.find id env
