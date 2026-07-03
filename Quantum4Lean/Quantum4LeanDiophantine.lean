/-
Quantum4LeanDiophantine.lean
Traductor: ecuaciones diofantinas lineales -> Ising Hamiltonians.

Dada ax + by = c, con x,y representados en b bits cada uno:
  x = Σ 2^j q_j,  q_j = (I - Z_j)/2
  Coste = (ax + by - c)² = Σ terminos de Pauli Z

Resoluble via QAOA nativo de Quantum4Lean.

Compatible: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanEngine
import Quantum4Lean.Quantum4LeanObservable
import Quantum4Lean.Quantum4LeanQAOA

namespace Quantum4Lean

structure DiophantineVar where
  coeff : Int
  name  : String
  bits  : Nat
  deriving Repr

structure Diophantine where
  vars     : List DiophantineVar
  constant : Int
  deriving Repr

structure DiophantineResult where
  values    : List (String × Int)
  energy    : Float
  satisfied : Bool
  deriving Repr

private def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

private def pow2 (n : Nat) : Float :=
  match n with
  | 0 => 1.0
  | n+1 => 2.0 * pow2 n

private def listGet (xs : List α) (i : Nat) (d : α) : α := xs[i]? |>.getD d

private def listMapIdx {α β : Type} (f : Nat -> α -> β) : List α -> List β :=
  let rec go (i : Nat) : List α -> List β
    | [] => []
    | y :: ys => f i y :: go (i + 1) ys
  go 0

/--
Convierte una variable diofantina x (con b bits) a lista de PauliStrings.
x = sum_j 2^j * (1 - Z_j)/2 = sum_j (2^j/2 * I - 2^j/2 * Z_j)
-/
private def varToPauli (bits : Nat) (startQ : Nat) : List PauliString :=
  let idTerm : PauliString := { coefficient := 0.0, terms := [] }
  (List.range bits).foldl (fun (acc : List PauliString) (j : Nat) =>
    let coeff := pow2 j / 2.0
    let identPiece : PauliString := { coefficient := coeff, terms := [] }
    let zPiece : PauliString :=
      { coefficient := -coeff, terms := [PauliTerm.mk .Z (startQ + j)] }
    identPiece :: zPiece :: acc
  ) []

/--
Multiplica dos PauliStrings (producto tensorial, simplifica fases).
Copia de pauliStringMul de Chemistry para evitar dependencia circular.
-/
private def psMul (a b : PauliString) : PauliString :=
  let combined := a.terms ++ b.terms
  -- Simplificar: fusionar qubits iguales
  let rec simplify (ts : List PauliTerm) : Float × List PauliTerm :=
    match ts with
    | [] => (1.0, [])
    | [t] => (1.0, [t])
    | t1 :: t2 :: rest =>
      if t1.qubit == t2.qubit then
        match t1.pauli, t2.pauli with
        | .X, .X => simplify rest
        | .Y, .Y => simplify rest
        | .Z, .Z => simplify ({ pauli := .I, qubit := t1.qubit } :: rest)
        | .X, .Y => simplify ({ pauli := .Z, qubit := t1.qubit } :: rest)
        | .Y, .X => simplify ({ pauli := .Z, qubit := t1.qubit } :: rest)
        | .X, .Z => simplify ({ pauli := .Y, qubit := t1.qubit } :: rest)
        | .Z, .X => simplify ({ pauli := .Y, qubit := t1.qubit } :: rest)
        | .Y, .Z => simplify ({ pauli := .X, qubit := t1.qubit } :: rest)
        | .Z, .Y => simplify ({ pauli := .X, qubit := t1.qubit } :: rest)
        | _, _ => let (c, rest') := simplify (t2 :: rest); (c, t1 :: rest')
      else
        let (c, rest') := simplify (t2 :: rest); (c, t1 :: rest')
    termination_by ts.length
  let (phase, simplified) := simplify combined
  { coefficient := a.coefficient * b.coefficient * phase
  , terms := simplified.filter fun t => t.pauli ≠ .I }

/--
Convierte ecuacion diofantina lineal a Observable via
multiplicacion explicita de PauliStrings (sin derivacion analitica).

Cost = (sum a_i x_i - c)^2
     = sum_{i,k} a_i a_k x_i x_k - 2c sum_i a_i x_i + c^2

Cada x_i se expande en PauliStrings via varToPauli.
Luego se multiplican explicitamente.
-/
def toIsing (eq : Diophantine) (bitsPerVar : Nat := 4) : Observable :=
  let vars := eq.vars
  let nVars := vars.length
  let c := intToFloat eq.constant
  let qIdx (i : Nat) : Nat := i * bitsPerVar
  -- Expandir cada variable
  let varExpanded : List (List PauliString) :=
    (List.range nVars).map fun i =>
      let v := listGet vars i { coeff := 0, name := "", bits := 0 }
      let a := intToFloat v.coeff
      varToPauli v.bits (qIdx i) |>.map fun ps =>
        { ps with coefficient := a * ps.coefficient }
  -- Construir Σ a_i x_i como Observable
  let linearExpr : List PauliString :=
    listBind (List.range nVars) fun i =>
      let expanded := listGet varExpanded i []
      expanded.map fun ps => { ps with coefficient := ps.coefficient }
  -- Construir (Σ a_i x_i)² via multiplicacion explicita
  let quadExpr : List PauliString :=
    listBind linearExpr fun psA =>
      linearExpr.map fun psB => psMul psA psB
  -- Construir -2c Σ a_i x_i
  let crossC : List PauliString :=
    linearExpr.map fun ps =>
      { ps with coefficient := -2.0 * c * ps.coefficient }
  -- Agregar constante c² como termino identidad
  let constTerm : List PauliString :=
    [{ coefficient := c * c, terms := [] }]
  let allStrings := constTerm ++ crossC ++ quadExpr
  -- Combinar terminos con mismos qubits (fusionar coeficientes)
  { strings := allStrings }

