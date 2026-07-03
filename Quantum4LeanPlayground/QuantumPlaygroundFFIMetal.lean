/-
QuantumPlaygroundFFIMetal.lean
Entry point para ejecutable FFI con Metal GPU.
Importa el mismo codigo de demo que la version CPU.
-/

import Quantum4LeanPlayground.QuantumPlaygroundFFI

/-- Main ejecutable FFI Metal. --/
def main : IO Unit := do
  IO.println "Quantum4Lean FFI — Metal GPU (Apple Silicon)"
  let r <- Quantum4LeanPlayground.FFI.report
  IO.println r
