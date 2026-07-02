/-
Quantum4Lean.lean
Modulo principal — Simulacion cuantica verificada en Lean 4.

Modulos activos (build autocontenido):
  - Quantum4LeanCore:       Qubit, Gate, Circuit (tipos dependientes)
  - Quantum4LeanError:      Errores tipados del motor
  - Quantum4LeanEngine:     Motor puro-Lean bit-exacto con CoreQU4TRIX
  - Quantum4LeanFFI:        Bindings @[extern] (declaraciones, no link)

Modulos pendientes de compatibilidad Lean 4.7.0:
  - Quantum4LeanDSL, Quantum4LeanVerify, Quantum4LeanUnitary
  - Quantum4LeanObservable, Quantum4LeanVQE, Quantum4LeanQAOA
  - Quantum4LeanSim, Quantum4LeanMonad, Quantum4LeanCompile (requieren FFI link)
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanError
import Quantum4Lean.Quantum4LeanEngine
import Quantum4Lean.Quantum4LeanFuzz
import Quantum4Lean.Quantum4LeanUnitary
import Quantum4Lean.Quantum4LeanObservable
import Quantum4Lean.Quantum4LeanVQE
import Quantum4Lean.Quantum4LeanQAOA

export Quantum4Lean (Qubit Gate Circuit StateVector
  executeSim executeSimProbs QuantumError
  FuzzConfig FuzzReport runFullSuite reportToString
  Complex UnitaryMatrix compile circuitsEquiv runAllTests
  Pauli PauliTerm PauliString Observable
  expect expectPauliString expectZ expectX expectY
  vqe isingAnsatz gradient parameterShiftGradient gradientDescentStep
  qaoaIsing qaoaIsingCircuit qaoaMixingLayer)
