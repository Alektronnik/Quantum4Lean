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
  -- 3. Density Matrix + Noise (expect vs StateVector)
  -- ================================================================
  IO.println "\n=== Density Matrix Tests ==="
  match DensityMatrix.init 1 with
  | Except.error e =>
    exitCode := 1
    IO.println s!"  FAIL: DensityMatrix.init(1): {e}"
  | Except.ok rho0 =>
    let q0 : Qubit 1 := ⟨⟨0, by decide⟩⟩
    let zObs : Observable := { strings := [
      { coefficient := 1.0, terms := [{ pauli := .Z, qubit := 0 }] }
    ] }
    let xObs : Observable := { strings := [
      { coefficient := 1.0, terms := [{ pauli := .X, qubit := 0 }] }
    ] }
    let tests : List (String × Circuit 1 × Observable × Float) := [
      ("|0> Z", Circuit.identity 1, zObs, 1.0),
      ("|0> X", Circuit.identity 1, xObs, 0.0),
      ("|1> Z", { gates := [Gate.X q0] }, zObs, -1.0),
      ("|1> X", { gates := [Gate.X q0] }, xObs, 0.0),
      ("|+> Z", { gates := [Gate.H q0] }, zObs, 0.0),
      ("|+> X", { gates := [Gate.H q0] }, xObs, 1.0)
    ]
    let mut densityFails := 0
    for (name, circ, obs, expected) in tests do
      let rho := DensityMatrix.runCircuit rho0 circ
      let eD := DensityMatrix.expect rho obs
      let t := DensityMatrix.trace rho
      let diff := eD - expected
      let dAbs := if diff >= 0.0 then diff else -diff
      let tDiff := t - 1.0
      let tAbs := if tDiff >= 0.0 then tDiff else -tDiff
      if dAbs >= 1e-5 || tAbs >= 1e-5 then
        densityFails := densityFails + 1
        IO.println s!"  FAIL: {name}: expect={eD} (expected {expected}), trace={t}"
    if densityFails == 0 then
      IO.println s!"  OK: {tests.length}/{tests.length} DensityMatrix vs StateVector, trace=1"
    else
      exitCode := 1
      IO.println s!"  FAIL: {densityFails} error(es)"

  -- ================================================================
  -- 4. OpenQASM 3.0 export
  -- ================================================================
  IO.println "\n=== QASM Tests ==="
  let qb0 : Qubit 2 := ⟨⟨0, by decide⟩⟩
  let qb1 : Qubit 2 := ⟨⟨1, by decide⟩⟩
  let bell : Circuit 2 :=
    circuit fun c => (c.add (Gate.H qb0)).add (Gate.CNOT qb0 qb1)
  let qasm := Quantum4Lean.QASM.circuitToQASM bell "bell"
  let qasmOK := qasm.contains "OPENQASM 3.0" && qasm.contains "h q[0]" && qasm.contains "cx q[0], q[1]"
  if qasmOK then
    IO.println "  OK: Bell -> QASM 3.0 valido"
  else
    exitCode := 1
    IO.println "  FAIL: QASM invalido"

  -- ================================================================
  -- 5. Resumen
  -- ================================================================
  IO.println "\n=============================================="
  if exitCode == 0 then
    IO.println "TODOS LOS TESTS OK - Quantum4Lean v0.6.1"
  else
    IO.println "HAY FALLOS - Revisar salida anterior"
  IO.println "=============================================="

  pure exitCode
