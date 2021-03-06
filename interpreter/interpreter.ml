exception Eval_error
exception Type_error
exception Substitution_error

type typ =
    | TBool
    | TInt
    | TArrow of typ * typ

type type_environment = (string * typ) list

type exp = 
    | True
    | False
    | If of exp * exp * exp
    | Num of int
    | IsZero of exp
    | Plus of exp * exp
    | Mult of exp * exp
    | Var of string
    | Lambda of string * typ * exp
    | Apply of exp * exp
    | LambdaRec of string * typ * typ * string * exp
    | Div of exp * exp
    | Try of exp * exp
    | RaiseDivByZero of typ * exp


let rec find e l = match l with
    | [] -> false
    | a :: rest -> (a = e) || (find e rest)

let rec union l1 l2 = match l1 with
    | [] -> l2
    | a :: rest -> if (find a l2) then (union rest l2) else (union rest (a::l2))

let rec remove e l = match l with
    | [] -> []
    | a :: rest -> if a = e then remove e rest else a :: (remove e rest)

(* 
returns a list of strings, which are the names of the variables that are
free in e. free_variables must be implemented according to the function
definition that we have seen in class.
*)
let rec free_variables (e : exp) = match e with
    | Num(n) -> []
    | True -> []
    | False -> []
    | If(e1, e2, e3) -> (union (union (free_variables e1) (free_variables e2)) (free_variables e3))
    | IsZero(e) -> free_variables(e)
    | Plus(e1, e2) -> union (free_variables e1) (free_variables e2)
    | Mult(e1, e2) -> union (free_variables e1) (free_variables e2)
    | Var(s) -> [Var(s)]
    | Lambda(var, typ, body) -> (remove (Var var) (free_variables body))
    | Apply(func, v) -> (free_variables func)
    | LambdaRec(name, t1, t2, var, body) -> (remove (Var var) (remove (Var name) (free_variables body)))
    | Div(e1, e2) -> union (free_variables e1) (free_variables e2)
    | Try(e1, e2) -> union (free_variables e1) (free_variables e2)
    | RaiseDivByZero(typ, e1) -> (free_variables e1)


let not x = match x with
    | true -> false
    | false -> true

(* 
(substitution e1 "x" e2) replaces all the free occurances of "x" in the
expression e1 with e2, according to the substitution algoritm that
we have seen in class.
The function substitution raises the exception Substitution_error for
the case of variable capture that we have seen in class

x[e/x] = e
y[e/x] = y   if y is different from x
(e1 + e2)[e/x] = (e1[e/x] + e2[e/x])
... all other cases ... (3/9 lecture?)
*)
let rec substitution (e1 : exp) (x : string) (e2 : exp) = match e1 with
    | Var(var) -> if var = x then e2 else Var(var)
    | True -> True
    | False -> False
    | If(ife1, ife2, ife3) -> If((substitution ife1 x e2), (substitution ife2 x e2), (substitution ife3  x  e2))
    | Num(n) -> Num(n)
    | IsZero(ze1) -> IsZero (substitution ze1 x e2)
    | Plus(pe1, pe2) -> Plus(substitution pe1 x e2, substitution pe2 x e2)
    | Mult(pe1, pe2) -> Mult(substitution pe1 x e2, substitution pe2 x e2)
    | Lambda(var, typ, body) -> if ( (var = x) || (find (Var(var)) (free_variables e2)) ) then Lambda(var, typ, body) else Lambda(var, typ, (substitution body x e2))
    | Apply(ae1, ae2) -> Apply((substitution ae1 x e2), (substitution ae2 x e2))
    | LambdaRec(name, t1, t2, var, body) -> if ( (var = x) || (name = x) ) then (
            LambdaRec(name, t1, t2, var, body) 
        ) else (
            if ( (var != x) && (name != x) ) then (
                if ((not (find (Var(var)) (free_variables e2))) && (not (find (Var(name)) (free_variables e2))) ) then (
                    LambdaRec(name, t1, t2, var, (substitution body x e2))
                ) else (
                    raise Substitution_error
                )
            ) else (
                raise Substitution_error
        )
    )
    | Div(de1, de2) -> Div(substitution de1 x e2, substitution de2 x e2)
    | Try(te1, te2) -> Try(substitution te1 x e2, substitution te2 x e2)
    | RaiseDivByZero(typ, re1) -> RaiseDivByZero(typ, substitution re1 x e2)

