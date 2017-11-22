(* Transformation de la syntaxe abstraite non typée
   vers la syntaxe abstraite "goto". *)
module S = UntypedAst
module T = GotoAst

let destructure_main p =

  (* new_label: unit -> string *)
  (* Un appel [new_label()] crée une nouvelle étiquette qui peut être
     utilisée pour créer des sauts. *)
  let new_label =
    let cpt = ref 0 in
    fun () -> incr cpt; Printf.sprintf "_label_main_%i" !cpt
  in

  (* destructure_block: S.block -> T.block *)
  let rec destructure_block = function
    | []     -> []
    | i :: b -> destructure_instruction i @ (destructure_block b)

  (* destructure_instruction: S.instruction -> T.block *)
  and destructure_instruction : S.instruction -> T.block = function
    | Set(l, e)     -> [ T.Set(l, e) ]
    | Print(e)      -> [ T.Print(e)  ]

    | SetArray(loc, l) -> (*failwith "NYI" *)
      let rec f l instr i =
        match l with
          | [] -> instr
          | t :: s ->
            let loc = SourceAst.ArrayAccess(Location(loc), Literal(Int(i))) in
            let new_instr = [ T.Set(loc, Literal(Int(t))) ] in
            ( f s (new_instr@instr) (i+1) )
      in
          f l [] 0




    | While(e, b)   -> let body_label = new_label() in
		       let test_label = new_label() in
		       [ T.Comment("While")             ]
		       @ [ T.Goto test_label            ]
		       @ [ T.Label body_label           ]
		       @ [ T.Comment("Corps de boucle") ]
		       @ (destructure_block b)
		       @ [ T.Label test_label           ]
		       @ [ T.Comment("Test de boucle")  ]
		       @ [ T.CondGoto(e, body_label)    ]
		       @ [ T.Comment("Fin boucle")      ]

    | If(e, b1, b2) -> let then_label = new_label() in
		       let end_label = new_label() in
		       [ T.Comment("If")             ]
		       @ [ T.CondGoto(e, then_label) ]
		       @ [ T.Comment("Bloc else")    ]
		       @ (destructure_block b2)
		       @ [ T.Goto end_label          ]
		       @ [ T.Label then_label        ]
		       @ [ T.Comment("Bloc then")    ]
		       @ (destructure_block b1)
		       @ [ T.Label end_label         ]
		       @ [ T.Comment("Fin if")       ]

  in

  { T.locals = p.S.locals; T.code = destructure_block p.S.code }
