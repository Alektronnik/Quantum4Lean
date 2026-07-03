/-
Quantum4LeanPlayground.lean
Demostraciones avanzadas de Quantum4Lean. Todas con prefijo QuantumPlayground.

  QuantumPlaygroundDiophantine  -- Solver diofantino (4 casos)
  QuantumPlaygroundFuzz          -- Fuzzer diofantino
  QuantumPlaygroundBeal         -- Conjetura de Beal (5 casos)
  QuantumPlaygroundFFI          -- FFI: 20-30 qubits via Metal 3
  QuantumPlaygroundTijdeman     -- Tijdeman cuantico: x^2 = y^3 + 1
  QuantumPlaygroundRiemann      -- Resonancia de Riemann
  QuantumPlaygroundTRDU         -- Teoria de Resonancia Dimensional Unificada

Uso:
  #eval Quantum4LeanPlayground.Diophantine.report
  #eval Quantum4LeanPlayground.Beal.report
  #eval Quantum4LeanPlayground.Tijdeman.report
-/

import Quantum4LeanPlayground.QuantumPlaygroundDiophantine
import Quantum4LeanPlayground.QuantumPlaygroundFuzz
import Quantum4LeanPlayground.QuantumPlaygroundBeal
import Quantum4LeanPlayground.QuantumPlaygroundFFI
import Quantum4LeanPlayground.QuantumPlaygroundTijdeman
import Quantum4LeanPlayground.QuantumPlaygroundRiemann
import Quantum4LeanPlayground.QuantumPlaygroundTRDU
