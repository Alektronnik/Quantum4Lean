/-
MobiusAnsatz.lean
Hardware Efficient Ansatz (HEA) para quimica cuantica.

Disenado para el experimento Half-Mobius C13Cl2 (IBM, Science 2026).

Estructura por capa:
  1. Ry(θ_i) en cada qubit (rotacion Y parametrizada)
  2. Rz(θ_i) en cada qubit (rotacion Z parametrizada)
  3. Anillo CNOT: CNOT(0,1), CNOT(1,2), ..., CNOT(n-2,n-1), CNOT(n-1,0)

Parametros: 2 * n * depth (Ry + Rz por qubit por capa).

El anillo CNOT completo (incluyendo cierre n-1->0) genera
entrelazamiento maximal, necesario para capturar correlaciones
electronicas en sistemas moleculares complejos.
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4LeanPlayground.Mobius

open Quantum4Lean

/--
Construye una capa del HEA: Ry(θ) + Rz(θ) + CNOT ring.

Parametros para esta capa: 2*n floats [Ry0, Rz0, Ry1, Rz1, ...].
-/
def heaLayer (n : Nat) (params : List Float) (offset : Nat) : Circuit n :=
  let gatesRy : List (Gate n) :=
    (List.range n).filterMap fun i =>
      let pIdx := offset + 2 * i
      if h : i < n then
        let q := Qubit.ofNat i h
        let theta := params[pIdx]!
        some (Gate.RY q theta)
      else none
  let gatesRz : List (Gate n) :=
    (List.range n).filterMap fun i =>
      let pIdx := offset + 2 * i + 1
      if h : i < n then
        let q := Qubit.ofNat i h
        let theta := params[pIdx]!
        some (Gate.RZ q theta)
      else none
  let gatesCNOT : List (Gate n) :=
    (List.range n).filterMap fun i =>
      let j := if i + 1 < n then i + 1 else 0
      if hi : i < n then
        if hj : j < n then
          some (Gate.CNOT (Qubit.ofNat i hi) (Qubit.ofNat j hj))
        else none
      else none
  { gates := gatesRy ++ gatesRz ++ gatesCNOT }

/--
Hardware Efficient Ansatz completo: `depth` capas.

Parametros totales: 2 * n * depth.
-/
def mobiusAnsatz (n : Nat) (depth : Nat) (params : List Float) : Circuit n :=
  (List.range depth).foldl (fun (c : Circuit n) (d : Nat) =>
    let layer := heaLayer n params (2 * n * d)
    Circuit.comp c layer
  ) (Circuit.identity n)

/--
Numero de parametros necesarios para el ansatz.
-/
def mobiusAnsatzNumParams (n : Nat) (depth : Nat) : Nat := 2 * n * depth

end Quantum4LeanPlayground.Mobius
