/-
QuantumPlaygroundBeal.lean
Conjetura de Beal: a^x + b^y = c^z con gcd(a,b,c) > 1.

5 casos en 3 escalas de busqueda exhaustiva.
-/

import Quantum4Lean
import Quantum4LeanPlayground.QuantumPlaygroundCommon

open Quantum4Lean
open Quantum4LeanPlayground.Common

namespace Quantum4LeanPlayground.Beal

private def gcd3 (a b c : Int) : Int :=
  let absA := if a >= 0 then a else -a
  let absB := if b >= 0 then b else -b
  let absC := if c >= 0 then c else -c
  ((absA.gcd absB).gcd absC.toNat : Int)

/-- Genera reporte para una ecuacion Beal generica. --/
private def caseReport (name : String) (aExp bExp cExp : Nat) (bitsA bitsB bitsC : Nat) : String :=
  let eq : PolyEquation := {
    monomials := [
      { coefficient := 1,  exponents := [(0, aExp)] },
      { coefficient := 1,  exponents := [(1, bExp)] },
      { coefficient := -1, exponents := [(2, cExp)] }
    ],
    constant := 0,
    varBits := [bitsA, bitsB, bitsC]
  }
  let totalQubits := polyTotalQubits eq
  let dim := 1 <<< totalQubits
  let results := (List.range dim).filterMap fun state =>
    let vals := decodeState eq.varBits state
    let a := vals.get! 0
    let b := vals.get! 1
    let c := vals.get! 2
    let af := intToFloat a; let bf := intToFloat b; let cf := intToFloat c
    let aPow := (List.range aExp).foldl (fun (acc : Float) _ => acc * af) 1.0
    let bPow := (List.range bExp).foldl (fun (acc : Float) _ => acc * bf) 1.0
    let cPow := (List.range cExp).foldl (fun (acc : Float) _ => acc * cf) 1.0
    let diff := aPow + bPow - cPow
    if diff.abs < 1e-6 then some (a, b, c, gcd3 a b c) else none
  let gcd1 := results.filter fun (_, _, _, g) => g == 1
  let gcdGt1 := results.filter fun (_, _, _, g) => g > 1
  let desc := s!"a^{aExp} + b^{bExp} = c^{cExp}"
  s!"[{name}] {desc} ({totalQubits} qubits)\n" ++
  s!"  Soluciones: {results.length} | gcd=1: {gcd1.length} | gcd>1: {gcdGt1.length}\n" ++
  (if gcd1.isEmpty then "  Beal se mantiene.\n"
   else "  CONTRAEJEMPLOS: " ++ String.intercalate " | " (gcd1.map fun (a,b,c,_) => s!"({a},{b},{c})") ++ "\n") ++
  (if gcdGt1.length <= 5 then
    "  Cumplen: " ++ String.intercalate " | " (gcdGt1.map fun (a,b,c,g) => s!"({a},{b},{c}) g={g}") ++ "\n"
   else s!"  Cumplen: {gcdGt1.length} soluciones (primeras 5 mostradas)\n")

def smallCase  := caseReport "Beal 3+3=2" 3 3 2 4 4 5
def mixedCase  := caseReport "Beal 3+2=3" 3 2 3 3 4 3
def altCase    := caseReport "Beal 2+3=3" 2 3 3 4 5 4
def tripleCase := caseReport "Beal 3+3=3" 3 3 3 4 4 4
def largeCase  := caseReport "Beal 3+3=2 L" 3 3 2 6 6 7

def report : String :=
  "Beal -- Conjetura de Beal (a^x + b^y = c^z)\n" ++
  "==========================================\n\n" ++
  String.intercalate "\n" [smallCase, mixedCase, altCase, tripleCase, largeCase]

end Quantum4LeanPlayground.Beal
