/-
Quantum4LeanPolynomial.lean
Traductor polinomico generalizado: monomios multivariados -> Ising.

Soporta cualquier exponente n (genera x^n via expansion iterativa Z-mask).
Cubre Tijdeman, Pillai, Fermat-Catalan, Beal y generalizaciones.
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

private def listGet (xs : List α) (i : Nat) (d : α) : α := xs[i]? |>.getD d

private def qubitOffsets (varBits : List Nat) : List Nat :=
  let rec go (acc : Nat) : List Nat -> List Nat
    | [] => []
    | b :: bs => acc :: go (acc + b) bs
  go 0 varBits

private def identTerm : PauliString := PauliString.mk 1.0 []

/--
Representacion Z-mask: (coeficiente, mask) donde mask es un bitmask
de qubits con operador Z. Z*Z = I se implementa como XOR de masks.
-/
private def zmToPauli (startQ : Nat) (bits : Nat) (coeff : Float) (mask : Nat) : PauliString :=
  let terms := (List.range bits).filterMap fun j =>
    if ((mask >>> j) &&& 1) == 1 then
      some (PauliTerm.mk .Z (startQ + j))
    else none
  { coefficient := coeff, terms := terms }

/--
Reduce una lista de (coeff, mask) fusionando masks identicas.
-/
private def mergeZM (acc : List (Float × Nat)) (coeff : Float) (mask : Nat) : List (Float × Nat) :=
  match acc with
  | [] => [(coeff, mask)]
  | (c, m) :: rest =>
    if m == mask then (c + coeff, m) :: rest
    else (c, m) :: mergeZM rest coeff mask

/--
Expande x^1 = sum_j 2^{j-1} * (I - Z_j) como lista de PauliStrings.
-/
private def expandLinear (startQ : Nat) (bits : Nat) : List PauliString :=
  let constPart := (pow2 bits - 1.0) / 2.0
  let idStr := PauliString.mk constPart []
  let zStrs := List.map (fun j =>
    PauliString.mk (-pow2 j / 2.0) [PauliTerm.mk .Z (startQ + j)]
  ) (List.range bits)
  idStr :: zStrs

/--
Expande x^n para x = sum_j 2^j * (1-Z_j)/2, con b bits.
Algoritmo: multiplicacion iterativa en representacion Z-mask.
Z*Z = I via XOR de masks. Complejidad O(2^b * n).
-/
def expandVarPower (startQ : Nat) (bits : Nat) (exponent : Nat) : List PauliString :=
  if exponent == 0 then
    [identTerm]
  else if exponent == 1 then
    expandLinear startQ bits
  else
    -- Base: x = sum_{j=0}^{b-1} 2^{j-1} * I  +  (-2^{j-1}) * Z_j
    let base : List (Float × Nat) :=
      listBind (List.range bits) fun j =>
        let c := pow2 j / 2.0
        [(c, 0), (-c, 1 <<< j)]
    -- Potenciacion: x^(k+1) = x^k * x, multiplicando masks con XOR
    let rec pow (k : Nat) (current : List (Float × Nat)) : List (Float × Nat) :=
      if k >= exponent then current
      else
        let next := listBind current fun (c1, m1) =>
          base.map fun (c2, m2) =>
            (c1 * c2, m1 ^^^ m2)
        let merged := next.foldl (fun acc (c, m) => mergeZM acc c m) []
        pow (k + 1) merged
    let result := pow 1 base
    result.map fun (coeff, mask) => zmToPauli startQ bits coeff mask

def expandMonomial (m : Monomial) (offsets : List Nat) (varBits : List Nat) : List PauliString :=
  let nVars := varBits.length
  let perVar : List (List PauliString) := List.map (fun i =>
    let exp := (List.find? (fun (idx, _) => idx == i) m.exponents).map (fun (_, e) => e) |>.getD 0
    let startQ := listGet offsets i 0
    let bits := listGet varBits i 0
    expandVarPower startQ bits exp
  ) (List.range nVars)
  let combined : List PauliString := List.foldl (fun (acc : List PauliString) (terms : List PauliString) =>
    listBind acc (fun a => List.map (fun t =>
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
  let selfSq : List PauliString := listBind expanded (fun terms =>
    listBind terms (fun a => List.map (fun b =>
      { coefficient := a.coefficient * b.coefficient, terms := a.terms ++ b.terms }
    ) terms))
  let nMon := expanded.length
  let cross : List PauliString := listBind (List.range nMon) (fun i =>
    listBind (List.filter (fun k => i < k) (List.range nMon)) (fun k =>
      let termsI := listGet expanded i []
      let termsK := listGet expanded k []
      listBind termsI (fun a => List.map (fun b =>
        { coefficient := 2.0 * a.coefficient * b.coefficient, terms := a.terms ++ b.terms }
      ) termsK)))
  let linearC : List PauliString := listBind expanded (fun terms =>
    List.map (fun ps => { ps with coefficient := -2.0 * c * ps.coefficient }) terms)
  let constTerm := PauliString.mk (c * c) []
  { strings := selfSq ++ cross ++ linearC ++ [constTerm] }

def polyTotalQubits (eq : PolyEquation) : Nat :=
  List.foldl (fun acc b => acc + b) 0 eq.varBits

end Quantum4Lean
