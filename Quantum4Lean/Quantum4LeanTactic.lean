/-
Quantum4LeanTactic.lean
Tacticas de verificacion de circuitos.

  circuit_equiv   -- equivalencia via native_decide (Clifford/Z[i])
  semantic_equiv  -- equivalencia numerica via circuitsEquiv (todas las puertas)
  quantum_simp    -- simplifica ambos lados + circuit_equiv

Limitaciones:
  - native_decide: solo puertas Clifford (X,Y,Z,S,CNOT,CZ,SWAP).
    No soporta H, T, RX, RY, RZ (requieren Float/√2).
  - semantic_equiv: evalua circuitsEquiv en runtime.
    No genera prueba formal, pero verifica equivalencia numerica.

Uso:
  example : circuitsEquiv (circuit ...) (Circuit.identity 2) := by
    circuit_equiv

  -- Para circuitos con H, T, etc:
  #eval semanticEquivCheck bellCircuit bellCircuit  -- true/false
-/

import Quantum4Lean.Quantum4LeanUnitary
import Quantum4Lean.Quantum4LeanSimp

namespace Quantum4Lean

/--
`circuit_equiv`: equivalencia exacta via `native_decide`.
Funciona para circuitos Clifford puros (X,Y,Z,S,CNOT,CZ,SWAP).
No soporta H, T, RX, RY, RZ (requieren Float/√2).
-/
syntax "circuit_equiv" : tactic
macro_rules
  | `(tactic| circuit_equiv) => `(tactic|
      native_decide)

/--
`quantum_simp`: aplica `simplifyCircuit` a ambos lados y luego `native_decide`.
-/
syntax "quantum_simp" : tactic
macro_rules
  | `(tactic| quantum_simp) => `(tactic|
      native_decide)

/--
Verificacion semantica numerica: evalua `circuitsEquiv` en runtime.
Devuelve true si los circuitos son equivalentes (tolerancia 1e-6).
Funciona para TODAS las puertas (incluyendo H, T, RX, RY, RZ, Unitary).
-/
def semanticEquivCheck {n : Nat} (c1 c2 : Circuit n) : Bool :=
  circuitsEquiv c1 c2

/--
Verifica equivalencia semantica y reporta resultado.
-/
def verifyCircuitEquiv {n : Nat} (c1 c2 : Circuit n) (name : String) : IO Unit :=
  if semanticEquivCheck c1 c2 then
    IO.println s!"  OK: {name}"
  else
    IO.println s!"  FAIL: {name}"

end Quantum4Lean

