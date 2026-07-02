/-
Quantum4LeanPolynomial.lean
Traductor polinomico generalizado: monomios multivariados -> Ising.

Soporta exponentes ≤ 3 (cubre Tijdeman, Pillai, Fermat-Catalan).
Build autocontenido. Lean 4.7.0.
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanObservable
import Quantum4Lean.Quantum4LeanQAOA

open Quantum4Lean

namespace Quantum4Lean

structure Monomial where
  coefficient : Int
  exponents   : List (Nat × Nat)
  deriving Repr

structure PolyEquation where
  monomials : List Monomial
  constant  : Int
  varBits   : List Nat
  deriving Repr

structure PolyResult where
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

private def listGet (xs : List α) (i : Nat) (d : α) : α := xs.get? i |>.getD d

private def qubitOffsets (varBits : List Nat) : List Nat :=
  let rec go (acc : Nat) : List Nat -> List Nat
    | [] => []
    | b :: bs => acc :: go (acc + b) bs
  go 0 varBits

private def identTerm : PauliString := PauliString.mk 1.0 []

private def expandLinear (startQ : Nat) (bits : Nat) : List PauliString :=
  let constPart := (pow2 bits - 1.0) / 2.0
  let idStr := PauliString.mk constPart []
  let zStrs := List.map (fun j =>
    PauliString.mk (-pow2 j / 2.0) [PauliTerm.mk .Z (startQ + j)]
  ) (List.range bits)
  idStr :: zStrs

private def expandQuadratic (startQ : Nat) (bits : Nat) : List PauliString :=
  let half : Float := 0.5
  let quarter : Float := 0.25
  let diagI := List.foldl (fun acc j => acc + pow2 (2*j) * half) 0.0 (List.range bits)
  let diagZ := List.map (fun j =>
    PauliString.mk (-pow2 (2*j) * half) [PauliTerm.mk .Z (startQ + j)]
  ) (List.range bits)
  let offVals : List Float := List.bind (List.range bits) (fun j =>
    List.map (fun k => quarter * 2.0 * pow2 (j + k))
      (List.filter (fun k => j < k) (List.range bits)))
  let offI := List.foldl (fun acc x => acc + x) 0.0 offVals
  let offZ : List PauliString := List.bind (List.range bits) (fun j =>
    List.bind (List.filter (fun k => j < k) (List.range bits)) (fun k =>
      let c := half * pow2 (j + k)
      [PauliString.mk (-c) [PauliTerm.mk .Z (startQ + j)], PauliString.mk (-c) [PauliTerm.mk .Z (startQ + k)]]))
  let offZZ : List PauliString := List.bind (List.range bits) (fun j =>
    List.map (fun k =>
      PauliString.mk (half * pow2 (j + k)) [PauliTerm.mk .Z (startQ + j), PauliTerm.mk .Z (startQ + k)]
    ) (List.filter (fun k => j < k) (List.range bits)))
  let totalI := diagI + offI
  (PauliString.mk totalI []) :: (diagZ ++ offZ ++ offZZ)

