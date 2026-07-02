/-
Quantum4LeanRunner.lean
Ejecutable de validacion: tests unitarios + fuzzer + equivalencias.

Uso:
  lake build && ./build/bin/quantum4lean-test

Retorna 0 si todos los tests pasan, 1 si hay fallos.
-/

import Quantum4Lean

open Quantum4Lean

def main : IO UInt32 := do
  let mut exitCode : UInt32 := 0

  -- ================================================================
  -- 1. Tests de matrices unitarias (circuitsEquiv)
  -- ================================================================
  IO.println "=== Unitary Matrix Tests ==="
  let unitaryResults := runAllTests
  if unitaryResults.isEmpty then
    IO.println "  OK: 8/8 identidades verificadas"
  else
    exitCode := 1
    IO.println s!"  FAIL: {unitaryResults.length} error(es)"
    for f in unitaryResults do
      IO.println s!"    - {f}"

  -- ================================================================
  -- 2. Fuzzer intra-Lean (Engine)
  -- ================================================================
  IO.println "\n=== Fuzz Tests ==="
  let fuzzCfg : FuzzConfig := { maxQubits := 5, numCircuits := 200, seed := 123456789 }
  let fuzzReport := runFullSuite fuzzCfg
  IO.println (reportToString fuzzReport)
  if ¬fuzzReport.allOk then
    exitCode := 1

  -- ================================================================
  -- 3. Resumen
  -- ================================================================
  IO.println "\n=============================================="
  if exitCode == 0 then
    IO.println "TODOS LOS TESTS OK - Quantum4Lean v0.4.0"
  else
    IO.println "HAY FALLOS - Revisar salida anterior"
  IO.println "=============================================="

  pure exitCode
