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
  Quantum4LeanDSL         Macro circuit!, q[i], Shortcuts
  Quantum4LeanTactic      circuit_equiv, quantum_simp
  Quantum4LeanPolynomial  Traductor polinomico (monomios <= 3)
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanError
import Quantum4Lean.Quantum4LeanEngine
import Quantum4Lean.Quantum4LeanFuzz
import Quantum4Lean.Quantum4LeanUnitary
import Quantum4Lean.Quantum4LeanSimp
import Quantum4Lean.Quantum4LeanTranspile
import Quantum4Lean.Quantum4LeanClifford
import Quantum4Lean.Quantum4LeanDiophantine
import Quantum4Lean.Quantum4LeanObservable
import Quantum4Lean.Quantum4LeanVQE
import Quantum4Lean.Quantum4LeanQAOA
import Quantum4Lean.Quantum4LeanDSL
import Quantum4Lean.Quantum4LeanTactic
import Quantum4Lean.Quantum4LeanPolynomial
import Quantum4Lean.Quantum4LeanSolver

export Quantum4Lean (Qubit Gate Circuit StateVector
  executeSim executeSimProbs
  FuzzConfig FuzzReport runFullSuite reportToString
  Complex UnitaryMatrix compile circuitsEquiv
  CliffordAmplitude CliffordMatrix compileClifford cliffordEquiv
  Pauli PauliString Observable
  expect expectPauliString expectZ expectX expectY
  vqe isingAnsatz gradient parameterShiftGradient adamVQE adamStep
  qaoaIsing qaoaIsingCircuit qaoaMixingLayer
  simplifyCircuit simplificationSavings
  optimizeCircuit optimizationSavings
  DiophantineVar Diophantine DiophantineResult
  toIsing diophantineSolve checkSolution decodeValues
  Monomial PolyEquation PolyResult
  expandVarPower expandMonomial polyToIsing polyTotalQubits
  intToFloat decodeState evalCost bruteForceSolve)

-- DSL y tacticas disponibles via `import Quantum4Lean` automaticamente
