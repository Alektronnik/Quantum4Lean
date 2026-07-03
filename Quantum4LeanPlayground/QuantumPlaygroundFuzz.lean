/-
QuantumPlaygroundFuzz.lean
Fuzzer Diofantino: tests automaticos para el solver via polyToIsing.

Genera ecuaciones aleatorias con soluciones conocidas y verifica
que bruteForceSolve las encuentra (coste = 0).

Dependencias: Quantum4Lean (Polynomial, Diophantine).
Build autocontenido. Lean 4.7.0.
-/

import Quantum4Lean

open Quantum4Lean

namespace Quantum4LeanPlayground.Fuzz

-- ===================================================================
-- Utilidades
-- ===================================================================

private def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

private def decodeState (varBits : List Nat) (state : Nat) : List Int :=
  let offsets : List Nat :=
    let rec go (acc : Nat) : List Nat -> List Nat
      | [] => []
      | b :: bs => acc :: go (acc + b) bs
    go 0 varBits
  List.mapIdx (fun i (bits : Nat) =>
    let start := offsets.get! i
    (List.range bits).foldl (fun (acc : Nat) (j : Nat) =>
      if ((state >>> (start + j)) &&& 1) == 1 then acc + (1 <<< j) else acc
    ) 0
  ) varBits

/-- Evalua coste: C(vals) = (polinomio - c)^2. --/
def evalCost (eq : PolyEquation) (vals : List Int) : Float :=
  let c := intToFloat eq.constant
  let evalMonom (m : Monomial) : Float :=
    let prod := m.exponents.foldl (fun (acc : Float) ((vi, e) : Nat × Nat) =>
      let v := vals.get! vi
      let vf := intToFloat v
      let p := if e == 0 then 1.0 else if e == 1 then vf
               else if e == 2 then vf*vf else vf*vf*vf
      acc * p
    ) 1.0
    intToFloat m.coefficient * prod
  let polyVal := eq.monomials.foldl (fun acc m => acc + evalMonom m) 0.0
  let diff := polyVal - c
  diff * diff

/-- Busqueda exhaustiva. --/
def bruteForceSolve (eq : PolyEquation) : List (List Int × Float) :=
  let totalQubits := eq.varBits.foldl (fun acc b => acc + b) 0
  let dim := 1 <<< totalQubits
  let allResults : List (Nat × Float) := (List.range dim).map fun state =>
    let vals := decodeState eq.varBits state
    (state, evalCost eq vals)
  let minEnergy := allResults.foldl (fun best ((_, e) : Nat × Float) =>
    if e < best then e else best
  ) 1e30
  let solutions := allResults.filter fun (_, e) => (e - minEnergy).abs < 1e-6
  solutions.map fun (state, e) => (decodeState eq.varBits state, e)

-- ===================================================================
-- Generador de ecuaciones con soluciones conocidas
-- ===================================================================

/-- Semilla LCG simple (misma que el motor). --/
private def lcgNext (seed : Nat) : Nat :=
  seed * 6364136223846793005 + 1442695040888963407

/-- Genera un entero pseudoaleatorio en [0, max). --/
private def randInt (seed : Nat) (max : Nat) : Int × Nat :=
  let s' := lcgNext seed
  ((s' % max).toNat, s')

/-- Genera una ecuacion aleatoria con solucion conocida. --/
def generateWithSolution (numVars : Nat) (maxBits : Nat) (seed : Nat)
    : PolyEquation × List Int × Nat :=
  -- Generar bits por variable
  let (varBits, s1) := (List.range numVars).foldl
    (fun ((bs, s) : List Nat × Nat) _ =>
      let (b, s') := randInt s (maxBits - 1)
      (bs ++ [b + 1], s')
    ) ([], seed)
  -- Generar solucion conocida (valores aleatorios dentro del rango)
  let (solution, s2) := varBits.foldl
    (fun ((vs, s) : List Int × Nat) (bits : Nat) =>
      let maxVal := 1 <<< bits
      let (v, s') := randInt s maxVal
      (vs ++ [v], s')
    ) ([], s1)
  -- Generar 1-2 monomios con exponentes aleatorios
  let (ms, s3) := (List.range 2).foldl
    (fun ((monoms, s) : List Monomial × Nat) _ =>
      let (coeffSign, s1') := randInt s 3
      let coeff := if coeffSign == 0 then 1 else if coeffSign == 1 then -1 else 2
      let (numTerms, s2') := randInt s1' (numVars.toNat)
      let numTerms' := if numTerms == 0 then 1 else numTerms.toNat
      let (exps, s3') := (List.range numTerms').foldl
        (fun ((es, si) : List (Nat × Nat) × Nat) _ =>
          let (vi, si1) := randInt si (numVars.toNat)
          let (exp, si2) := randInt si1 3  -- 0,1,2
          let exp' := if exp == 0 then 1 else exp.toNat  -- evitar exp=0
          ((vi.toNat, exp') :: es, si2)
        ) ([], s2')
      ({ coefficient := coeff, exponents := exps } :: monoms, s3')
    ) ([], s2)
  -- Calcular constante para que la solucion sea exacta
  let c := solution.foldl (fun (acc : Int) (v : Int) => acc) 0
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

-- ===================================================================
-- Fuzzer
-- ===================================================================

structure FuzzResult where
  testName   : String
  passed     : Bool
  equation   : PolyEquation
  solution   : List Int
  found      : List (List Int × Float)
  deriving Repr

/-- Ejecuta un test: verifica que la solucion conocida tiene coste 0. --/
def runSingleTest (testName : String) (eq : PolyEquation) (expected : List Int)
    : FuzzResult :=
  let solutions := bruteForceSolve eq
  let exact := solutions.filter fun (_, e) => e < 1e-6
  let foundExpected := exact.any fun (vals, _) =>
    vals.length == expected.length &&
    (List.range vals.length).all fun i =>
      vals.get! i == expected.get! i
  { testName := testName
  , passed := foundExpected
  , equation := eq
  , solution := expected
  , found := exact
  }

/-- Ejecuta N tests aleatorios. --/
def runFuzz (numTests : Nat := 50) (maxVars : Nat := 3) (maxBits : Nat := 4)
    (baseSeed : Nat := 42) : List FuzzResult :=
  let (results, _) := (List.range numTests).foldl
    (fun ((rs : List FuzzResult), (s : Nat)) (i : Nat) =>
      let name := s!"test_{i}"
      let (eq, sol, s') := generateWithSolution maxVars maxBits s
      let result := runSingleTest name eq sol
      (rs ++ [result], s')
    ) ([], baseSeed)
  results

/-- Reporte del fuzzer. --/
def report : String :=
  let results := runFuzz 50
  let passed := results.filter fun r => r.passed
  let failed := results.filter fun r => !r.passed
  s!"Fuzzer Diofantino\n" ++
  s!"=================\n" ++
  s!"Tests: {results.length} | Pasados: {passed.length} | Fallados: {failed.length}\n\n" ++
  (if failed.isEmpty then "Todos los tests pasaron.\n"
   else "Fallos:\n" ++ String.intercalate "\n" (failed.map fun r =>
     s!"  {r.testName}: esperado={r.solution}, encontrado={r.found.length} soluciones"))

end Quantum4LeanPlayground.Fuzz
