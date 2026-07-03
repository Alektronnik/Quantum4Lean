/-
QuantumPlaygroundBeal.lean
Conjetura de Beal: a^x + b^y = c^z con gcd(a,b,c) > 1.

Busqueda masiva de contraejemplos via polyToIsing + busqueda exhaustiva.
Escalas: pequeña (12 qubits), grande (19 qubits).

Dependencias: Quantum4Lean (Polynomial, Observable).
Build autocontenido. Lean 4.7.0.
-/

import Quantum4Lean

open Quantum4Lean

namespace Quantum4LeanPlayground.Beal

private def gcd3 (a b c : Int) : Int :=
  let absA := if a >= 0 then a else -a
  let absB := if b >= 0 then b else -b
  let absC := if c >= 0 then c else -c
  (absA.gcd absB).gcd absC

private def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

private def decodeState (varBits : List Nat) (state : Nat) : List Int :=
  let offsets : List Nat :=
    let rec go (acc : Nat) : List Nat -> List Nat
      | [] => []
      | b :: bs => acc :: go (acc + b) bs
    go 0 varBits
  List.mapIdx (fun i (bits : Nat) =>
    let start := offsets.get\! i
    (List.range bits).foldl (fun (acc : Nat) (j : Nat) =>
      if ((state >>> (start + j)) &&& 1) == 1 then acc + (1 <<< j) else acc
    ) 0
  ) varBits

def evalBealCost (a b c : Int) : Float :=
  let af := intToFloat a
  let bf := intToFloat b
  let cf := intToFloat c
  let diff := af*af*af + bf*bf*bf - cf*cf
  diff * diff

-- ===================================================================
-- Caso: a^3 + b^3 = c^2 (12 qubits)
-- ===================================================================

def smallCaseEq : PolyEquation := {
  monomials := [
    { coefficient := 1,  exponents := [(0, 3)] },
    { coefficient := 1,  exponents := [(1, 3)] },
    { coefficient := -1, exponents := [(2, 2)] }
  ],
  constant := 0,
  varBits := [4, 4, 5]
}

def smallCaseReport : String :=
  let totalQubits := polyTotalQubits smallCaseEq
  let dim := 1 <<< totalQubits
  let results := (List.range dim).filterMap fun state =>
    let vals := decodeState smallCaseEq.varBits state
    let a := vals.get\! 0
    let b := vals.get\! 1
    let c := vals.get\! 2
    let cost := evalBealCost a b c
    if cost < 1e-6 then some (a, b, c, gcd3 a b c) else none
  let gcd1 := results.filter fun (_, _, _, g) => g == 1
  let gcdGt1 := results.filter fun (_, _, _, g) => g > 1
  s\!"Beal a^3 + b^3 = c^2 (12 qubits: a,b in 0..15, c in 0..31)\n" ++
  s\!"Soluciones exactas: {results.length}\n" ++
  s\!"Con gcd=1 (contraejemplos): {gcd1.length}\n" ++
  (if gcd1.isEmpty then "  NINGUNA. Beal se mantiene.\n"
   else String.intercalate "\n" (gcd1.map fun (a,b,c,_) => s\!"  a={a}, b={b}, c={c}") ++ "\n") ++
  s\!"Con gcd>1 (cumplen Beal): {gcdGt1.length}"

-- ===================================================================
-- Caso: a^3 + b^2 = c^3 (9 qubits, exploracion)
-- ===================================================================

def mixedCaseEq : PolyEquation := {
  monomials := [
    { coefficient := 1, exponents := [(0, 3)] },
    { coefficient := 1, exponents := [(1, 2)] },
    { coefficient := -1, exponents := [(2, 3)] }
  ],
  constant := 0,
  varBits := [3, 4, 3]
}

def mixedCaseReport : String :=
  let totalQubits := polyTotalQubits mixedCaseEq
  let dim := 1 <<< totalQubits
  let results := (List.range dim).filterMap fun state =>
    let vals := decodeState mixedCaseEq.varBits state
    let a := vals.get\! 0
    let b := vals.get\! 1
    let c := vals.get\! 2
    let cost := evalBealCost a b c
    if cost < 1e-6 then some (a, b, c, gcd3 a b c) else none
  s\!"Beal a^3 + b^2 = c^3 (9 qubits: a,c in 0..7, b in 0..15)\n" ++
  s\!"Soluciones exactas: {results.length}\n" ++
  (if results.isEmpty then "  Ninguna encontrada en este rango.\n"
   else String.intercalate "\n" (results.map fun (a,b,c,g) =>
     s\!"  a={a}, b={b}, c={c} (gcd={g})") ++ "\n")

-- ===================================================================
-- Busqueda masiva: a^3 + b^3 = c^2 (19 qubits)
-- ===================================================================

def largeCaseEq : PolyEquation := {
  monomials := [
    { coefficient := 1,  exponents := [(0, 3)] },
    { coefficient := 1,  exponents := [(1, 3)] },
    { coefficient := -1, exponents := [(2, 2)] }
  ],
  constant := 0,
  varBits := [6, 6, 7]
}

def largeCaseReport : String :=
  let totalQubits := polyTotalQubits largeCaseEq
  let dim := 1 <<< totalQubits
  let results := (List.range dim).filterMap fun state =>
    let vals := decodeState largeCaseEq.varBits state
    let a := vals.get\! 0
    let b := vals.get\! 1
    let c := vals.get\! 2
    let cost := evalBealCost a b c
    if cost < 1e-6 then some (a, b, c, gcd3 a b c) else none
  let gcd1 := results.filter fun (_, _, _, g) => g == 1
  let gcdGt1 := results.filter fun (_, _, _, g) => g > 1
  s\!"Beal a^3 + b^3 = c^2 (19 qubits: a,b in 0..63, c in 0..127)\n" ++
  s\!"Espacio: {dim} estados, evaluados exhaustivamente.\n" ++
  s\!"Soluciones exactas totales: {results.length}\n" ++
  s\!"Soluciones con gcd=1 (contraejemplos): {gcd1.length}\n" ++
  (if gcd1.isEmpty then "  NINGUNA. Beal se mantiene en este rango.\n"
   else String.intercalate "\n" (gcd1.map fun (a,b,c,_) => s\!"  a={a}, b={b}, c={c}") ++ "\n") ++
  s\!"Soluciones con gcd>1 (cumplen Beal): {gcdGt1.length}\n" ++
  (if gcdGt1.length <= 10 then
    String.intercalate "\n" (gcdGt1.map fun (a,b,c,g) => s\!"  a={a}, b={b}, c={c} (gcd={g})")
   else s\!"  (primeras 10 de {gcdGt1.length})")

def report : String :=
  "Beal -- Conjetura de Beal (a^x + b^y = c^z)\n" ++
  "==========================================\n\n" ++
  smallCaseReport ++ "\n\n" ++ mixedCaseReport ++ "\n\n" ++ largeCaseReport

end Quantum4LeanPlayground.Beal
