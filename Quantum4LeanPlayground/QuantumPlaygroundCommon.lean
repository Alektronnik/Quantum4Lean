/-
QuantumPlaygroundCommon.lean
Utilidades compartidas por todos los Playgrounds Diofantinos.

Funciones: intToFloat, decodeState, evalCost, bruteForceSolve.
Namespace: Quantum4LeanPlayground.Common.
-/

import Quantum4Lean

open Quantum4Lean

namespace Quantum4LeanPlayground.Common

def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

def decodeState (varBits : List Nat) (state : Nat) : List Int :=
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

end Quantum4LeanPlayground.Common
