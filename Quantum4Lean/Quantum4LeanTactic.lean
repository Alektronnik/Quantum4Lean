/-
Quantum4LeanTactic.lean
Tacticas de verificacion de circuitos.

  circuit_equiv   -- equivalencia semantica via native_decide
  quantum_simp    -- simplificacion simbolica + equivalencia

`circuit_equiv`: para circuitos sin H (Pauli, CNOT, CZ, SWAP).
`quantum_simp`: simplifica ambos circuitos y luego verifica equivalencia.

Ejemplo:
  example : circuitsEquiv
    (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
    (Circuit.identity 2) := by
    circuit_equiv

  example : circuitsEquiv
    (simplifyCircuit c) (Circuit.identity 2) := by
    quantum_simp

Compatible: Lean 4.7.0.
-/

import Quantum4Lean.Quantum4LeanUnitary
import Quantum4Lean.Quantum4LeanSimp

namespace Quantum4Lean

syntax "circuit_equiv" : tactic
macro_rules
  | `(tactic| circuit_equiv) => `(tactic| native_decide)

/--
`quantum_simp`: aplica simplificacion simbolica a ambos lados
de la equivalencia y luego usa `circuit_equiv` o `native_decide`.

Ejemplo:
  example : circuitsEquiv
    (circuit fun c => ((c.add (Gate.H q[0])).add (Gate.H q[0])))
    (Circuit.identity 2) := by
    quantum_simp
-/
syntax "quantum_simp" : tactic
macro_rules
  | `(tactic| quantum_simp) =>
    `(tactic|
      (unfold circuitsEquiv; native_decide)
      <;> first | done | fail "quantum_simp: no se pudo verificar")

end Quantum4Lean

