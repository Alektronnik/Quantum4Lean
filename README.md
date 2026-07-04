# Quantum4Lean

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.21197538.svg)](https://doi.org/10.5281/zenodo.21197538)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Lean 4](https://img.shields.io/badge/Lean-4.31.0-green.svg)](https://leanprover.github.io/)

Verified quantum computing in Lean 4. Bit-exact pure-Lean engine. Complete NISQ stack: StateVector, Observables, adaptive VQE, QAOA, Density Matrix + noise, Jordan-Wigner, quantum chemistry (exact H2), polynomial expansion to arbitrary degree, discrete topology with Hodge and Betti, declarative DSL, OpenQASM 3.0 exporter (including Gate.Unitary), verification tactics, intra-Lean fuzzer, FFI bridge to C++ CPU and Metal GPU engine for up to 30 qubits.

Status: v0.8.0 — 24 library modules, 7 playgrounds, 12 verified theorems, 208+ tests.

## Build

```bash
cd Quantum4Lean
lake build quantum4lean-test && .lake/build/bin/quantum4lean-test
```

Zero external dependencies. Requires Lean 4.31.0 (`lean-toolchain`).

## Architecture

```
Quantum4Lean (24 modules)
  Core, Error, Engine, Fuzz, Unitary, Observable, VQE, QAOA,
  Diophantine, Polynomial, Solver, Simp, Transpile, Clifford,
  Verify, DSL, Tactic, FFI, QASM, Density, Chemistry, Topology,
  Ansatz, Runner

Quantum4LeanPlayground (7 demos)
  Diophantine, Beal, Tijdeman, Riemann, TRDU, FFI, Mobius

Quantum4LeanBridge (C bridge)
  Quantum4LeanFFI.c/.h  -- Stable C API for FFI
buildCPU.sh buildFFI.sh buildMetal.sh  -- CPU/FFI/Metal build scripts
```

## Quick Start

```lean
import Quantum4Lean
open Quantum4Lean
open Quantum4Lean.DSL.Shortcuts

-- Bell circuit with declarative DSL
def bell : Circuit 2 := circuit! {
  H q[0];
  CNOT q[0] q[1]
}

-- Run on the pure-Lean engine
#eval executeSim bell
-- Except.ok [1]

-- Verify semantic equivalence
#eval circuitsEquiv bell bell
-- true

-- circuit_equiv tactic (Clifford, no H)
example : circuitsEquiv
  (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
  (Circuit.identity 2) := by
  circuit_equiv
```

## API

| Category | Symbols |
|----------|---------|
| Types | `Qubit`, `Gate`, `Circuit`, `StateVector`, `Complex`, `UnitaryMatrix` |
| Pauli | `Pauli`, `PauliString`, `Observable` |
| Execution | `executeSim`, `executeSimProbs` |
| Expectation | `expect`, `expectPauliString`, `expectZ`, `expectX`, `expectY` |
| VQE | `vqe`, `adamVQE`, `isingAnsatz`, `gradient`, `parameterShiftGradient` |
| QAOA | `qaoaIsing`, `qaoaIsingCircuit`, `qaoaMixingLayer` |
| Verification | `compile`, `compileSafe`, `validateCircuit`, `circuitsEquiv`, `circuitsEquivSafe`, `circuit_equiv` (tactic) |
| Clifford | `cliffordEquiv`, `CliffordAmplitude`, `CliffordMatrix` |
| Optimization | `simplifyCircuit`, `optimizeCircuit`, `verifyOptimization`, `quantumEquivCheck` |
| DSL | `circuit! { ... }`, `q[i]`, `H`, `X`, `CNOT`, ... (Shortcuts) |
| Circuit Fuzzer | `FuzzConfig`, `FuzzReport`, `runFullSuite` |
| Diophantine Fuzzer | `generateWithSolution`, `runDiophantineFuzz`, `diophantineFuzzReport` |
| Diophantine | `Diophantine`, `toIsing`, `diophantineSolve`, `checkSolution` |
| Polynomial | `Monomial`, `PolyEquation`, `polyToIsing`, `expandVarPower` (arbitrary degree) |
| Chemistry | `h2ExactObservable`, `h2Observable`, `lihObservable`, `fermionToObservable` |
| Topology | `harmonicProjector`, `bettiNumber`, `FirmaPrima`, `topologicalKappa` |
| FFI | `quantum4LeanInit`, `quantum4LeanApplyGate`, `quantum4LeanMeasure` |
| QASM | `circuitToQASM`, `exportCircuit`, `printCircuit` (supports Gate.Unitary) |

## DSL

```lean
-- Full names (always available)
def bell : Circuit 2 := circuit! {
  Gate.H q[0];
  Gate.CNOT q[0] q[1]
}

-- Short aliases (requires `open Quantum4Lean.DSL.Shortcuts`)
def ghz3 : Circuit 3 := circuit! {
  H q[0];
  CNOT q[0] q[1];
  CNOT q[1] q[2]
}
```

## circuit_equiv Tactic

```lean
-- Works with native_decide for circuits without H (Pauli, CNOT, CZ, SWAP)
example : circuitsEquiv
  (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
  (Circuit.identity 2) := by
  circuit_equiv

-- For circuits with H, use #eval
#eval circuitsEquiv
  (circuit fun c => (c.add (Gate.H q[0])).add (Gate.H q[0]))
  (Circuit.identity 2)
```

## Clifford Verification (Z[i])

Formal proof of equivalences for the 7 Clifford gates (X, Y, Z, S, CNOT, CZ, SWAP) using integer arithmetic in Z[i]. No Float, no √2. 8 theorems proven with `native_decide`.

```lean
-- Formally proven (0 sorry)
theorem rule_X_X_eq_I : cliffordEquiv c (Circuit.identity 2) := by
  native_decide

-- Runtime verification for any Clifford circuit
#eval cliffordEquiv myCircuit otherCircuit
```

## Diophantine Translator

Linear Diophantine equations (ax + by = c) to Ising Hamiltonians.

```lean
import Quantum4Lean

let eq : Diophantine := {
  vars := [
    { coeff := 3, name := "x", bits := 4 },
    { coeff := 5, name := "y", bits := 4 }
  ],
  constant := 22
}

let H := toIsing eq 4
let result := diophantineSolve eq 4
#eval checkSolution eq [("x", 4), ("y", 2)]  -- true (3*4 + 5*2 = 22)
```

## Polynomial Translator

Polynomial expansion to any degree n. Z-mask representation with XOR for Z*Z=I.
Generalizes the linear translator to multivariate monomials.
Supports equations such as x^2 = y^3 + 1 (Tijdeman), x^3 + y^3 = z^3 (Fermat n=3), etc.

```lean
import Quantum4Lean

-- Equation: x^2 - y^3 = 1
let eq : PolyEquation := {
  monomials := [
    { coefficient := 1,  exponents := [(0, 2)] },
    { coefficient := -1, exponents := [(1, 3)] }
  ],
  constant := 1,
  varBits := [4, 4]
}

let H := polyToIsing eq    -- Ising Observable
let n := polyTotalQubits eq -- 8 qubits
```

## FFI: C++/Metal Bridge (Apple Silicon)

External engine with GPU acceleration via Metal 3. CPU: up to 25 qubits (~1 GB). Metal GPU: Apple Silicon M2/M3 with unified memory.

Requires `../QuantumKit` (sibling repository with the C++ engine). Setup:

```bash
bash setup.sh          # verify QuantumKit + build libs
# or step by step:
bash buildCPU.sh       # libQuantum4LeanCPU.a
bash buildMetal.sh     # libQuantum4LeanMetal.a

# Run CPU
LEAN_CC=clang lake build quantum4lean-ffi
.lake/build/bin/quantum4lean-ffi

# Run Metal GPU
LEAN_CC=clang lake build quantum4lean-ffi-metal
.lake/build/bin/quantum4lean-ffi-metal
```

```lean
import Quantum4Lean
open Quantum4Lean

-- FFI functions are in Quantum4Lean.FFI and helpers in the playground
-- Precompiled executable: .lake/build/bin/quantum4lean-ffi
```

FFI Architecture: Lean (`@[extern]` + `unsafe`) → C bridge (`Quantum4LeanFFI.c`) → C++ Engine (`QuantumKitCore.mm`) with embedded Metal JIT. Zero-copy via `FloatArray` (double*).

## Playground

Advanced demonstrations extending the library. Independent import.

### Diophantine Solver (QuantumPlaygroundDiophantine)

4 cases with exhaustive search via polyToIsing:

```lean
import Quantum4LeanPlayground
#eval Quantum4LeanPlayground.Diophantine.report
```

Cases: Tijdeman, Pillai n=2, Pillai n=3, Pythagoras.

### Beal's Conjecture (QuantumPlaygroundBeal)

Massive counterexample search at 3 scales (9, 12, 19 qubits):

```lean
#eval Quantum4LeanPlayground.Beal.report
```

### ADAM Optimizer

VQE with ADAM optimizer (momentum + adaptive learning rate).

```lean
let (energy, params, history) := adamVQE ansatz H initialParams 0.01 200
```

### Quantum Tijdeman

```lean
#eval Quantum4LeanPlayground.Tijdeman.report
-- x^2 = y^3 + 1 via QAOA. Validated against formal proof.
```

## Fuzzer

```lean
#eval runFullSuite { maxQubits := 5, numCircuits := 200 }
#eval reportToString (runFullSuite { numCircuits := 100 })
```

## Bit-exactness with CoreQU4TRIX

| Algorithm | C++ Source | Lean Implementation |
|-----------|-----------|---------------------|
| 1q Unitary | `aplicar_unitaria_cpu` | `applyUnitaryInPlace` |
| CNOT | `aplicar_cnot_cpu` | `applyCNOTInPlace` |
| CZ | `aplicar_cz_cpu` | `applyCZInPlace` |
| SWAP | `aplicar_swap_cpu` | `applySWAPInPlace` |
| Measurement | `medir_y_colapsar_cpu` | `measure` |
| LCG | `6364136223846793005` | `lcgNext` |

## Structure

```
Quantum4Lean/
+-- lakefile.lean
+-- Quantum4Lean.lean              -- Main module
+-- Quantum4Lean/
|   +-- Quantum4LeanCore.lean      -- Qubit, Gate, Circuit
|   +-- Quantum4LeanError.lean     -- QuantumError
|   +-- Quantum4LeanEngine.lean    -- StateVector, simulator
|   +-- Quantum4LeanFuzz.lean      -- Intra-Lean fuzzer
|   +-- Quantum4LeanUnitary.lean   -- Complex, UnitaryMatrix
|   +-- Quantum4LeanObservable.lean-- PauliString, expect
|   +-- Quantum4LeanVQE.lean       -- Parameter-shift, VQE
|   +-- Quantum4LeanQAOA.lean      -- Mixing layer, Ising
|   +-- Quantum4LeanDSL.lean       -- circuito!, q[i]
|   +-- Quantum4LeanTactic.lean    -- circuit_equiv, quantum_simp
|   +-- Quantum4LeanSimp.lean      -- Simplifier (12 rules)
|   +-- Quantum4LeanTranspile.lean -- Transpiler (8 theorems)
|   +-- Quantum4LeanClifford.lean  -- Clifford verification (Z[i])
|   +-- Quantum4LeanDiophantine.lean-- Linear Diophantine translator
|   +-- Quantum4LeanPolynomial.lean -- Polynomial translator
|   +-- Quantum4LeanRunner.lean    -- Test runner
+-- Quantum4LeanPlayground.lean    -- Playground root
+-- Quantum4LeanPlayground/
|   +-- QuantumPlaygroundDiophantine.lean
|   +-- QuantumPlaygroundBeal.lean
|   +-- QuantumPlaygroundTijdeman.lean
|   +-- QuantumPlaygroundRiemann.lean
|   +-- QuantumPlaygroundTRDU.lean
+-- Quantum4LeanBridge/            -- C bridge (FFI)
|   +-- Quantum4LeanFFI.h / .c
+-- buildCPU.sh buildFFI.sh buildMetal.sh  -- FFI scripts
+-- .github/workflows/ci.yml       -- CI
+-- README.md
+-- USER_MANUAL.md
+-- FOUNDATIONAL_MANUSCRIPT.md
+-- LICENSE
+-- CITATION.cff
```

## License

Apache 2.0 — see [LICENSE](LICENSE) for full text.

## Citation

If you use Quantum4Lean in your research, please cite:

```bibtex
@software{Quantum4Lean_v0.8.0,
  title   = {Quantum4Lean: Verified Quantum Computing on Apple Silicon},
  author  = {Izquierdo P\'erez, Bezalel},
  orcid   = {0009-0001-5993-4057},
  doi     = {10.5281/zenodo.21197538},
  year    = {2026},
  version = {v0.8.0},
  url     = {https://github.com/Alektronnik/Quantum4Lean}
}
```

See [CITATION.cff](CITATION.cff) for the full metadata.

## Requirements

- Lean 4 (v4.31.0)
- macOS / Linux / Windows
- Apple Silicon + macOS 13+ (FFI/Metal optional, up to 25 qubits)
- RAM: 512 MB for 20 qubits, 4 GB for 25 qubits
