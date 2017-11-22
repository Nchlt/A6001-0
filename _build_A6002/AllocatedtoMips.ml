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
    | New(dest, value)  ->
      let i = match find_alloc dest with
        | Reg r   -> failwith "AllocatedToMips 83 : Reg alloc NYI"
        | Stack o -> sw v0 o ~$fp
          (* On  met la taille du tableau dans l'en tête *)
      in
      li ~$v0 9             @@ (*9 pour sbrk*)
      li ~$t1 4             @@
      load_value a0 value   @@
      mul a0 a0 t1          @@
      addi a0 a0 4          @@
      addi t0 a0 0          @@ (* on veut allouer (4 + 4 * taille) octets  *)
      syscall               @@
      sw t0 0 v0            @@
      i

      (* Remarque : pour l'instant, on stocke les booléens sur 4 octets comme les
      entiers même si on pourrait faire mieux *)

    | Load(dest, access) ->
       let dada = match find_alloc dest with
        | Reg r   -> failwith "AllocatedToMips 102 : Reg alloc NYI"
        | Stack o -> sw t0 o fp
      in
      let array_addr , i = access in

      li t0 4         @@
      load_value t1 i @@
      mul t0 t0 t1    @@
      addi t0 t0 4    @@

      (* Vérification pour l'extension 3.1: on saute à la fin de programme si on est en dehors
      des bornes du tableau. *)
      blez t0 "atoi_error"      @@ (* on ne veut pas d'index négatifs *)
      load_value t1 array_addr  @@
      lw t1 0 t1                @@ (* On récupère la taille du tableau *)
      blt t1 t0 "atoi_error"    @@    (* Si la "range" du tableau est plus petite que
      l'adresse dans le tableau alors on arrête *)

      load_value t1 array_addr@@
      add t0 t0 t1 @@ (* à ce moment, t0 contient offset de l'addresse de t[i] *)
      lw t0 0 t0      @@
      dada



    | Store(access, value) ->
      let array_addr, i = access in (* ce sont des values *)
      load_value t0 i @@
      li t1 4         @@
      mul t0 t0 t1    @@
      addi t0 t0 4    @@ (* t0 contient maintenant l'adresse t[i] dans laquelle on
      veut écrire offset par rapport à l'adresse de début du tableau*)


      (* Vérification pour l'extension 3.1: on saute à la fin de programme si on est en dehors
      des bornes du tableau. *)
      blez t0 "atoi_error"      @@ (* on ne veut pas d'index négatifs *)
      load_value t1 array_addr  @@
      lw t1 0 t1                @@ (* On récupère la taille du tableau *)
      blt t1 t0 "atoi_error"    @@    (* Si la "range" du tableau est plus petite que
      l'adresse dans le tableau alors on arrête *)


      load_value t1 array_addr  @@
      add t0 t0 t1              @@ (*L'adresse on on veut store*)
      load_value t1 value       @@
      sw t1 0 t0


  in

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
  in

  let asm = generate_block p.code in
  { text = init @@ asm @@ close @@ built_ins; data = Nop }
