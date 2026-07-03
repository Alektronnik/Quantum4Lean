/-
Quantum4LeanClifford.lean
Verificacion formal de circuitos Clifford via aritmetica entera.

Las puertas Clifford (X, Y, Z, S, CNOT, CZ, SWAP) generan amplitudes
en el anillo Z[i] = {a + bi | a,b ∈ Z}. Sin √2, sin Float.

Esto permite que `native_decide` demuestre equivalencias de circuitos
Clifford automaticamente, sin depender de `Float.sqrt`.

Puertas cubiertas:
  X, Y, Z, S, CNOT, CZ, SWAP  -- 7 puertas
Puertas NO cubiertas (requieren 1/√2 o Float):
  H, T, RX, RY, RZ, Unitary   -- 6 puertas

Uso:
  #eval cliffordEquiv c1 c2           -- runtime check
  theorem miTeorema : cliffordEquiv ... := by native_decide  -- proof

Compatible: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean

-- ===================================================================
-- Amplitud Clifford: a + bi, a,b ∈ Z
-- ===================================================================

structure CliffordAmplitude where
  re : Int
  im : Int
  deriving Repr, DecidableEq, Inhabited

namespace CliffordAmplitude

def zero : CliffordAmplitude := { re := 0, im := 0 }
def one  : CliffordAmplitude := { re := 1, im := 0 }

def add (a b : CliffordAmplitude) : CliffordAmplitude :=
  { re := a.re + b.re, im := a.im + b.im }

def mul (a b : CliffordAmplitude) : CliffordAmplitude :=
  { re := a.re * b.re - a.im * b.im, im := a.re * b.im + a.im * b.re }

instance : Add CliffordAmplitude where add := add
instance : Mul CliffordAmplitude where mul := mul
instance : OfNat CliffordAmplitude 0 where ofNat := zero
instance : OfNat CliffordAmplitude 1 where ofNat := one

end CliffordAmplitude

-- ===================================================================
-- Matriz Clifford
-- ===================================================================

structure CliffordMatrix (n : Nat) where
  entries : List (List CliffordAmplitude)
  dim     : Nat
  deriving Repr, Inhabited

namespace CliffordMatrix

def identity (n : Nat) : CliffordMatrix n :=
  let d := 1 <<< n
  let row (i : Nat) : List CliffordAmplitude :=
    (List.range d).map fun j =>
      if i == j then CliffordAmplitude.one else CliffordAmplitude.zero
  { entries := (List.range d).map row, dim := d }

def get {n : Nat} (m : CliffordMatrix n) (i j : Nat) : CliffordAmplitude :=
  match m.entries[i]? with
  | some row => row[j]? |>.getD CliffordAmplitude.zero
  | none => CliffordAmplitude.zero

def mul {n : Nat} (a b : CliffordMatrix n) : CliffordMatrix n :=
  let d := a.dim
  let row (i : Nat) : List CliffordAmplitude :=
    (List.range d).map fun j =>
      (List.range d).foldl (fun acc k =>
        acc + get a i k * get b k j
      ) CliffordAmplitude.zero
  { entries := (List.range d).map row, dim := d }

/-- Compara dos matrices Clifford elemento a elemento. --/
def equal (a b : CliffordMatrix n) : Bool :=
  if a.dim ≠ b.dim then false else
  (List.range a.dim).all fun i =>
    (List.range a.dim).all fun j =>
      get a i j == get b i j

end CliffordMatrix

-- ===================================================================
-- Matrices de puertas Clifford (en Z[i])
-- ===================================================================

private def cA (re im : Int) : CliffordAmplitude := { re := re, im := im }

-- Pauli X: [[0,1],[1,0]]
private def gateXC : List CliffordAmplitude := [cA 0 0, cA 1 0, cA 1 0, cA 0 0]
-- Pauli Y: [[0,-i],[i,0]]
private def gateYC : List CliffordAmplitude := [cA 0 0, cA 0 (-1), cA 0 1, cA 0 0]
-- Pauli Z: [[1,0],[0,-1]]
private def gateZC : List CliffordAmplitude := [cA 1 0, cA 0 0, cA 0 0, cA (-1) 0]
-- S (fase): [[1,0],[0,i]]
private def gateSC : List CliffordAmplitude := [cA 1 0, cA 0 0, cA 0 0, cA 0 1]

-- ===================================================================
-- Expansion tensorial a n qubits (identica a Unitary pero con Int)
-- ===================================================================

private def expand1Q {n : Nat} (g : List CliffordAmplitude) (q : Nat) : CliffordMatrix n :=
  let d := 1 <<< n
  let dMinusOne := d - 1
  let mask := 1 <<< q
  let notMask := dMinusOne ^^^ mask
  let g00 := g[0]? |>.getD (cA 1 0)
  let g01 := g[1]? |>.getD (cA 0 0)
  let g10 := g[2]? |>.getD (cA 0 0)
  let g11 := g[3]? |>.getD (cA 1 0)
  let row (i : Nat) : List CliffordAmplitude :=
    (List.range d).map fun j =>
      if (i ^^^ j) &&& notMask == 0 then
        let iBit := (i >>> q) &&& 1
        let jBit := (j >>> q) &&& 1
        match iBit, jBit with
        | 0, 0 => g00 | 0, 1 => g01
        | 1, 0 => g10 | 1, 1 => g11
        | _, _ => cA 0 0
      else cA 0 0
  { entries := (List.range d).map row, dim := d }

