/-
Quantum4LeanTactic.lean
Tactica de verificacion de circuitos.

  circuit_equiv   -- tactica para usar en `by` blocks

Funciona con `native_decide` para circuitos sin puertas H (solo
Pauli, CNOT, CZ, SWAP). Las matrices de puertas booleanas producen
amplitudes en {0, 1, -1} que `native_decide` reduce sin Float.sqrt.

Para circuitos con H, usar `#eval circuitsEquiv c1 c2` en su lugar.

Ejemplo:
  example : circuitsEquiv
    (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
    (Circuit.identity 2) := by
    circuit_equiv

Compatible: Lean 4.7.0.
-/

import Quantum4Lean.Quantum4LeanUnitary

namespace Quantum4Lean

syntax "circuit_equiv" : tactic

macro_rules
  | `(tactic| circuit_equiv) => `(tactic| native_decide)

end Quantum4Lean
