/-
Quantum4LeanAnsatz.lean
Hardware Efficient Ansatz (HEA) para VQE quimico.

Estructura por capa:
  1. Ry(θ_i) en cada qubit
  2. Rz(θ_i) en cada qubit
  3. Anillo CNOT completo (incluye cierre n-1 -> 0)

Parametros: 2 * n * depth (Ry + Rz por qubit por capa).
Entrelazamiento maximal para correlaciones electronicas.
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean

/--
Capa HEA: Ry(θ) + Rz(θ) + CNOT ring.
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

end Quantum4Lean