(* 
The function type_check takes in input an expression and returns the
type of that expression according to the type system that we have seen
in class, or the function raises the OCaml exception Type_error when
type checking fails

add cases for variables, functions, and applications
*)
let rec type_check (te : type_environment) (e : exp) = match e with
    | True -> TBool
    | False -> TBool
    | Num(n) -> TInt
    | If(e1, e2, e3) -> (
        match (type_check te e1) with
        | TBool -> (
            match (type_check te e2) with
            | TBool -> (
                match (type_check te e3) with
                | TBool -> TBool
                | otherwise -> raise Type_error
            )
            | TInt -> (
                match (type_check te e3) with
                | TInt -> TInt
                | otherwise -> raise Type_error
            )
            | TArrow(t1a,t2a) -> (
                match (type_check te e3) with
                | TArrow(t1b,t2b) -> if ((t1a = t1b)&&(t2a = t2b)) then TArrow(t1a,t2a) else raise Type_error
                | otherwise -> raise Type_error
            )
        )
        | otherwise -> raise Type_error
    )
    | IsZero(e1) -> (
        match (type_check te e1) with
        | TInt -> TBool
        | otherwise -> raise Type_error
    )
    | Plus(e1, e2) -> (
        match (type_check te e1) with
        | TInt -> (
            match (type_check te e2) with
            | TInt -> TInt
            | otherwise -> raise Type_error
        )
        | otherwise -> raise Type_error
    )
    | Mult(e1, e2) -> (
        match (type_check te e1) with
        | TInt -> (
            match (type_check te e2) with
            | TInt -> TInt
            | otherwise -> raise Type_error
        )
        | otherwise -> raise Type_error
    )
    | Var(x) -> (
        match te with
        | [] -> raise Type_error
        | a :: rest -> if (fst a) = x then (snd a) else (type_check rest (Var(x)))
    )
    | Apply(e1, e2) -> (
        match (type_check te e1) with
        | TArrow(t1, t2) -> if ((type_check te e2) = t1) then t2 else raise Type_error
        | otherwise -> raise Type_error
    )
    | Lambda(var, typ, body) -> TArrow(typ, (type_check ((var, typ)::te) body))
    (* 
    Notes from Mar 18 Class
    -- -- -- -- -- -- -- --

    Gamma, x : T1 |- e : T2
    -----------------------
    Gamma |- \lambda x: T1.e : T1 --> T2

    let rec type_check (te : type_environment) e = match e with
        | IsZero(e) -> ... type_check(te, e) ...
        | Lambda(varname, t, e) -> type_check((varname,t)::te, e)
        | Var(varname) -> lookup in te for varname and if its not there then you raise Type_error
     *)
     | LambdaRec(f, t1, t2, x, body) -> (
        if ((type_check (((f,(TArrow(t1,t2)))::(x,t1)::te)) body) = t2) then (TArrow(t1,t2)) else (raise Type_error)
     )
     | Div(e1, e2) -> (
        match (type_check te e1) with
        | TInt -> (
            match (type_check te e2) with
            | TInt -> TInt
            | otherwise -> raise Type_error
        )
        | otherwise -> raise Type_error
    )
     | Try(e1, e2) -> if TArrow(TInt, (type_check te e1)) = (type_check te e2) then (type_check te e1) else raise Type_error
     | RaiseDivByZero(typ, n) -> typ

