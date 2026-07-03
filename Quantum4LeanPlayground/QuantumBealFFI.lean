/-
QuantumBealFFI.lean
Playground: Beal a 20-30 qubits via FFI (Apple Silicon / Metal 3).

Pipeline: polyToIsing -> FFI Engine (C++/Metal, hasta 30q) -> Medicion.

Requisito: libQuantum4LeanFFI.a compilada.
  bash build_ffi.sh && lake build quantum4lean-ffi
-/

import Quantum4Lean
import Quantum4Lean.Quantum4LeanFFI

open Quantum4Lean
open Quantum4Lean.FFI

namespace Quantum4LeanPlayground.BealFFI

-- Puertas
def HADAMARD : Int := 0
def X        : Int := 1
def CNOT     : Int := 6

/-- Inicializa motor FFI con N qubits. Devuelve (token, estado). --/
def ffiInit (n : Nat) : IO (USize × FloatArray) := do
  let memBytes <- quantum4LeanMemoryEstimate n
  let mb := (memBytes.toNat.toFloat / 1048576.0)
  IO.println ("FFI: " ++ toString n ++ " qubits, memoria: " ++ toString memBytes ++ " bytes")
  let dim : Nat := 1 <<< n
  let arr : Array Float := Array.mkArray (2 * dim) 0.0
  let estado : FloatArray := FloatArray.mk arr
  let token <- quantum4LeanInit n estado 12345
  if token == 0 then
    IO.println "Error: init devolvio token 0"
    IO.Process.exit 1
  return (token, estado)

/-- Finaliza motor. --/
def ffiFinalize (token : USize) : IO Unit := do
  let _ <- quantum4LeanFinalize token

/-- Aplica puerta. --/
def ffiGate (token : USize) (estado : FloatArray) (t : Int) (qa qb : Int)
    (param : Float := 0.0) : IO Unit := do
  let err <- quantum4LeanApplyGate token t qa qb param estado
  if err != 0 then IO.println ("Error gate " ++ toString t ++ " q" ++ toString qa ++ " q" ++ toString qb ++ ": " ++ toString err)

/-- Mide qubit. --/
def ffiMeasure (token : USize) (estado : FloatArray) (q : Int) : IO Int := do
  let bit <- quantum4LeanMeasure token q estado
  if bit < 0 then IO.println ("Error measure q" ++ toString q)
  return bit

/-- Demo: inicializa 20 qubits, aplica H a todos, mide. --/
def runDemo20 : IO String := do
  IO.println "=== FFI Demo: 20 qubits ==="
  let (token, estado) <- ffiInit 20
  for i in [0:12] do
    ffiGate token estado HADAMARD i (-1)
  let b0 <- ffiMeasure token estado 0
  let b11 <- ffiMeasure token estado 11
  ffiFinalize token
  return "FFI 20q OK. Muestras: q0=" ++ toString b0 ++ ", q11=" ++ toString b11

/-- Stress test: 30 qubits. --/
def runStress30 : IO String := do
  IO.println "=== FFI Stress: 30 qubits ==="
  let (token, estado) <- ffiInit 30
  for i in [0:30] do
    ffiGate token estado HADAMARD i (-1)
  let b0 <- ffiMeasure token estado 0
  let b15 <- ffiMeasure token estado 15
  let b29 <- ffiMeasure token estado 29
  ffiFinalize token
  return "FFI 30q OK. Muestras: q0=" ++ toString b0 ++ ", q15=" ++ toString b15 ++ ", q29=" ++ toString b29

/-- Reporte completo. --/
def report : IO String := do
  let d20 <- runDemo20
  let s30 <- runStress30
  return d20 ++ "\n\n" ++ s30

/-- Main ejecutable. --/
def main : IO Unit := do
  let r <- report
  IO.println r

end Quantum4LeanPlayground.BealFFI