/--
Coste de una asignacion de variables: (sum a_i * val_i - c)^2.
-/
def diophantineCost (eq : Diophantine) (vals : List Int) : Float :=
  let sum := (List.zip eq.vars vals).foldl (fun (acc : Int) ((v, val) : DiophantineVar × Int) =>
    acc + v.coeff * val
  ) 0
  let diff : Int := sum - eq.constant
  let df : Float := if diff >= 0 then diff.toNat.toFloat else -(((-diff).toNat.toFloat))
  df * df

/--
Busqueda exhaustiva sobre el espacio de variables diofantinas.
Coste: O(2^(nVars * bitsPerVar)).
-/
def diophantineBruteForce (eq : Diophantine) (tolerance : Float := 1e-6)
    : List (List (String × Int) × Float) :=
  let totalBits := eq.vars.foldl (fun acc v => acc + v.bits) 0
  let dim := 1 <<< totalBits
  let offsets : List Nat :=
    let rec offsetGo (acc : Nat) : List DiophantineVar -> List Nat
      | [] => []
      | v :: vs => acc :: offsetGo (acc + v.bits) vs
    offsetGo 0 eq.vars
  let decodeOne (state : Nat) (i : Nat) (v : DiophantineVar) : (String × Int) :=
    let start := offsets[i]!
    let val : Int := (List.range v.bits).foldl (fun (acc : Int) (j : Nat) =>
      if ((state >>> (start + j)) &&& 1) == 1 then acc + ((1 <<< j : Nat) : Int) else acc
    ) 0
    (v.name, val)
  let decodeAll (state : Nat) : List (String × Int) :=
    let rec decodeGo (i : Nat) : List DiophantineVar -> List (String × Int)
      | [] => []
      | v :: vs => decodeOne state i v :: decodeGo (i + 1) vs
    decodeGo 0 eq.vars
  let allResults : List (Nat × Float) := (List.range dim).map fun state =>
    let vals := decodeAll state
    let valsInt := vals.map fun (_, vi) => vi
    (state, diophantineCost eq valsInt)
  let minEnergy := allResults.foldl (fun best ((_, e) : Nat × Float) =>
    if e < best then e else best
  ) 1e30
  let threshold := if minEnergy < tolerance then minEnergy * 10.0 else minEnergy + 1.0
  (allResults.filter fun ((_, e) : Nat × Float) => e <= threshold).map fun (state, e) =>
    (decodeAll state, e)

/--
Resuelve ecuacion diofantina lineal por busqueda exhaustiva.
Usa diophantineBruteForce internamente.
-/
def diophantineSolve (eq : Diophantine) : DiophantineResult :=
  let results := diophantineBruteForce eq
  match results with
  | [] =>
    { values := eq.vars.map fun v => (v.name, 0)
    , energy := 1e30
    , satisfied := false
    }
  | (vals, e) :: _ =>
    { values := vals
    , energy := e
    , satisfied := e < 1e-6
    }

/--
Evalua la energia VQE de una ecuacion diofantina (experimental).
Devuelve DiophantineResult con valores = 0 y satisfied = false.
Usar diophantineSolve para solucion real via busqueda exhaustiva.
-/
def diophantineEnergy (eq : Diophantine) (bitsPerVar : Nat := 4)
    (p : Nat := 1) (lr : Float := 0.05) (iters : Nat := 200) : DiophantineResult :=
  let n := eq.vars.length * bitsPerVar
  let H := toIsing eq bitsPerVar
  -- VQE con el Observable diofantino real (no Ising generico)
  let ansatz (params : List Float) : Circuit n :=
    (qaoaIsingCircuit n p 1.0 0.5) params
  let initialParams := List.replicate (2 * p) 0.1
  let (energy, _, _) := vqe ansatz H initialParams lr iters
  { values := eq.vars.map fun v => (v.name, 0)
  , energy := energy
  , satisfied := false
  }

def checkSolution (eq : Diophantine) (values : List (String × Int)) : Bool :=
  let sum := values.foldl (fun (acc : Int) ((name, val) : String × Int) =>
    match eq.vars.find? fun v => v.name == name with
    | some v => acc + v.coeff * val
    | none => acc
  ) 0
  sum == eq.constant

/-- Decodifica valores desde StateVector (bit mas probable por qubit). --/
def decodeValues (eq : Diophantine) (bitsPerVar : Nat) (sv : StateVector) : List (String × Int) :=
  let probs : Array Float := StateVector.probabilities sv
  let totalDim : Nat := StateVector.dim sv
  let (maxIdx, _) : Nat × Float :=
    (List.range totalDim).foldl
      (fun ((bestIdx, bestProb) : Nat × Float) (idx : Nat) =>
        let p : Float := probs[idx]!
        if p > bestProb then (idx, p) else (bestIdx, bestProb)
      ) (0, 0.0)
  listMapIdx (fun i (v : DiophantineVar) =>
    let startQ := i * bitsPerVar
    let val : Int := (List.range v.bits).foldl (fun (acc : Int) (j : Nat) =>
      let bitVal : Nat := (maxIdx >>> (startQ + j)) &&& 1
      if bitVal == 1 then acc + ((1 <<< j : Nat) : Int) else acc
    ) 0
    (v.name, val)
  ) eq.vars

end Quantum4Lean