(*
The function step takes in input an
expression and returns the expression that
results from computing one step of the expression
in input, or raises OCaml exception Eval_error if
the computation fails
*)
let rec step (e : exp) = match e with
    | If(e1, e2, e3) -> (
        match e1 with
        | True -> e2
        | False -> e3
        | Num(n) -> raise Eval_error
        | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
        | otherwise -> If(step(e1), e2, e3))
    | IsZero(e) ->  (
        match e with
        | Num(n) -> if (n = 0) then True else False
        | True -> raise Eval_error
        | False -> raise Eval_error
        | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
        | otherwise -> IsZero(step(e)))
    | Plus(e1, e2) -> (
        match e1 with
        | Num(n1) -> (
            match e2 with
            | Num(n2) -> Num(n1+n2)
            | True -> raise Eval_error
            | False -> raise Eval_error
            | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
            | otherwise -> Plus(e1, step(e2)))
        | True -> raise Eval_error
        | False -> raise Eval_error
        | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
        | otherwise -> Plus(step(e1), e2))
    | Mult(e1, e2) -> (
        match e1 with
        | Num(n1) -> (
            match e2 with
            | Num(n2) -> Num(n1*n2)
            | True -> raise Eval_error
            | False -> raise Eval_error
            | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
            | otherwise -> Mult(e1, step(e2)))
        | True -> raise Eval_error
        | False -> raise Eval_error
        | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
        | otherwise -> Mult(step(e1), e2))
    | Apply(func, arg) -> (
        match func with
        | Lambda(var, typ, body) -> (
            match arg with
            | Num(n) -> (substitution body var arg)
            | True -> (substitution body var arg)
            | False -> (substitution body var arg)
            | Lambda(v,t,b) -> (substitution body var (Lambda(v,t,b)))
            | LambdaRec(name, t1, t2, var, body) -> (substitution body var arg)
            | Var(x) -> raise Eval_error
            | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
            | notValue -> Apply(func, step arg))
        | LambdaRec(name, t1, t2, var, body) -> (
            match arg with
            | Num(n) -> (substitution (substitution body var arg) name (LambdaRec(name, t1, t2, var, body)))
            | True -> (substitution (substitution body var arg) name (LambdaRec(name, t1, t2, var, body)))
            | False -> (substitution (substitution body var arg) name (LambdaRec(name, t1, t2, var, body)))
            | Lambda(v,t,b) -> (substitution (substitution body var arg) name (LambdaRec(name, t1, t2, var, body)))
            | LambdaRec(name, t1, t2, var, body) -> (substitution (substitution body var arg) name (LambdaRec(name, t1, t2, var, body)))
            | Var(x) -> raise Eval_error
            | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
            | notValue -> Apply(func, step arg))
        | Var(x) -> raise Eval_error
        | Num(n) -> raise Eval_error
        | True -> raise Eval_error
        | False -> raise Eval_error
        | RaiseDivByZero(typ, n) -> RaiseDivByZero(typ, n)
        | notLambda -> Apply(step func, arg))
    | Div(e1, e2) -> (
        match e1 with
        | Num(n1) -> (
            match e2 with
            | Num(n2) -> if e2 = Num(0) then RaiseDivByZero(TInt, e1) else Num(n1/n2)
            | True -> raise Eval_error
            | False -> raise Eval_error
            | otherwise -> Div(e1, step e2)
        )
        | True -> raise Eval_error
        | False -> raise Eval_error
        | otherwise -> Div(step e1, e2)
    )
    | Try(e1, e2) -> (
        match e1 with
        | RaiseDivByZero(typ, v) -> Apply(e2, v)
        | Div(a,b) -> Try(step e1, e2)
        | Mult(a,b) -> Try(step e1, e2)
        | Plus(a,b) -> Try(step e1, e2)
        | IsZero(a) -> Try(step e1, e2)
        | If(a,b,c) -> Try(step e1, e2)
        | Apply(a,b)-> Try(step e1, e2)
        | value -> e1
    )
    (* | otherwise -> raise Eval_error *)


(*
The function multi_step takes in input an
expression and iterates the function step in order
to evaluate the expression one step at a time until
it returns a value, or raises OCaml exception Eval_error
if the computation fails
*)
let rec multi_step (e : exp) = match e with
    | True -> True
    | False -> False
    | If(e1, e2, e3) -> multi_step(step(If(e1,e2,e3)))
    | Num(n) -> Num(n)
    | Var(x) -> Var(x)
    | IsZero(e) -> multi_step(step(IsZero(e)))
    | Plus(e1, e2) -> multi_step(step(Plus(e1, e2)))
    | Mult(e1, e2) -> multi_step(step(Mult(e1, e2)))
    | Apply(e1, e2) -> multi_step(step(Apply(e1, e2)))
    | Lambda(var, typ, body) -> Lambda(var, typ, body)
    | LambdaRec(name, t1, t2, var, body) -> LambdaRec(name, t1, t2, var, body)
    | Div(e1, e2) -> multi_step(step e)
    | Try(e1, e2) -> multi_step(step e)
    | RaiseDivByZero(typ, e1) -> RaiseDivByZero(typ, multi_step e1)
    

