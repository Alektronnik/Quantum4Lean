/-
Quantum4LeanDSL.lean
Lenguaje de Dominio Especifico (DSL) estilo Apple para circuitos cuanticos.

Uso:
  import Quantum4Lean

  def bell : Circuit 2 := circuit! {
    H q[0];
    CNOT q[0] q[1]
  }

Sintaxis inspirada en el DSL de QuantumKit:
  H q[i]    -> Hadamard en qubit i
  X q[i]    -> Pauli-X
  CNOT q[i] q[j] -> CNOT control i, target j
  RX q[i](theta)  -> Rotacion X con angulo theta
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean.DSL

open Quantum4Lean

-- --- Azucar sintactico para construccion de circuitos ----------

/--
Referencia a un qubit: `q[0]`, `q[3]`, etc.
-/
syntax "q[" term "]" : term

macro_rules
  | `(q[$i]) => `(Qubit.ofNat $i)

/--
Aplicacion de puerta: `H q[0]`, `CNOT q[0] q[1]`.
-/
syntax "H"    term : gate
syntax "X"    term : gate
syntax "Y"    term : gate
syntax "Z"    term : gate
syntax "S"    term : gate
syntax "T"    term : gate
syntax "CNOT" term term : gate
syntax "CZ"   term term : gate
syntax "SWAP" term term : gate
syntax "RX" term "(" term ")" : gate
syntax "RY" term "(" term ")" : gate
syntax "RZ" term "(" term ")" : gate

macro_rules
  | `(H $q)    => `(Gate.H $q)
  | `(X $q)    => `(Gate.X $q)
  | `(Y $q)    => `(Gate.Y $q)
  | `(Z $q)    => `(Gate.Z $q)
  | `(S $q)    => `(Gate.S $q)
  | `(T $q)    => `(Gate.T $q)
  | `(CNOT $c $t) => `(Gate.CNOT $c $t)
  | `(CZ $c $t)   => `(Gate.CZ $c $t)
  | `(SWAP $a $b) => `(Gate.SWAP $a $b)
  | `(RX $q($theta)) => `(Gate.RX $q $theta)
  | `(RY $q($theta)) => `(Gate.RY $q $theta)
  | `(RZ $q($theta)) => `(Gate.RZ $q $theta)

/--
Constructor de circuito con notacion DSL: `circuit! { H q[0]; CNOT q[0] q[1] }`.
-/
syntax "circuit!" "{" sepBy(gate, ";") "}" : term

macro_rules
  | `(circuit! { $[$gates];* }) =>
      let gatesArr := gates.map fun g => `(Circuit.add $c $g)
      `(circuit fun $c:ident => $gatesArr*)

end Quantum4Lean.DSL
