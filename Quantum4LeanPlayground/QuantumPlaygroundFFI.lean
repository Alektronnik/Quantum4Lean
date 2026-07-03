/-
QuantumPlaygroundFFI.lean
Playground: Beal a 20-30 qubits via FFI (Apple Silicon / Metal 3).

Pipeline: polyToIsing -> FFI Engine (C++/Metal, hasta 30q) -> Medicion.

Requisito: libQuantum4LeanCPU.a o libQuantum4LeanMetal.a compilada.
  bash build_cpu_ffi.sh   (CPU)
  bash build_metal_ffi.sh (Metal GPU)
-/

import Quantum4Lean
import Quantum4Lean.Quantum4LeanFFI

open Quantum4Lean
open Quantum4Lean.FFI

namespace Quantum4LeanPlayground.FFI

-- Puertas (UInt32 para FFI directo)
def HADAMARD : UInt32 := 0
def X        : UInt32 := 1
def CNOT     : UInt32 := 6

/-- Inicializa motor FFI con N qubits. Devuelve (token, estado). --/
def ffiInit (n : Nat) : IO (UInt64 × FloatArray) := do
  let nU32 : UInt32 := n.toUInt32
  let memBytes <- quantum4LeanMemoryEstimate nU32
  IO.println ("FFI: " ++ toString n ++ " qubits, memoria: " ++ toString memBytes ++ " bytes")
  let dim : Nat := 1 <<< n
  let arr : Array Float := Array.replicate (2 * dim) 0.0
  let estado : FloatArray := FloatArray.mk arr
  let token <- quantum4LeanInit nU32 estado 12345
  if token == 0 then
    IO.println "Error: init devolvio token 0"
    IO.Process.exit 1
  return (token, estado)

/-- Finaliza motor. --/
def ffiFinalize (token : UInt64) : IO Unit := do
  let _ <- quantum4LeanFinalize token
  pure ()

/-- Aplica puerta. qa y qb son indices de qubit (Nat). qb=0 para puertas 1-qubit. --/
def ffiGate (token : UInt64) (estado : FloatArray) (t : UInt32) (qa qb : Nat)
    (param : Float := 0.0) : IO Unit := do
  let err <- quantum4LeanApplyGate token t (qa.toUInt32) (qb.toUInt32) param estado
  if err != 0 then IO.println ("Error gate " ++ toString t ++ " q" ++ toString qa ++ " q" ++ toString qb ++ ": " ++ toString err)

/-- Mide qubit k. Devuelve bit (0 o 1). -1 codificado como UInt32 max si error. --/
def ffiMeasure (token : UInt64) (estado : FloatArray) (q : Nat) : IO UInt32 := do
  quantum4LeanMeasure token (q.toUInt32) estado

/-- Demo: inicializa 20 qubits, aplica H a todos, mide. --/
def runDemo20 : IO String := do
  IO.println "=== FFI Demo: 20 qubits ==="
  let (token, estado) <- ffiInit 20
  for i in [0:12] do
    ffiGate token estado HADAMARD i 0
  let b0 <- ffiMeasure token estado 0
  let b11 <- ffiMeasure token estado 11
  ffiFinalize token
  return "FFI 20q OK. Muestras: q0=" ++ toString b0 ++ ", q11=" ++ toString b11

/-- Stress test: 30 qubits. --/
def runStress30 : IO String := do
  IO.println "=== FFI Stress: 30 qubits ==="
  let (token, estado) <- ffiInit 30
  for i in [0:30] do
    ffiGate token estado HADAMARD i 0
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

end Quantum4LeanPlayground.FFI