let rec string_of_typ (t : typ) = match t with
    | TBool -> "bool"
    | TInt -> "int"
    | TArrow(t1, t2) -> "(" ^ (string_of_typ t1) ^ " -> " ^ (string_of_typ t2) ^ ")"

(* Brought in from interpreter_bigstep for testing *)
let rec string_of_exp (e : exp) = match e with
    | True -> "true"
    | False -> "false"
    | If(e1, e2, e3) -> "if " ^ (string_of_exp e1) ^ " then " ^ (string_of_exp e2) ^ " else " ^ (string_of_exp e3)
    | Num(n) -> string_of_int(n)
    | IsZero(e) -> "(isZero " ^ (string_of_exp e) ^ ")"
    | Plus(e1, e2) -> "(" ^ (string_of_exp e1) ^ " + " ^ (string_of_exp e2) ^ ")"
    | Mult(e1, e2) -> "(" ^ (string_of_exp e1) ^ " * " ^ (string_of_exp e2) ^ ")"
    | Var(x) -> x
    | Lambda(var, typ, e) -> "(lambda " ^ var ^ ":" ^ (string_of_typ typ) ^ "." ^ (string_of_exp e) ^ ")"
    | Apply(e1, e2) -> "(" ^ (string_of_exp e1) ^ ", " ^ (string_of_exp e2) ^ ")"
    | LambdaRec(name, t1, t2, var, body) -> "(LambdaRec (" ^ name ^ " : " ^ (string_of_typ t1) ^ " -> " ^ (string_of_typ t2) ^ ") " ^ var ^ " = " ^ (string_of_exp body) ^ ")"
    | Div(e1, e2) -> "(" ^ (string_of_exp e1) ^ " / " ^ (string_of_exp e2) ^ ")"
    | Try(e1, e2) -> "try (" ^ (string_of_exp e1) ^ ") with (" ^ (string_of_exp e2) ^ ")"
    | RaiseDivByZero(typ, e1) -> "RaiseDivByZero (" ^ (string_of_typ typ) ^ ", " ^ (string_of_exp e1) ^")"
    
let () =
    (* EXCEPTIONS *)
    (print_endline "\n1-3\n");
    (* 1-3 *)

    (print_endline (string_of_exp ((multi_step (RaiseDivByZero (TInt, Plus (Num 4, Num 2)))))));
    (print_endline (string_of_exp ((multi_step (Div (Plus (Num 4, Num 2), Num 0))))));
    (print_endline (string_of_exp ((multi_step (Try (Plus (Num 4, Num 4), Lambda ("x", TInt, Var "x"))))
)));

   
    (print_endline "\n4-6\n");
    (* 4-6 *)

    (print_endline (string_of_exp ((multi_step
   (Try (Div (Num 4, Num 0), Lambda ("x", TInt, Plus (Var "x", Num 1))))))));
    (print_endline (string_of_exp ((multi_step (Apply (Lambda ("x", TInt, Var "x"), Div (Num 4, Num 0)))))));
    (print_endline (string_of_exp ((multi_step (If (IsZero (Div (Num 4, Num 0)), Num 1, Num 2))))));

    (print_endline "\n7-9\n");
    (* 7-9 *)

    (print_endline (string_of_typ ((type_check [] (RaiseDivByZero (TInt, Plus (Num 4, Num 2)))))));
    (print_endline (string_of_typ ((type_check []
   (Try (Div (Num 4, Num 0), Lambda ("x", TInt, Plus (Var "x", Num 1))))))));
    (print_endline (string_of_typ ((type_check []
   (If (IsZero (Num 0), RaiseDivByZero (TBool, Num 4), False)))
)));

    (print_endline "\n10-11\n");
    (* 10-11 *)

    (* (print_endline (string_of_typ ((type_check []
   (Try (Div (Num 4, Num 0), Lambda ("x", TBool, Plus (Var "x", Num 1)))))))); *)
    (* (print_endline (string_of_typ ((type_check []
   (Try (Div (Num 4, Num 0), Lambda ("x", TInt, False))))))); *)

 