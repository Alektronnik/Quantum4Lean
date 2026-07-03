/-
QuantumPlaygroundFuzz.lean
Fuzzer Diofantino: tests automaticos via polyToIsing.

Genera ecuaciones aleatorias con soluciones conocidas y verifica
que bruteForceSolve las encuentra.

Dependencias: Quantum4Lean, QuantumPlaygroundCommon.
-/

import Quantum4Lean
import Quantum4Lean

open Quantum4Lean
open Quantum4Lean

namespace Quantum4LeanPlayground.Fuzz

private def lcgNext (seed : Nat) : Nat :=
  seed * 6364136223846793005 + 1442695040888963407

private def randInt (seed : Nat) (max : Nat) : Int × Nat :=
  let s' := lcgNext seed
  ((s' % max : Nat), s')

def generateWithSolution (numVars : Nat) (maxBits : Nat) (seed : Nat)
    : PolyEquation × List Int × Nat :=
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

structure FuzzResult where
  testName   : String
  passed     : Bool
  equation   : PolyEquation
  solution   : List Int
  found      : List (List Int × Float)
  deriving Repr

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
