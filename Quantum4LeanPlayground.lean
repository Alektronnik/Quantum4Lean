/-
Quantum4LeanPlayground.lean
Demostraciones avanzadas de Quantum4Lean. Estilo Apple Playgrounds.

  QuantumDiophantineSolver  -- Solver unificado: Pentalogia (6 casos)
  QuantumBealLargeScale     -- Beal a 19 qubits: busqueda de contraejemplos
  QuantumBealFFI            -- Beal FFI: 20-30 qubits via Apple Silicon/Metal 3
  QuantumTijdeman           -- Tijdeman cuantico: x^2 = y^3 + 1 via QAOA
  QuantumRiemann            -- Resonancia de Riemann: Primos + Cuantica
  QuantumTRDU               -- Teoria de Resonancia Dimensional Unificada

Uso:
  #eval Quantum4LeanPlayground.DiophantineSolver.report
  #eval Quantum4LeanPlayground.BealLargeScale.report
  #eval Quantum4LeanPlayground.Tijdeman.report
  #eval Quantum4LeanPlayground.Riemann.report
  #eval Quantum4LeanPlayground.TRDU.report
-/

import Quantum4LeanPlayground.QuantumBealLargeScale
import Quantum4LeanPlayground.QuantumDiophantineSolver
import Quantum4LeanPlayground.QuantumBealFFI
import Quantum4LeanPlayground.QuantumTijdeman
import Quantum4LeanPlayground.QuantumRiemann
import Quantum4LeanPlayground.QuantumTRDU
