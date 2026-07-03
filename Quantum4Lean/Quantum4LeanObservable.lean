/-
Quantum4LeanObservable.lean
Observables cuanticos puros sobre StateVector (sin FFI, sin monada).

Define:
  - Pauli: I, X, Y, Z
  - PauliString: producto tensorial de Paulis con coeficiente
  - Observable: suma ponderada de PauliStrings
  - expect: <H> para cualquier Observable sobre StateVector

Algoritmo de expectacion (identico al original pero puro):
  Para cada PauliString:
    1. Aplica rotaciones de base (X->H, Y->Sdg+H) para diagonalizar en Z
    2. Lee probabilidades del StateVector
    3. Calcula <Z_product> = sum_i parity(i) * P(i)
    4. Multiplica por coeficiente y acumula
  Sin colapsar el estado. Sin extraer amplitudes complejas.
-/

import Quantum4Lean.Quantum4LeanEngine

namespace Quantum4Lean

-- ===================================================================
-- Tipos
-- ===================================================================

inductive Pauli : Type where
  | I | X | Y | Z
  deriving Repr, DecidableEq

structure PauliTerm where
  pauli : Pauli
  qubit : Nat
  deriving Repr

structure PauliString where
  coefficient : Float
  terms       : List PauliTerm
  deriving Repr

structure Observable where
  strings : List PauliString
  deriving Repr

namespace Observable

def zero : Observable := { strings := [] }

def identity (c : Float) : Observable :=
  { strings := [PauliString.mk c []] }

def pauli (p : Pauli) (q : Nat) (c : Float := 1.0) : Observable :=
  { strings := [PauliString.mk c [PauliTerm.mk p q]] }

def add (a b : Observable) : Observable :=
  { strings := a.strings ++ b.strings }

def scale (c : Float) (o : Observable) : Observable :=
  { strings := o.strings.map fun ps =>
      { ps with coefficient := ps.coefficient * c } }

-- ===================================================================
-- Hamiltonianos comunes
-- ===================================================================

/-- Ising 1D: H = -J sum Z_i Z_{i+1} - h sum X_i --/
def ising1D (numQubits : Nat) (jCoupling : Float) (hField : Float) : Observable :=
  let pairs := List.range (numQubits - 1) |>.map fun i =>
    PauliString.mk (-jCoupling)
      [PauliTerm.mk .Z i, PauliTerm.mk .Z (i+1)]
  let fields := List.range numQubits |>.map fun i =>
    PauliString.mk (-hField) [PauliTerm.mk .X i]
  { strings := pairs ++ fields }

/-- Heisenberg 1D: H = J sum (X_i X_{i+1} + Y_i Y_{i+1} + Z_i Z_{i+1}) --/
def heisenberg1D (numQubits : Nat) (jCoupling : Float) : Observable :=
  let pairs := List.range (numQubits - 1)
  let xx := pairs.map fun i =>
    PauliString.mk jCoupling
      [PauliTerm.mk .X i, PauliTerm.mk .X (i+1)]
  let yy := pairs.map fun i =>
    PauliString.mk jCoupling
      [PauliTerm.mk .Y i, PauliTerm.mk .Y (i+1)]
  let zz := pairs.map fun i =>
    PauliString.mk jCoupling
      [PauliTerm.mk .Z i, PauliTerm.mk .Z (i+1)]
  { strings := xx ++ yy ++ zz }

end Observable

-- ===================================================================
-- Operaciones puras sobre StateVector para expectacion
-- ===================================================================

/-- Aplica puerta 1-qubit al StateVector usando indice Nat --/
private def applyGateNat (sv : StateVector) (gateFn : Qubit sv.numQubits -> Gate sv.numQubits) (q : Nat) : StateVector :=
  if h : q < sv.numQubits then
    let qubit : Qubit sv.numQubits := ⟨⟨q, h⟩⟩
    StateVector.applyGate sv (gateFn qubit)
  else
    sv

/-- Aplica puerta 1-qubit con indice Nat (version simplificada) --/
private def applyH (sv : StateVector) (q : Nat) : StateVector :=
  applyGateNat sv Gate.H q

