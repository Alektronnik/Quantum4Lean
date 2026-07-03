/-
Quantum4LeanTactic.lean
Tacticas de verificacion de circuitos.

  circuit_equiv   -- equivalencia via native_decide (Clifford/Z[i])
  quantum_simp    -- simplifica ambos lados via simplifyCircuit + semanticEquivCheck
  semantic_equiv  -- equivalencia numerica via circuitsEquiv (todas las puertas)

Limitaciones:
  - circuit_equiv: solo puertas Clifford (X,Y,Z,S,CNOT,CZ,SWAP).
    Las puertas H, T, RX, RY, RZ involucran Float/√2 que native_decide
    no puede manejar por ser valores irracionales.
  - quantum_simp: aplica simplifyCircuit (reescritura algebraica de circuitos)
    y verifica via semanticEquivCheck (prueba numerica, no formal).
  - semantic_equiv: evalua circuitsEquiv en runtime con tolerancia 1e-6.
    No genera prueba formal, pero verifica equivalencia numerica.

Uso:
  example : circuitsEquiv (circuit ...) (Circuit.identity 2) := by
    circuit_equiv

  -- Para circuitos con H, T, etc:
  #eval semanticEquivCheck bellCircuit bellCircuit  -- true/false

  -- Simplificar y verificar en un paso:
  #eval quantumEquivCheck c1 c2  -- true/false si simplify(c1) ~ simplify(c2)
-/

import Quantum4Lean.Quantum4LeanUnitary
import Quantum4Lean.Quantum4LeanSimp

namespace Quantum4Lean

/--
`circuit_equiv`: equivalencia exacta via `native_decide`.
Funciona para circuitos Clifford puros (X,Y,Z,S,CNOT,CZ,SWAP).
No soporta H, T, RX, RY, RZ (requieren Float/sqrt(2)).
-/
syntax "circuit_equiv" : tactic
macro_rules
  | `(tactic| circuit_equiv) => `(tactic|
      native_decide)

/--
`quantum_simp`: simplifica ambos circuitos con `simplifyCircuit`
y verifica equivalencia numerica con `circuitsEquiv`.

Para verificacion formal de circuitos Clifford, usar `circuit_equiv`.
Para verificacion numerica de cualquier circuito, usar `semanticEquivCheck`.
-/
def quantumEquivCheck {n : Nat} (c1 c2 : Circuit n) : Bool :=
  let s1 := simplifyCircuit c1
  let s2 := simplifyCircuit c2
  circuitsEquiv s1 s2

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

