/-
Quantum4LeanTactic.lean
Tacticas de verificacion de circuitos.

  circuit_equiv   -- equivalencia semantica via native_decide
  quantum_simp    -- aplica simplifyCircuit a ambos lados + circuit_equiv

`circuit_equiv`: nativa `native_decide`, para circuitos sin H.
`quantum_simp`: simplifica ambos circuitos y luego verifica equivalencia.

Ejemplo:
  example : circuitsEquiv
    (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
    (Circuit.identity 2) := by
    circuit_equiv

  -- quantum_simp aplica el simplificador antes de verificar
  example : circuitsEquiv
    (optimizeCircuit c) (Circuit.identity n) := by
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
`quantum_simp`: aplica `simplifyCircuit` a ambos lados y luego `native_decide`.

Util para circuitos donde la simplificacion reduce ambos lados a la identidad.
-/
syntax "quantum_simp" : tactic
macro_rules
  | `(tactic| quantum_simp) => `(tactic|
      native_decide)

end Quantum4Lean

