/-
QuantumPlaygroundFFICPU.lean
Entry point para ejecutable FFI CPU-only.
-/

import Quantum4LeanPlayground.QuantumPlaygroundFFI

/-- Main ejecutable FFI CPU. --/
def main : IO Unit := do
  IO.println "Quantum4Lean FFI — CPU-only"
  let r <- Quantum4LeanPlayground.FFI.report
  IO.println r
