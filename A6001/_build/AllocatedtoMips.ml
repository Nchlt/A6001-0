open AllocatedAst
open Mips

let generate_main p =

  (* Affecte des emplacements mémoire aux variables locales. *)
  let sp_off = p.offset in
  let symb_tbl = p.locals in
  let find_alloc id =
    try  AllocatedAst.Symb_Tbl.find id symb_tbl
    with Not_found -> failwith (Printf.sprintf "Node %s not found" id)
  in

  let rec generate_block = function
    | []       -> Nop
    | (l,i)::b -> comment l @@ generate_instr i @@ generate_block b

  (* Un appel [load_literal r v] génère du code qui place la valeur
     immédiate [v] dans le registre [r]. *)
  and load_literal r : AllocatedAst.literal -> 'a Mips.asm = function
    | Int(i)  -> li r i
    | Bool(b) -> let i = if b then -1 else 0 in li r i

  (* Un appel [load_value r v] génère du code qui place la valeur [v]
     dans le registre [r]. *)
  and load_value r : AllocatedAst.value -> 'a Mips.asm = function
    | Literal(lit)   -> load_literal r lit
    | Identifier(id) -> (match find_alloc id with
	| Reg r'  -> move r r'
	| Stack o -> lw r o ~$fp)

  (* Variante optimisée de [load_value], qui place la valeur dans le
     registre [r] sauf si cette valeur est déjà stockée dans un
     registre [r'].
     Renvoie le code généré et le registre de destination effectif. *)
  and load_operand r : AllocatedAst.value -> Mips.register * 'a Mips.asm =
    function
      | Literal(lit)   -> r, load_literal r lit
      | Identifier(id) ->
	(match find_alloc id with
	  | Reg r'  -> r', Nop
	  | Stack o -> r, lw r o ~$fp
	)
  (* Spécialisations pour les premier et second opérandes d'une opération. *)
  and load_first_operand v  = load_operand ~$t0 v
  and load_second_operand v = load_operand ~$t1 v

  and generate_instr : AllocatedAst.instruction -> 'a Mips.asm = function
      (* FunCall(res_id, fun_id, param_list) -> failwith "NYI"  *)
      (*L'appellant doit réserver ...*)
      | FunCall(i,s,v) ->

        let save_args, nb = List.fold_left (fun (acc,i) e ->
            (let reg1, inst1 = load_value_bis ~$t0 e in

             acc
             @@ inst1
             @@ (if i > 3 then sw reg1 ( -(i-4) * 4 - 4 ) ~$sp
                 else move ("$a"^string_of_int(i)) reg1 ),i+1 ) )

            (nop,0) v
        in

        let stack_args = (nb-4)*4 in

        let max_reg = Symb_Tbl.fold
            (fun id alloc_info acc ->
               match alloc_info with
                 Reg s -> let index = int_of_string (String.sub s 2 1) in
                 if index > acc then index else acc
               | _ -> acc)
            p.locals 0
        in

        let save_reg reg =
          let rec aux r =
            match r with
            | 2 -> sw ("$t"^string_of_int(r)) (-4) sp
            | n -> aux (n-1) @@ sw ("$t"^string_of_int(r)) (-(n-1) * 4) sp
          in
          aux reg @@ addi sp sp (-(reg-1) * 4)
        in

        let load_reg reg =
          let rec aux r =
            match r with
            | 2 -> lw ("$t"^string_of_int(r)) (-4) sp
            | n -> aux (n-1) @@ lw ("$t"^string_of_int(r)) (-(n-1) * 4) sp
          in
          addi sp sp ((reg-1) * 4) @@ aux reg in

        let load_res =
          match find_alloc i with
          | Reg r -> move r v0
          | Stack o -> sw v0 o ~$fp
        in

        (*Etape 1*)
        save_reg max_reg
        @@ save_args
        @@ addi sp sp (-stack_args)
        @@ jal s
        (*Etape 4*)
        @@ addi sp sp stack_args
        @@ load_reg max_reg
        @@ load_res

      | ProcCall(s,v) ->

        let save_args, nb = List.fold_left (fun (acc,i) e ->
            (let reg1, inst1 = load_value_bis ~$t0 e in

             acc
             @@ inst1
             @@ (if i > 3 then sw reg1 ( -(i-4) * 4 - 4 ) ~$sp
                 else move ("$a"^string_of_int(i)) reg1 ),i+1 ) )

            (nop,0) v
        in

        let stack_args = nb*4 in

        let max_reg = Symb_Tbl.fold
            (fun id alloc_info acc ->
               match alloc_info with
                 Reg s -> let index = int_of_string (String.sub s 2 1) in
                 if index > acc then index else acc
               | _ -> acc)
            p.locals 0
        in

        let save_reg reg =
          let rec aux r =
            match r with
            | 2 -> sw ("$t"^string_of_int(r)) (-4) sp
            | n -> aux (n-1) @@ sw ("$t"^string_of_int(r)) (-(n-1) * 4) sp
          in
          aux reg @@ addi sp sp (-(reg-1) * 4)
        in

        let load_reg reg =
          let rec aux r =
            match r with
            | 2 -> lw ("$t"^string_of_int(r)) (-4) sp
            | n -> aux (n-1) @@ lw ("$t"^string_of_int(r)) (-(n-1) * 4) sp
          in
          addi sp sp ((reg-1) * 4) @@ aux reg in

        (*Etape 1*)
        save_reg max_reg
        @@ save_args
        @@ addi sp sp (-stack_args)
        @@ jal s
        (*Etape 4*)
        @@ addi sp sp stack_args
        @@ load_reg max_reg



    | ProcCall(fun_id, param_list) -> failwith "NYI"
    | Value(dest, v) ->
      (match find_alloc dest with
	| Reg r   -> load_value r v
	| Stack o -> let r, a = load_first_operand v in
		     a @@ sw r o ~$fp
      )

    | Binop(dest, op, o1, o2) ->
      let op = match op with
	| Add  -> add
	| Mult -> mul
	| Sub  -> sub
	| Eq   -> seq
	| Neq  -> sne
	| Lt   -> slt
	| Le   -> sle
	| And  -> and_
	| Or   -> or_
      in
      let (r1, a1) = load_first_operand o1 in
      let (r2, a2) = load_second_operand o2 in
      let aop = match find_alloc dest with
	| Reg r   -> op r r1 r2
	| Stack o -> op ~$t0 r1 r2 @@ sw ~$t0 o ~$fp
      in
      a1 @@ a2 @@ aop

    | Print(v)        -> load_value ~$a0 v @@ li ~$v0 11 @@ syscall
    | Label(lab)      -> label lab
    | Goto(lab)       -> b lab
    | CondGoto(v,lab) -> load_value ~$t0 v @@ bnez ~$t0 lab
    | Comment(s)      -> comment s
  in

  let load_args =

    let args, index = List.fold_left
        (fun (v,i) arg -> match find_alloc arg with
           | Reg r -> (v @@ (if i > 3 then lw r ((i-4)*4 +8) ~$fp
                             else move r ("$a"^string_of_int(i))) ,i+1)
           | Stack o -> (v @@ (if i > 3
                               then lw ~$t0 ((i-4)*4 +8) ~$fp@@ sw ~$t0 o ~$fp
                               else sw ("$a"^string_of_int(i)) o ~$fp ) ,i+1) )
        (nop,0) (List.rev p.formals)
    in
    args
  in

  let store_res =
    if Symb_Tbl.mem "result" p.locals
    then
      match find_alloc "result" with
      | Reg r -> move v0 r
      | Stack o -> lw v0 o ~$fp
    else nop
  in

  let start_fun = (*Etape 2*)

    sw fp (-4) sp
    @@ sw ra (-8) sp
    @@ addi sp sp (-8)
    @@ move fp sp
    @@ addi sp sp sp_off
    @@ load_args
  in

  let end_fun = (*Etape 3*)
    store_res
    @@ lw ra 0 fp
    @@ lw fp 4 fp
    @@ addi sp sp (-sp_off+8)
    @@ jr ra
  in

  start_fun @@ (generate_block p.code) @@ end_fun

  let init =
    move fp sp
    @@ addi fp fp (-4)
    @@ lw a0 0 a1
    @@ jal "atoi"
    @@ sw v0 0 fp
    @@ addi sp sp sp_off
  in

  let close = li v0 10 @@ syscall in

  let built_ins =
    label "atoi"
    @@ move t0 a0
    @@ li   t1 0
    @@ li   t2 10
    @@ label "atoi_loop"
    @@ lbu  t3 0 t0
    @@ beq  t3 zero "atoi_end"
    @@ li   t4 48
    @@ blt  t3 t4 "atoi_error"
    @@ li   t4 57
    @@ bgt  t3 t4 "atoi_error"
    @@ addi t3 t3 (-48)
    @@ mul  t1 t1 t2
    @@ add  t1 t1 t3
    @@ addi t0 t0 1
    @@ b "atoi_loop"
    @@ label "atoi_error"
    @@ li   v0 10
    @@ syscall
    @@ label "atoi_end"
    @@ move v0 t1
    @@ jr   ra


    let generate_prog p =
      let asm = Symb_Tbl.fold (fun i info acc ->
          acc @@ (label i) @@ (generate_fun info) ) p nop in

      { text = init @@ close @@ asm @@ built_ins; data = nop }
