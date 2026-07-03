/-
QuantumPlaygroundFFI.lean
Playground: Beal a 20-30 qubits via FFI (Apple Silicon / Metal 3).

Pipeline: polyToIsing -> FFI Engine (C++/Metal, hasta 30q) -> Medicion.

Requisito: libQuantum4LeanCPU.a o libQuantum4LeanMetal.a compilada.
  bash buildCPU.sh   (CPU)
  bash buildMetal.sh (Metal GPU)
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

/-- Aplica puerta. Devuelve codigo de error (0 = exito). --/
def ffiGate (token : UInt64) (estado : FloatArray) (t : UInt32) (qa qb : Nat)
    (param : Float := 0.0) : IO UInt32 := do
  quantum4LeanApplyGate token t (qa.toUInt32) (qb.toUInt32) param estado

/-- Mide qubit k. Devuelve bit (0 o 1). 0xFFFFFFFF si error. --/
def ffiMeasure (token : UInt64) (estado : FloatArray) (q : Nat) : IO UInt32 := do
  quantum4LeanMeasure token (q.toUInt32) estado

/-- Demo: inicializa 20 qubits, aplica H a todos, mide. --/
def runDemo20 : IO String := do
  IO.println "=== FFI Demo: 20 qubits ==="
  let (token, estado) <- ffiInit 20
  let mut errCount : Nat := 0
  for i in [0:12] do
    let err <- ffiGate token estado HADAMARD i 0
    if err != 0 then errCount := errCount + 1
  let b0 <- ffiMeasure token estado 0
  let b11 <- ffiMeasure token estado 11
  ffiFinalize token
  if errCount > 0 then
    return s!"FFI 20q FAIL: {errCount} errores de puerta"
  return s!"FFI 20q OK. Muestras: q0={b0}, q11={b11}"

/--
Stress test: 25 qubits (~512 MB). Para 30 qubits se necesitan ~34 GB
de RAM unificada (Apple Silicon M2 Max/M3 Ultra).
-/
def runStress25 : IO String := do
  IO.println "=== FFI Stress: 25 qubits (~512 MB) ==="
  let (token, estado) <- ffiInit 25
  let mut errCount : Nat := 0
  for i in [0:25] do
    let err <- ffiGate token estado HADAMARD i 0
    if err != 0 then errCount := errCount + 1
  let b0 <- ffiMeasure token estado 0
  let b12 <- ffiMeasure token estado 12
  let b24 <- ffiMeasure token estado 24
  ffiFinalize token
  if errCount > 0 then
    return s!"FFI 25q FAIL: {errCount} errores de puerta"
  return s!"FFI 25q OK. Muestras: q0={b0}, q12={b12}, q24={b24}"

/-- Reporte completo. --/
def report : IO String := do
  let d20 <- runDemo20
  let s25 <- runStress25
  return d20 ++ "\n\n" ++ s25

end Quantum4LeanPlayground.FFI