private def applyS (sv : StateVector) (q : Nat) : StateVector :=
  applyGateNat sv Gate.S q

private def applyCNOT (sv : StateVector) (c t : Nat) : StateVector :=
  if hc : c < sv.numQubits then
    if ht : t < sv.numQubits then
      let qc : Qubit sv.numQubits := ⟨⟨c, hc⟩⟩
      let qt : Qubit sv.numQubits := ⟨⟨t, ht⟩⟩
      StateVector.applyGate sv (Gate.CNOT qc qt)
    else sv
  else sv

/--
Aplica rotacion de base para convertir medicion Pauli a Z.
Devuelve (stateVectorRotado, funcionDeshacer).
-/
private def applyBasisRotation (sv : StateVector) (t : PauliTerm) : StateVector × (StateVector -> StateVector) :=
  match t.pauli with
  | .X =>
      let sv' := applyH sv t.qubit
      -- undo: H again (H = H^dagger)
      (sv', fun sv'' => applyH sv'' t.qubit)
  | .Y =>
      -- Sdg = S^3, then H
      let sv1 := applyS (applyS (applyS sv t.qubit) t.qubit) t.qubit
      let sv2 := applyH sv1 t.qubit
      -- undo: H, then S
      (sv2, fun sv'' =>
        let u1 := applyH sv'' t.qubit
        applyS u1 t.qubit)
  | .Z | .I => (sv, fun sv'' => sv'')

/--
Valor esperado de una PauliString sobre un StateVector.
No modifica el estado (aplica y deshace rotaciones).
-/
def expectPauliString (sv : StateVector) (ps : PauliString) : Float :=
  -- 1. Aplicar rotaciones de base
  let (svRot, undosRev) :=
    ps.terms.foldl (fun ((cur : StateVector), (undos : List (StateVector -> StateVector))) (t : PauliTerm) =>
      let (sv', undo) := applyBasisRotation cur t
      (sv', undo :: undos)
    ) (sv, [])
  let undos := undosRev.reverse

  -- 2. Leer probabilidades
  let probs := StateVector.probabilities svRot
  let dim := svRot.dim

  -- 3. Calcular <Z_product> = sum_i parity(i) * P(i)
  let expectZ := (List.range dim).foldl (fun (acc : Float) (i : Nat) =>
    let prob := probs[i]!
    let parity := ps.terms.foldl (fun (par : Float) (t : PauliTerm) =>
      match t.pauli with
      | .Z | .X | .Y =>
          if ((i >>> t.qubit) &&& 1) == 1 then -par else par
      | .I => par
    ) 1.0
    acc + parity * prob
  ) 0.0

  -- 4. Deshacer rotaciones (no usado, el SV original no se modifica)
  -- La variable svRot se descarta; expectZ ya se calculo.
  -- Deshacemos para verificacion de pureza:
  let _svFinal := undos.foldl (fun (cur : StateVector) (undo : StateVector -> StateVector) => undo cur) svRot

  ps.coefficient * expectZ

/--
Valor esperado de un Observable: <H> = sum c_k * <P_k>.
-/
def expect (sv : StateVector) (obs : Observable) : Float :=
  obs.strings.foldl (fun (acc : Float) (ps : PauliString) =>
    acc + expectPauliString sv ps
  ) 0.0

/-- <Z_q> --/
def expectZ (sv : StateVector) (q : Nat) : Float :=
  expect sv (Observable.pauli .Z q)

/-- <X_q> --/
def expectX (sv : StateVector) (q : Nat) : Float :=
  expect sv (Observable.pauli .X q)

/-- <Y_q> --/
def expectY (sv : StateVector) (q : Nat) : Float :=
  expect sv (Observable.pauli .Y q)

/-- Valor esperado de una PauliString arbitraria. --/
def expectString (sv : StateVector) (coeff : Float) (terms : List (Pauli × Nat)) : Float :=
  let psTerms := terms.map fun (p, q) => PauliTerm.mk p q
  expectPauliString sv (PauliString.mk coeff psTerms)

end Quantum4Lean
