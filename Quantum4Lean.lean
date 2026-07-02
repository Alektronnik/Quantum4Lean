/-
Quantum4Lean — Computacion Cuantica Verificada en Lean 4.

Motor puro-Lean bit-exacto con CoreQU4TRIX (C++/Metal).
Stack NISQ completo. Cero dependencias externas.

Modulos activos:
  Quantum4LeanCore        Qubit, Gate, Circuit (tipos dependientes)
  Quantum4LeanError       QuantumError (inductivo)
  Quantum4LeanEngine      StateVector, simulador bit-exacto
  Quantum4LeanFuzz        Fuzzer intra-Lean
  Quantum4LeanUnitary     Complex, UnitaryMatrix, circuitsEquiv
  Quantum4LeanObservable  PauliString, Observable, expect
  Quantum4LeanVQE         Parameter-shift, gradient, VQE
  Quantum4LeanQAOA        Mixing layer, Ising cost layer

Modulos conservados para futuro:
  Quantum4LeanDSL         Macro circuit! (pendiente compatibilidad 4.7.0)
  Quantum4LeanVerify      Identidades algebraicas (pendiente compatibilidad 4.7.0)
  Quantum4LeanFFI         Bindings @[extern] (requiere QuantumKitCore)
  Quantum4LeanSim         Runner FFI (requiere FFI)
  Quantum4LeanMonad       Monada cuantica (requiere FFI)
  Quantum4LeanCompile     Circuit -> QuantumM (requiere Monad)
  Quantum4LeanExamples    Bell, GHZ, Grover, QFT (requiere Sim)
  Quantum4LeanTest        55 aserciones (requiere Unitary activo)
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
  executeSim executeSimProbs
  FuzzConfig FuzzReport runFullSuite reportToString
  Complex UnitaryMatrix compile circuitsEquiv
  Pauli PauliString Observable
  expect expectPauliString expectZ expectX expectY
  vqe isingAnsatz gradient parameterShiftGradient
  qaoaIsing qaoaIsingCircuit qaoaMixingLayer)
