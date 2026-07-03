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
  -- 5. Quantum Chemistry (Jordan-Wigner)
  -- ================================================================
  IO.println "\n=== Chemistry Tests ==="
  -- Test H2 Observable generation
  let h2 := h2Observable
  let h2ok := h2.strings.length >= 100  -- Debe tener muchos terminos
  if h2ok then
    IO.println s!"  OK: H2 -> {h2.strings.length} PauliStrings (4 qubits)"
  else
    exitCode := 1
    IO.println s!"  FAIL: H2 solo tiene {h2.strings.length} PauliStrings"

  -- Test LiH Observable generation
  let lih := lihObservable
  let lihok := lih.strings.length >= 10
  if lihok then
    IO.println s!"  OK: LiH -> {lih.strings.length} PauliStrings (6 qubits)"
  else
    exitCode := 1
    IO.println s!"  FAIL: LiH solo tiene {lih.strings.length} PauliStrings"

  -- Test Jordan-Wigner a_0 operator
  let a0 := jwSingle 0 .annihilation
  let a0ok := a0.length == 2
  if a0ok then
    IO.println "  OK: jwSingle(a_0) = 2 PauliStrings"
  else
    exitCode := 1
    IO.println s!"  FAIL: jwSingle(a_0) = {a0.length}"

  -- Test number operator n_0 = a_0^† a_0
  let n0 := jwTermToObservable { operators := [(0, .creation), (0, .annihilation)] }
  let n0ok := n0.strings.length >= 2
  if n0ok then
    IO.println s!"  OK: n_0 -> {n0.strings.length} PauliStrings"
  else
    exitCode := 1
    IO.println s!"  FAIL: n_0 solo tiene {n0.strings.length}"

  -- Test expectation on Hartree-Fock state
  match StateVector.init 4 with
  | Except.error e =>
    exitCode := 1
    IO.println s!"  FAIL: StateVector.init(4): {e}"
  | Except.ok sv =>
    let q0 : Qubit 4 := ⟨⟨0, by decide⟩⟩
    let q1 : Qubit 4 := ⟨⟨1, by decide⟩⟩
    let sv := StateVector.applyGate (StateVector.applyGate sv (Gate.X q0)) (Gate.X q1)
    let eHF := expect sv h2
    let eOk := eHF < 0.0  -- Bound state: energy must be negative
    if eOk then
      IO.println s!"  OK: E(HF) = {eHF} (negativa, estado ligado)"
    else
      exitCode := 1
      IO.println s!"  FAIL: E(HF) = {eHF} (deberia ser negativa)"

  -- ================================================================
  -- 6. Resumen
  -- ================================================================
  IO.println "\n=============================================="
  if exitCode == 0 then
    IO.println "TODOS LOS TESTS OK - Quantum4Lean v0.6.1"
  else
    IO.println "HAY FALLOS - Revisar salida anterior"
  IO.println "=============================================="

  pure exitCode