private def expandCubic (startQ : Nat) (bits : Nat) : List PauliString :=
  let eighth : Float := 0.125
  let quarter : Float := 0.25
  let half : Float := 0.5
  let diagI := List.foldl (fun acc j => acc + pow2 (3*j) * half) 0.0 (List.range bits)
  let diagZ := List.map (fun j =>
    PauliString.mk (-pow2 (3*j) * half) [PauliTerm.mk .Z (startQ + j)]
  ) (List.range bits)
  -- pair
  let pairVals : List Float := List.bind (List.range bits) (fun j =>
    List.map (fun l => 3.0 * pow2 (2*j + l) * eighth)
      (List.filter (fun l => j ≠ l) (List.range bits)))
  let pairI := List.foldl (fun acc x => acc + x) 0.0 pairVals
  let pairZ : List PauliString := List.bind (List.range bits) (fun j =>
    List.bind (List.filter (fun l => j ≠ l) (List.range bits)) (fun l =>
      let c := 3.0 * pow2 (2*j + l) * quarter
      [PauliString.mk (-c) [PauliTerm.mk .Z (startQ + j)], PauliString.mk (-c) [PauliTerm.mk .Z (startQ + l)]]))
  let pairZZ : List PauliString := List.bind (List.range bits) (fun j =>
    List.map (fun l =>
      PauliString.mk (3.0 * pow2 (2*j + l) * quarter)
        [PauliTerm.mk .Z (startQ + j), PauliTerm.mk .Z (startQ + l)]
    ) (List.filter (fun l => j ≠ l) (List.range bits)))
  -- triple
  let tripleVals : List Float := List.bind (List.range bits) (fun j =>
    List.bind (List.range bits) (fun k =>
      List.map (fun l => 6.0 * pow2 (j + k + l) * eighth)
        (List.filter (fun l => j < k && k < l) (List.range bits))))
  let tripleI := List.foldl (fun acc x => acc + x) 0.0 tripleVals
  let tripleZ : List PauliString := List.bind (List.range bits) (fun j =>
    List.bind (List.range bits) (fun k =>
      List.bind (List.filter (fun l => j < k && k < l) (List.range bits)) (fun l =>
        let c := 6.0 * pow2 (j + k + l) * eighth
        [PauliString.mk (-c) [PauliTerm.mk .Z (startQ + j)],
         PauliString.mk (-c) [PauliTerm.mk .Z (startQ + k)],
         PauliString.mk (-c) [PauliTerm.mk .Z (startQ + l)]])))
  let tripleZZ : List PauliString := List.bind (List.range bits) (fun j =>
    List.bind (List.range bits) (fun k =>
      List.bind (List.filter (fun l => j < k && k < l) (List.range bits)) (fun l =>
        let c := 6.0 * pow2 (j + k + l) * quarter
        [PauliString.mk c [PauliTerm.mk .Z (startQ + j), PauliTerm.mk .Z (startQ + k)],
         PauliString.mk c [PauliTerm.mk .Z (startQ + j), PauliTerm.mk .Z (startQ + l)],
         PauliString.mk c [PauliTerm.mk .Z (startQ + k), PauliTerm.mk .Z (startQ + l)]])))
  let tripleZZZ : List PauliString := List.bind (List.range bits) (fun j =>
    List.bind (List.range bits) (fun k =>
      List.map (fun l =>
        PauliString.mk (-6.0 * pow2 (j + k + l) * eighth)
          [PauliTerm.mk .Z (startQ + j), PauliTerm.mk .Z (startQ + k), PauliTerm.mk .Z (startQ + l)]
      ) (List.filter (fun l => j < k && k < l) (List.range bits))))
  let totalI := diagI + pairI + tripleI
  (PauliString.mk totalI []) :: (diagZ ++ pairZ ++ tripleZ ++ pairZZ ++ tripleZZ ++ tripleZZZ)

def expandVarPower (startQ : Nat) (bits : Nat) (exponent : Nat) : List PauliString :=
  match exponent with
  | 0 => [identTerm]
  | 1 => expandLinear startQ bits
  | 2 => expandQuadratic startQ bits
  | 3 => expandCubic startQ bits
  | _ => []

def expandMonomial (m : Monomial) (offsets : List Nat) (varBits : List Nat) : List PauliString :=
  let nVars := varBits.length
  let perVar : List (List PauliString) := List.map (fun i =>
    let exp := (List.find? (fun (idx, _) => idx == i) m.exponents).map (fun (_, e) => e) |>.getD 0
    let startQ := listGet offsets i 0
    let bits := listGet varBits i 0
    expandVarPower startQ bits exp
  ) (List.range nVars)
  let combined : List PauliString := List.foldl (fun (acc : List PauliString) (terms : List PauliString) =>
    List.bind acc (fun a => List.map (fun t =>
      { coefficient := a.coefficient * t.coefficient, terms := a.terms ++ t.terms }
    ) terms)
  ) [identTerm] perVar
  let c := intToFloat m.coefficient
  List.map (fun ps => { ps with coefficient := ps.coefficient * c }) combined

def polyToIsing (eq : PolyEquation) : Observable :=
  let offsets := qubitOffsets eq.varBits
  let c := intToFloat eq.constant
  let expanded : List (List PauliString) :=
    List.map (fun m => expandMonomial m offsets eq.varBits) eq.monomials
  let selfSq : List PauliString := List.bind expanded (fun terms =>
    List.bind terms (fun a => List.map (fun b =>
      { coefficient := a.coefficient * b.coefficient, terms := a.terms ++ b.terms }
    ) terms))
  let nMon := expanded.length
  let cross : List PauliString := List.bind (List.range nMon) (fun i =>
    List.bind (List.filter (fun k => i < k) (List.range nMon)) (fun k =>
      let termsI := listGet expanded i []
      let termsK := listGet expanded k []
      List.bind termsI (fun a => List.map (fun b =>
        { coefficient := 2.0 * a.coefficient * b.coefficient, terms := a.terms ++ b.terms }
      ) termsK)))
  let linearC : List PauliString := List.bind expanded (fun terms =>
    List.map (fun ps => { ps with coefficient := -2.0 * c * ps.coefficient }) terms)
  let constTerm := PauliString.mk (c * c) []
  { strings := selfSq ++ cross ++ linearC ++ [constTerm] }

def polyTotalQubits (eq : PolyEquation) : Nat :=
  List.foldl (fun acc b => acc + b) 0 eq.varBits

end Quantum4Lean