private def expandCNOT {n : Nat} (c t : Nat) : CliffordMatrix n :=
  let d := 1 <<< n
  let tMask := 1 <<< t
  let row (i : Nat) : List CliffordAmplitude :=
    (List.range d).map fun j =>
      let expected := if ((i >>> c) &&& 1) == 1 then i ^^^ tMask else i
      if j == expected then cA 1 0 else cA 0 0
  { entries := (List.range d).map row, dim := d }

private def expandCZ {n : Nat} (c t : Nat) : CliffordMatrix n :=
  let d := 1 <<< n
  let row (i : Nat) : List CliffordAmplitude :=
    (List.range d).map fun j =>
      if i == j then
        if ((i >>> c) &&& 1) == 1 && ((i >>> t) &&& 1) == 1 then
          cA (-1) 0
        else cA 1 0
      else cA 0 0
  { entries := (List.range d).map row, dim := d }

private def expandSWAP {n : Nat} (a b : Nat) : CliffordMatrix n :=
  let d := 1 <<< n
  let dMinusOne := d - 1
  let aMask := 1 <<< a
  let bMask := 1 <<< b
  let clearMask := dMinusOne ^^^ aMask ^^^ bMask
  let row (i : Nat) : List CliffordAmplitude :=
    (List.range d).map fun j =>
      let bitA := (i >>> a) &&& 1
      let bitB := (i >>> b) &&& 1
      let swapped := (i &&& clearMask) ||| (bitB <<< a) ||| (bitA <<< b)
      if j == swapped then cA 1 0 else cA 0 0
  { entries := (List.range d).map row, dim := d }

-- ===================================================================
-- Compilacion y equivalencia
-- ===================================================================

/-- Matriz Clifford de una puerta. Puertas no-Clifford devuelven none. --/
def gateMatrix {n : Nat} (g : Gate n) : Option (CliffordMatrix n) :=
  match g with
  | .X q    => some (expand1Q gateXC q.idx.val)
  | .Y q    => some (expand1Q gateYC q.idx.val)
  | .Z q    => some (expand1Q gateZC q.idx.val)
  | .S q    => some (expand1Q gateSC q.idx.val)
  | .CNOT ctrl tgt => some (expandCNOT ctrl.idx.val tgt.idx.val)
  | .CZ   ctrl tgt => some (expandCZ   ctrl.idx.val tgt.idx.val)
  | .SWAP a b      => some (expandSWAP a.idx.val b.idx.val)
  -- Puertas no-Clifford: rechazadas
  | _ => none

/-- Compila un circuito a su matriz Clifford. Puertas no-Clifford causan fallo. --/
def compileClifford {n : Nat} (c : Circuit n) : Option (CliffordMatrix n) :=
  c.gates.foldl (fun (mo : Option (CliffordMatrix n)) (g : Gate n) =>
    match mo with
    | none => none
    | some m =>
      match gateMatrix g with
      | none => none
      | some gm => some (CliffordMatrix.mul gm m)
  ) (some (CliffordMatrix.identity n))

/--
Equivalencia de circuitos Clifford via comparacion entera.
Devuelve false si algun circuito contiene puertas no-Clifford.
-/
def cliffordEquiv {n : Nat} (c1 c2 : Circuit n) : Bool :=
  match compileClifford c1, compileClifford c2 with
  | some m1, some m2 => CliffordMatrix.equal m1 m2
  | _, _ => false

-- ===================================================================
-- Helper: Qubit para n=2
-- ===================================================================

private def q0 : Qubit 2 := ⟨⟨0, by native_decide⟩⟩
private def q1 : Qubit 2 := ⟨⟨1, by native_decide⟩⟩

-- ===================================================================
-- Teoremas demostrados (8/8, sin sorry)
-- ===================================================================

theorem clifford_rule_X_X_eq_I :
    cliffordEquiv
      (circuit fun c => (c.add (Gate.X q0)).add (Gate.X q0))
      (Circuit.identity 2) := by
  native_decide

theorem clifford_rule_Y_Y_eq_I :
    cliffordEquiv
      (circuit fun c => (c.add (Gate.Y q0)).add (Gate.Y q0))
      (Circuit.identity 2) := by
  native_decide

theorem clifford_rule_Z_Z_eq_I :
    cliffordEquiv
      (circuit fun c => (c.add (Gate.Z q0)).add (Gate.Z q0))
      (Circuit.identity 2) := by
  native_decide

theorem clifford_rule_CNOT_CNOT_eq_I :
    cliffordEquiv
      (circuit fun c => (c.add (Gate.CNOT q0 q1)).add (Gate.CNOT q0 q1))
      (Circuit.identity 2) := by
  native_decide

theorem clifford_rule_CZ_CZ_eq_I :
    cliffordEquiv
      (circuit fun c => (c.add (Gate.CZ q0 q1)).add (Gate.CZ q0 q1))
      (Circuit.identity 2) := by
  native_decide

theorem clifford_rule_SWAP_SWAP_eq_I :
    cliffordEquiv
      (circuit fun c => (c.add (Gate.SWAP q0 q1)).add (Gate.SWAP q0 q1))
      (Circuit.identity 2) := by
  native_decide

theorem clifford_rule_S_S_eq_Z :
    cliffordEquiv
      (circuit fun c => (c.add (Gate.S q0)).add (Gate.S q0))
      (circuit fun c => c.add (Gate.Z q0)) := by
  native_decide

theorem clifford_rule_CNOT_swap_decomposition :
    cliffordEquiv
      (circuit fun c =>
        ((c.add (Gate.CNOT q0 q1)).add (Gate.CNOT q1 q0)).add (Gate.CNOT q0 q1))
      (circuit fun c => c.add (Gate.SWAP q0 q1)) := by
  native_decide

end Quantum4Lean
