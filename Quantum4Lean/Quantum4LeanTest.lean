/-
Quantum4LeanTest.lean
Suite de tests para modulos puros de Quantum4Lean (sin FFI).

Prueba:
  - Complex: aritmetica, conjugado, norma
  - UnitaryMatrix: identidad, multiplicacion, traza, adjunta
  - Gate: toCode, qubits
  - Circuit: depth, comp, repeat
  - QuantumError: fromCode, toString
  - Observable: Ising, Heisenberg (construccion)

NO necesita QuantumKitCore compilado. Son tests de logica pura.
-/

import Quantum4Lean
import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanError
import Quantum4Lean.Quantum4LeanUnitary
import Quantum4Lean.Quantum4LeanObservable
import Quantum4Lean.Quantum4LeanVerify

open Quantum4Lean

-- ===================================================================
-- Complex
-- ===================================================================

#eval Complex.zero
#eval Complex.one
#eval Complex.one + Complex.one
#eval Complex.one * Complex.one

example : Complex.add Complex.zero Complex.one = Complex.one := rfl
example : Complex.mul Complex.one Complex.one = Complex.one := rfl
example : Complex.norm2 Complex.one = 1.0 := rfl
example : Complex.norm2 Complex.zero = 0.0 := rfl
example : Complex.conj (Complex.mk 3.0 4.0) = Complex.mk 3.0 (-4.0) := rfl

-- ===================================================================
-- UnitaryMatrix
-- ===================================================================

def testMatrix2 : UnitaryMatrix 1 := UnitaryMatrix.identity 1

#eval UnitaryMatrix.size testMatrix2
#eval UnitaryMatrix.get testMatrix2 0 0
#eval UnitaryMatrix.get testMatrix2 0 1
#eval UnitaryMatrix.get testMatrix2 1 1

example : UnitaryMatrix.size testMatrix2 = 2 := rfl
example : UnitaryMatrix.get testMatrix2 0 0 = Complex.one := rfl
example : UnitaryMatrix.get testMatrix2 0 1 = Complex.zero := rfl
example : UnitaryMatrix.get testMatrix2 1 1 = Complex.one := rfl

-- Traza de identidad 2x2 = 2+0i
example : UnitaryMatrix.trace testMatrix2 = Complex.mk 2.0 0.0 := rfl

-- Distancia de traza consigo misma = 0
example : UnitaryMatrix.traceDistance testMatrix2 testMatrix2 = 0.0 := by
  nativeDecide

-- Identidad 2-qubit (4x4)
def testMatrix4 : UnitaryMatrix 2 := UnitaryMatrix.identity 2
example : UnitaryMatrix.size testMatrix4 = 4 := rfl
example : UnitaryMatrix.trace testMatrix4 = Complex.mk 4.0 0.0 := rfl

-- ===================================================================
-- Gate
-- ===================================================================

def q0 : Qubit 2 := ⟨⟨0, by decide⟩⟩
def q1 : Qubit 2 := ⟨⟨1, by decide⟩⟩

example : Gate.H q0 |>.toCode = 0 := rfl
example : Gate.X q0 |>.toCode = 1 := rfl
example : Gate.Y q0 |>.toCode = 2 := rfl
example : Gate.Z q0 |>.toCode = 3 := rfl
example : Gate.S q0 |>.toCode = 4 := rfl
example : Gate.T q0 |>.toCode = 5 := rfl
example : Gate.CNOT q0 q1 |>.toCode = 6 := rfl
example : Gate.CZ q0 q1 |>.toCode = 7 := rfl
example : Gate.SWAP q0 q1 |>.toCode = 8 := rfl
example : Gate.RX q0 0.5 |>.toCode = 9 := rfl
example : Gate.RY q0 0.5 |>.toCode = 10 := rfl
example : Gate.RZ q0 0.5 |>.toCode = 11 := rfl

example : (Gate.H q0).qubits = [q0] := rfl
example : (Gate.CNOT q0 q1).qubits = [q0, q1] := rfl

-- ===================================================================
-- Circuit
-- ===================================================================

def bellCircuit : Circuit 2 :=
  circuit fun c => (c.add (Gate.H q0)).add (Gate.CNOT q0 q1)

example : bellCircuit.depth = 2 := rfl
example : bellCircuit.gates.length = 2 := rfl

def emptyCircuit : Circuit 3 := Circuit.identity 3
example : emptyCircuit.depth = 0 := rfl

def repeatedCircuit : Circuit 2 := bellCircuit.repeat 3
example : repeatedCircuit.depth = 6 := rfl

def composedCircuit : Circuit 2 := bellCircuit.comp bellCircuit
example : composedCircuit.depth = 4 := rfl

-- ===================================================================
-- QuantumError
-- ===================================================================

example : QuantumError.fromCode 0 = QuantumError.noInit := by
  nativeDecide

example : QuantumError.fromCode 203 = QuantumError.qubitsMax 0 0 := rfl
example : QuantumError.fromCode 205 = QuantumError.nullPointer := rfl
example : QuantumError.fromCode 208 = QuantumError.memoria 0 := rfl

example : (QuantumError.qubitsMax 35 30).toString = "35 qubits solicitados, maximo 30" := rfl

-- ===================================================================
-- Observable
-- ===================================================================

def testIsing : Observable := Observable.ising1D 4 1.0 0.5
example : testIsing.strings.length = 7 := rfl  -- 3 ZZ pairs + 4 X fields

def testHeisenberg : Observable := Observable.heisenberg1D 3 1.0
example : testHeisenberg.strings.length = 6 := rfl  -- 2*3 = 6 terms (XX,YY,ZZ for 2 pairs)

-- ===================================================================
-- Verificacion semantica
-- ===================================================================

example : circuitsEquiv (Circuit.identity 1) (Circuit.identity 1) := by
  nativeDecide

example {n : Nat} (h : n >= 1) :
    let q : Qubit n := ⟨⟨0, by omega⟩⟩
    circuitsEquiv
      (circuit fun c => (c.add (Gate.H q)).add (Gate.H q))
      (Circuit.identity n) := by
  nativeDecide

example {n : Nat} (h : n >= 1) :
    let q : Qubit n := ⟨⟨0, by omega⟩⟩
    circuitsEquiv
      (circuit fun c => (c.add (Gate.X q)).add (Gate.X q))
      (Circuit.identity n) := by
  nativeDecide

example {n : Nat} (h : n >= 2) :
    let q0 : Qubit n := ⟨⟨0, by omega⟩⟩
    let q1 : Qubit n := ⟨⟨1, by omega⟩⟩
    circuitsEquiv
      (circuit fun c => (c.add (Gate.CNOT q0 q1)).add (Gate.CNOT q0 q1))
      (Circuit.identity n) := by
  nativeDecide

example {n : Nat} (h : n >= 2) :
    let q0 : Qubit n := ⟨⟨0, by omega⟩⟩
    let q1 : Qubit n := ⟨⟨1, by omega⟩⟩
    circuitsEquiv
      (circuit fun c =>
        ((c.add (Gate.CNOT q0 q1)).add (Gate.CNOT q1 q0)).add (Gate.CNOT q0 q1))
      (circuit fun c => c.add (Gate.SWAP q0 q1)) := by
  nativeDecide

-- ===================================================================
-- Verificacion algebraica
-- ===================================================================

example (q : Qubit 3) : (hadamardPairIdentity q).depth = 2 := rfl
example : ghzCircuit.depth = 3 := rfl

-- Cancelacion de pares H*H
example : (bellCircuit.cancelHadamardPairs).depth <= bellCircuit.depth := by
  simp [Circuit.cancelHadamardPairs]
