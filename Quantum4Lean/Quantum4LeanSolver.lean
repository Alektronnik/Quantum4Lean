/-
Quantum4LeanSolver.lean
Utilidades compartidas: decode, eval, brute force search.
Usado por Diophantine, Polynomial, y Playgrounds.
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanObservable
import Quantum4Lean.Quantum4LeanPolynomial

open Quantum4Lean

namespace Quantum4Lean

def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

def decodeState (varBits : List Nat) (state : Nat) : List Int :=
  let offsets : List Nat :=
    let rec offsetGo (acc : Nat) : List Nat -> List Nat
      | [] => []
      | b :: bs => acc :: offsetGo (acc + b) bs
    offsetGo 0 varBits
  let rec valueGo (i : Nat) : List Nat -> List Int
    | [] => []
    | bits :: rest =>
      let start := offsets.get! i
      let valNat := (List.range bits).foldl (fun (acc : Nat) (j : Nat) =>
        if ((state >>> (start + j)) &&& 1) == 1 then acc + (1 <<< j) else acc
      ) 0
      Int.ofNat valNat :: valueGo (i + 1) rest
  valueGo 0 varBits

def evalCost (eq : PolyEquation) (vals : List Int) : Float :=
  let c := intToFloat eq.constant
  let evalMonom (m : Monomial) : Float :=
    let prod := m.exponents.foldl (fun (acc : Float) ((vi, e) : Nat × Nat) =>
      let v := vals.get! vi
      let vf := intToFloat v
      let p := if e == 0 then 1.0
               else if e == 1 then vf
               else if e == 2 then vf * vf
               else vf * vf * vf
      acc * p
    ) 1.0
    intToFloat m.coefficient * prod
  let polyVal := eq.monomials.foldl (fun acc m => acc + evalMonom m) 0.0
  let diff := polyVal - c
  diff * diff

def bruteForceSolve (eq : PolyEquation) (tolerance : Float := 1e-6)
    : List (List Int × Float) :=
  let totalQubits := eq.varBits.foldl (fun acc b => acc + b) 0
  let dim := 1 <<< totalQubits
  let allResults : List (Nat × Float) := (List.range dim).map fun state =>
    let vals := decodeState eq.varBits state
    (state, evalCost eq vals)
  let minEnergy := allResults.foldl (fun best ((_, e) : Nat × Float) =>
    if e < best then e else best
  ) 1e30
  let solutions := allResults.filter fun (_, e) => (e - minEnergy).abs < tolerance
  solutions.map fun (state, e) =>
    (decodeState eq.varBits state, e)


-- ===================================================================
-- Fuzzer Diofantino
-- ===================================================================

/-- Genera una ecuacion aleatoria con solucion conocida. --/
def generateWithSolution (numVars : Nat) (maxBits : Nat) (seed : Nat)
    : PolyEquation × List Int × Nat :=
  let lcgNext (s : Nat) : Nat := s * 6364136223846793005 + 1442695040888963407
  let randInt (s : Nat) (max : Nat) : Int × Nat :=
    let s' := lcgNext s
    ((s' % max : Nat), s')
  let (varBits, s1) := (List.range numVars).foldl
    (fun ((bs, s) : List Nat × Nat) _ =>
      let (b, s') := randInt s (maxBits - 1)
      (bs ++ [b.toNat + 1], s')
    ) ([], seed)
  let (solution, s2) := varBits.foldl
    (fun ((vs, s) : List Int × Nat) (bits : Nat) =>
      let maxVal := 1 <<< bits
      let (v, s') := randInt s maxVal
      (vs ++ [v], s')
    ) ([], s1)
  let (ms, s3) := (List.range 2).foldl
    (fun ((monoms, s) : List Monomial × Nat) _ =>
      let (coeffSign, s1') := randInt s 3
      let coeff := if coeffSign == 0 then 1 else if coeffSign == 1 then -1 else 2
      let (numTerms, s2') := randInt s1' numVars
      let numTerms' := if numTerms == 0 then 1 else numTerms.toNat
      let (exps, s3') := (List.range numTerms').foldl
        (fun ((es, si) : List (Nat × Nat) × Nat) _ =>
          let (vi, si1) := randInt si numVars
          let (exp, si2) := randInt si1 3
          let exp' := if exp == 0 then 1 else exp.toNat
          ((vi.toNat, exp') :: es, si2)
        ) ([], s2')
      ({ coefficient := coeff, exponents := exps } :: monoms, s3')
    ) ([], s2)
  let polyVal := ms.foldl (fun (acc : Int) (m : Monomial) =>
    let prod := m.exponents.foldl (fun (p : Int) ((vi, e) : Nat × Nat) =>
      let sv := solution.get! vi
      let vp := (List.range e).foldl (fun (pv : Int) _ => pv * sv) 1
      p * vp
    ) 1
    acc + m.coefficient * prod
  ) 0
  let eq : PolyEquation := { monomials := ms, constant := polyVal, varBits := varBits }
  (eq, solution, s3)

structure DiophantineFuzzResult where
  testName   : String
  passed     : Bool
  equation   : PolyEquation
  solution   : List Int
  found      : List (List Int × Float)
  deriving Repr

def runDiophantineFuzz (numTests : Nat := 50) (maxVars : Nat := 3) (maxBits : Nat := 4)
    (baseSeed : Nat := 42) : List DiophantineFuzzResult :=
  let (results, _) := (List.range numTests).foldl
    (fun ((rs : List DiophantineFuzzResult), (s : Nat)) (i : Nat) =>
      let name := s!"test_{i}"
      let (eq, sol, s') := generateWithSolution maxVars maxBits s
      let solutions := bruteForceSolve eq
      let exact := solutions.filter fun (_, e) => e < 1e-6
      let foundExpected := exact.any fun (vals, _) =>
        vals.length == sol.length &&
        (List.range vals.length).all fun i => vals.get! i == sol.get! i
      let result : DiophantineFuzzResult :=
        { testName := name, passed := foundExpected, equation := eq, solution := sol, found := exact }
      (rs ++ [result], s')
    ) ([], baseSeed)
  results

def diophantineFuzzReport : String :=
  let results := runDiophantineFuzz 50
  let passed := results.filter fun r => r.passed
  let failed := results.filter fun r => !r.passed
  s!"Fuzzer Diofantino\n" ++
  s!"=================\n" ++
  s!"Tests: {results.length} | Pasados: {passed.length} | Fallados: {failed.length}\n\n" ++
  (if failed.isEmpty then "Todos los tests pasaron.\n"
   else "Fallos:\n" ++ String.intercalate "\n" (failed.map fun r =>
     s!"  {r.testName}: esperado={r.solution}, encontrado={r.found.length} soluciones"))

end Quantum4Lean
