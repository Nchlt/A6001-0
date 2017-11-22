(* Transformation de la syntaxe abstraite non typée
   vers la syntaxe abstraite "goto". *)
module S = UntypedAst
module T = GotoAst

let cpt = ref 0
let destructure_main p =

  (* new_label: unit -> string *)
  (* Un appel [new_label()] crée une nouvelle étiquette qui peut être
     utilisée pour créer des sauts. *)
  let new_label =
    fun () -> incr cpt; Printf.sprintf "_label_%i" !cpt
  in

  (* destructure_block: S.block -> T.block *)
  let rec destructure_block = function
    | []     -> []
    | i :: b -> destructure_instruction i @ (destructure_block b)

  (* destructure_instruction: S.instruction -> T.block *)
  and destructure_instruction : S.instruction -> T.block = function
    | ProcCall(call) -> [ T.Procall(call)]
    | Set(l, e)     -> [ T.Set(l, e) ]
    | Print(e)      -> [ T.Print(e)  ]

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

  { T.locals = p.S.locals; T.code = destructure_block p.S.code;
    T.formals = p.S.formals; T.return = p.S.return }

    let destructure_program p =
      S.Symb_Tbl.fold (fun i info acc ->
          T.Symb_Tbl.add i (destructure_func info) acc )
        p T.Symb_Tbl.empty
