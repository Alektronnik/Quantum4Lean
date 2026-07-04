---
title: Quantum4Lean -- User Manual
mark: Documentation
author: Bezalel Izquierdo Pérez (Alektronnik)
version: v0.7.0
date: July 2026
keywords: quantum computing, lean4, formal verification, NISQ, VQE, QAOA, quantum chemistry, topology
lang: en
---

# Quantum4Lean -- User Manual

**Version**: v0.7.0
**Date**: July 2026
**Keywords**: quantum computing, lean4, formal verification, NISQ, VQE, QAOA, quantum chemistry, topology

## Index

1. [Introduction](#1-introduction)
2. [Installation](#2-installation)
3. [Getting Started](#3-getting-started)
4. [Core Concepts](#4-core-concepts)
5. [Execution Engines](#5-execution-engines)
6. [Declarative DSL](#6-declarative-dsl)
7. [Observables and Expected Values](#7-observables-and-expected-values)
8. [VQE: Variational Optimization](#8-vqe-variational-optimization)
9. [QAOA: Approximate Optimization Algorithm](#9-qaoa-approximate-optimization-algorithm)
10. [Semantic Verification](#10-semantic-verification)
11. [Simplifier and Transpiler](#11-simplifier-and-transpiler)
12. [Intra-Lean Fuzzer](#12-intra-lean-fuzzer)
13. [Diophantine Translator](#13-diophantine-translator)
14. [Polynomial Translator](#14-polynomial-translator)
15. [ADAM Optimizer + Adaptive VQE](#15-adam-optimizer--adaptive-vqe)
16. [Quantum Chemistry (Jordan-Wigner)](#16-quantum-chemistry-jordan-wigner)
17. [Discrete Topology (Hodge + Betti + FirmaPrima)](#17-discrete-topology-hodge--betti--firmaprima)
18. [Playground](#18-playground)
19. [OpenQASM 3.0 Exporter](#19-openqasm-30-exporter)
20. [Density Matrix and Noise Channels](#20-density-matrix-and-noise-channels)
21. [FFI Bridge (Apple Silicon / Metal 3)](#21-ffi-bridge-apple-silicon--metal-3)
22. [API Reference](#22-api-reference)
23. [Project Architecture](#23-project-architecture)

---

## 1. Introduction

Quantum4Lean is a verified quantum computing platform in Lean 4. It provides:

- **Pure-Lean simulation engine** bit-exact with CoreQU4TRIX (C++/Metal)
- **Complete NISQ stack**: StateVector, Observables, VQE, QAOA
- **Diophantine translator**: linear equations to Ising Hamiltonians
- **Polynomial translator**: monomials with exponents <= 3 (Tijdeman, Pillai, Beal)
- **ADAM Optimizer**: VQE with momentum and adaptive learning rate
- **Formal verification**: unitary matrices, semantic equivalence, tactics
- **Symbolic simplifier**: circuit rewriting over the AST (arbitrary N)
- **Verified transpiler**: optimization with semantic preservation
- **Intra-Lean fuzzer**: algebraic + random tests
- **Declarative DSL**: `circuit\! { H q[0]; CNOT q[0] q[1] }`
- **OpenQASM 3.0 exporter**: verified circuits to IBM/AWS-executable format
- **Density Matrix + Noise**: decoherence simulation for the NISQ era
- **FFI bridge**: C++/Metal 3 engine for up to 25 qubits (~1 GB RAM)
- **Zero external dependencies**: `lake build quantum4lean-test` + `./.lake/build/bin/quantum4lean-test`
- **Lean 4.31.0** compatible

### Philosophy

Quantum4Lean follows three principles:

1. **Dependent types for safety**. A circuit referencing `q[5]` in a 3-qubit system is rejected at compile time. Not at runtime. At compile time.

2. **Functional purity**. Every state transformation is a pure function returning a new `StateVector`. No side effects, no mutable memory.

3. **Verification over trust**. Every circuit can be verified against its unitary matrix. Every optimization preserves semantics. The fuzzer validates thousands of random circuits.

---

## 2. Installation

### Requirements

- Lean 4 v4.31.0
- macOS, Linux, or Windows

### Installing Lean 4

```bash
curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain leanprover/lean4:4.31.0
export PATH="$HOME/.elan/bin:$PATH"
```

### Building Quantum4Lean

```bash
git clone https://github.com/TU_USUARIO/Quantum4Lean.git
cd Quantum4Lean
lake build quantum4lean-test
```

Zero external dependencies. No mathlib4, no C++ binaries.

### Verifying Installation

```bash
lake build quantum4lean-test && .lake/build/bin/quantum4lean-test
```

Expected output:

```
=== Unitary Matrix Tests ===
  OK: 8/8 verified identities

=== Fuzz Tests ===
FUZZ: 0 failures
  ...

ALL TESTS OK - Quantum4Lean v0.7.0
```

---

## 3. Getting Started

### Importing Quantum4Lean

```lean
import Quantum4Lean
```

This provides access to all public types and functions.

### Creating a Circuit

```lean
-- Without DSL (explicit types)
def bellCircuit : Circuit 2 :=
  let q0 : Qubit 2 := \u27e8\u27e80, by decide\u27e9\u27e9
  let q1 : Qubit 2 := \u27e8\u27e81, by decide\u27e9\u27e9
  circuit fun c => (c.add (Gate.H q0)).add (Gate.CNOT q0 q1)

-- With DSL
open Quantum4Lean.DSL.Shortcuts

def bell : Circuit 2 := circuit\! {
  H q[0];
  CNOT q[0] q[1]
}
```

### Running a Circuit

```lean
#eval executeSim bell
-- Except.ok [1]
```

The result `[1]` indicates the measured state in one shot (Bell collapses to `|00\u27e9` or `|11\u27e9`). `executeSim` performs a single shot.

### Verifying Equivalence

```lean
#eval circuitsEquiv bellCircuit bell
-- true
```

Both circuits (with explicit types and with DSL) are semantically identical.

---

## 4. Core Concepts

### Qubit

```lean
structure Qubit (n : Nat) where
  idx : Fin n
```

A `Qubit n` is a valid index in a register of `n` qubits. `Fin n` guarantees `0 <= idx < n`.

```lean
-- Create a qubit
let q0 : Qubit 3 := \u27e8\u27e80, by decide\u27e9\u27e9  -- index 0 in a 3-qubit register
let q1 : Qubit 3 := \u27e8\u27e81, by decide\u27e9\u27e9  -- index 1
let q2 : Qubit 3 := \u27e8\u27e82, by decide\u27e9\u27e9  -- index 2

-- Syntactic sugar
let q0 : Qubit 3 := q[0]
```

### Gate

```lean
inductive Gate (n : Nat) : Type where
  | H    (q : Qubit n)
  | X    (q : Qubit n)
  | Y    (q : Qubit n)
  | Z    (q : Qubit n)
  | S    (q : Qubit n)
  | T    (q : Qubit n)
  | CNOT (control target : Qubit n)
  | CZ   (control target : Qubit n)
  | SWAP (a b : Qubit n)
  | RX (q : Qubit n) (theta : Float)
  | RY (q : Qubit n) (theta : Float)
  | RZ (q : Qubit n) (theta : Float)
  | Unitary (q : Qubit n) (matrix : Array Float)
```

13 constructors covering Clifford gates, parametric rotations, and arbitrary unitaries.

### Circuit

```lean
structure Circuit (n : Nat) where
  gates : List (Gate n)
```

A circuit is an ordered sequence of gates. Composition is sequential: `c1.comp c2` applies `c1` then `c2`.

```lean
-- Build a circuit with the builder
def myCircuit : Circuit 3 :=
  circuit fun c =>
    c.add (Gate.H (q[0]))
    |>.add (Gate.CNOT (q[0]) (q[1]))
    |>.add (Gate.X (q[2]))

-- Components
let c := Circuit.identity 3       -- empty circuit
let c := c.add (Gate.H q[0])     -- add gate
let c := c.comp anotherCircuit    -- compose
let c := c.repeat 5               -- repeat 5 times
c.gates                           -- gate list
c.depth                           -- depth
```

---

## 5. Execution Engines

### Pure-Lean Engine

Bit-exact state vector simulator with the C++ CoreQU4TRIX engine. Up to 10 qubits.

```lean
-- Execute and get measurement bits
let result := executeSim myCircuit 123456789
-- Except.ok [1, 0, 1]  (measured bits)

-- Execute and get probabilities
let probs := executeSimProbs myCircuit 123456789
-- Except.ok #[0.25, 0.0, 0.25, 0.0, ...]
```

### StateVector API

```lean
-- Initialize |0...0\u27e9
let sv <- StateVector.init 3

-- Apply circuit
let sv := StateVector.runCircuit sv myCircuit

-- Measure a qubit (collapses the state)
let (bit, sv) := StateVector.measure sv 0

-- Measure all qubits
let (bits, sv) := StateVector.measureAll sv

-- Probabilities P(|i\u27e9) for each basis state
let probs := StateVector.probabilities sv

-- Complex amplitude of state |i\u27e9
let (re, im) := StateVector.amplitude sv 5

-- Probability of state |i\u27e9
let p := StateVector.prob sv 0

-- Run circuit with measurement
let result := StateVector.run myCircuit 123456789 1
```

### FFI Engine (optional)

For N > 10 qubits or Metal 3 GPU. Up to 25 qubits on Apple Silicon.

```bash
# Prerequisite: build QuantumKitCore (sibling project)
cd ../QuantumKit && swift build
cd ../Quantum4Lean && lake build -K enableFFI=true
```

The linker looks for `libQuantumKitCore.a` in QuantumKit build paths. If the binary is not found, the FFI build will fail with undefined symbol errors. The pure-Lean engine works without this step.

---

## 6. Declarative DSL

### Basic Syntax

```lean
open Quantum4Lean.DSL.Shortcuts

-- q[i] creates a Qubit n (n inferred from context)
def bell : Circuit 2 := circuit\! {
  H q[0];
  CNOT q[0] q[1]
}

-- Available gates: H, X, Y, Z, S, T, CNOT, CZ, SWAP, RX, RY, RZ
def complexCircuit : Circuit 3 := circuit\! {
  H q[0];
  CNOT q[0] q[1];
  RX q[2] (1.57);
  SWAP q[0] q[2]
}
```

### Without Shortcuts

If not using `open Quantum4Lean.DSL.Shortcuts`, use `Gate.` prefix:

```lean
def bell : Circuit 2 := circuit\! {
  Gate.H q[0];
  Gate.CNOT q[0] q[1]
}
```

---

## 7. Observables and Expected Values

### Types

```lean
inductive Pauli : Type where
  | I | X | Y | Z

structure PauliString where
  coefficient : Float
  terms       : List PauliTerm

structure Observable where
  strings : List PauliString
```

### Common Hamiltonians

```lean
-- 1D Ising: H = -J \u03a3 Z_i Z_{i+1} - h \u03a3 X_i
let H := Observable.ising1D 4 1.0 0.5

-- 1D Heisenberg: H = J \u03a3 (X_i X_{i+1} + Y_i Y_{i+1} + Z_i Z_{i+1})
let H := Observable.heisenberg1D 4 1.0

-- Custom observable
let H := Observable.pauli .Z 0 0.5         -- 0.5 * Z_0
let H := H.add (Observable.pauli .X 1 0.3)  -- + 0.3 * X_1
```

### Expected Values

```lean
-- <H> over a StateVector
let sv : StateVector := ...
let energy := expect sv H

-- <Z_0>
let z0 := expectZ sv 0

-- <X_1>
let x1 := expectX sv 1

-- Arbitrary PauliString
let val := expectString sv 1.0 [(.X, 0), (.Z, 1)]
```

---

## 8. VQE: Variational Optimization

### Ansatz

An ansatz is a function `List Float -> Circuit n` mapping parameters to a circuit.

```lean
-- Ising ansatz with RY layer + CNOT entanglement
def ansatz := isingAnsatz 4 1
-- 4 qubits, depth 1 = 8 parameters (4 RY + 4 more in the CNOT layer)
```

### Optimization

```lean
let H := Observable.ising1D 4 1.0 0.5
let initialParams := List.replicate 8 0.1
let (energy, params, history) := vqe ansatz H initialParams 0.01 100

-- energy: final energy
-- params: optimal parameters
-- history: energies per iteration
```

### Parameter-shift

```lean
-- Gradient of <H> with respect to parameter i
let g := parameterShiftGradient ansatz H params 0

-- Full gradient (2*k evaluations)
let grad := gradient ansatz H params

-- Gradient descent step
let newParams := gradientDescentStep params grad 0.01
```

---

## 9. QAOA: Approximate Optimization Algorithm

### QAOA for Ising

```lean
-- 4-qubit Ising model, p=1 layer, J=1.0, h=0.5
let (energy, params, history) := qaoaIsing 4 1 1.0 0.5 0.05 100
```

### Manual QAOA Circuit

```lean
-- Build QAOA circuit (without optimizing)
let circuit := qaoaIsingCircuit 4 1 1.0 0.5
let c := circuit [0.1, 0.1]  -- gamma=0.1, beta=0.1

-- Individual layers
let costLayer := qaoaIsingCostLayer 4 0.1 1.0 0.5
let mixLayer := qaoaMixingLayer 4 0.1
```

---

## 10. Semantic Verification

### Unitary Matrices

```lean
-- Compile circuit to 2^n x 2^n unitary matrix
let U := compile bellCircuit  -- UnitaryMatrix 2

-- Element (i, j)
let element := UnitaryMatrix.get U 0 3

-- First column: |U|0...0>
let col0 := UnitaryMatrix.firstColumn U

-- Theoretical probabilities: |U|0>|^2
let theoryProbs := UnitaryMatrix.theoreticalProbs U
```

### Circuit Equivalence

Quantum4Lean offers two levels of verification:

**Level 1: `cliffordEquiv` (formal, Z[i])** -- For the 7 Clifford gates (X, Y, Z, S, CNOT, CZ, SWAP). Uses integer arithmetic in Z[i] = {a+bi | a,b \u2208 Z}. `native_decide` proves automatically.

```lean
-- Formal proof (kernel, no Float, no \u221a2)
theorem rule : cliffordEquiv c1 c2 := by
  native_decide
```

**Level 2: `circuitsEquiv` (runtime, Float)** -- For any circuit (includes H, T, rotations). Verifies via `#eval` comparing unitary matrices with `traceDistance`.

```lean
-- Runtime verification
#eval circuitsEquiv c1 c2
```

### Tactics

```lean
-- circuit_equiv: for circuits without H (Pauli, CNOT, CZ, SWAP)
example : circuitsEquiv
  (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
  (Circuit.identity 2) := by
  circuit_equiv

-- quantum_simp: simplifies and verifies
example : circuitsEquiv
  (optimizeCircuit c) (Circuit.identity 2) := by
  quantum_simp
```

### Correctness Theorems

8 theorems document the correctness of each simplifier rule:

```lean
-- See Quantum4LeanTheorems.lean for the complete proofs.
-- 8 Clifford theorems proven with `native_decide`.
-- Example:
theorem X_X_eq_I : cliffordEquiv
    (circuit fun c => (c.add (Gate.X q0)).add (Gate.X q0))
    (Circuit.identity 2) := by
  native_decide
```

The 8 Clifford theorems are proven with `native_decide` in `Quantum4LeanTheorems.lean`. Non-Clifford identities (H, T, RX) are verified computationally via `circuitsEquiv` with tolerance `1e-6`.

---

## 11. Simplifier and Transpiler

### Symbolic Simplifier

Operates on the circuit AST. No matrices. Scales to arbitrary N.

```lean
-- Simplify circuit
let optimized := simplifyCircuit myCircuit

-- Gates removed
let saved := simplificationSavings myCircuit
```

### Implemented Rules

| Rule | Transformation |
|------|----------------|
| Cancellation | G*G -> remove (H,X,Y,Z,CNOT,CZ,SWAP) |
| Pauli sandwich | H*X*H -> Z, H*Z*H -> X |
| Phase | S*S -> Z, T*T -> S |
| Commutation | A*B -> B*A (disjoint qubits) |
| CNOT target | CNOT(a,b)*CNOT(a,c) = CNOT(a,c)*CNOT(a,b) |
| CNOT control | CNOT(a,b)*CNOT(c,b) = CNOT(c,b)*CNOT(a,b) |
| H sandwich CNOT | H(t)*CNOT(c,t)*H(t) = CZ(c,t) |
| SWAP decomp | CNOT(a,b)*CNOT(b,a)*CNOT(a,b) = SWAP(a,b) |

### Verified Transpiler

```lean
-- Optimize preserving semantics
let optimized := optimizeCircuit myCircuit

-- Verify preservation
#eval verifyOptimization myCircuit
-- true

-- Engine test: runs both and compares probabilities
#eval testOptimization myCircuit
-- Except.ok true
```

---

## 12. Intra-Lean Fuzzer

### Full Suite

```lean
-- Run all tests
let report := runFullSuite { maxQubits := 5, numCircuits := 200 }

-- Human-readable report
#eval reportToString report
```

Expected output:

```
FUZZ: 0 failures
  Identities: OK
  SWAP: OK
  Pauli: OK
  Bell: OK
  GHZ: OK
  Random: OK
```

### Individual Tests

```lean
#eval testGateIdentities   -- H*H=I, X*X=I, etc.
#eval testBellState         -- (|00>+|11>)/sqrt(2)
#eval testGHZState          -- (|000>+|111>)/sqrt(2)
#eval testPauliAlgebra      -- XZ|0> vs ZX|0>
```

### Configuration

```lean
let cfg : FuzzConfig := {
  maxQubits   := 5      -- 2..5 qubits
  maxDepth    := 20     -- 1..20 gates
  numCircuits := 200    -- circuits to generate
  seed        := 987654321
  tolerance   := 1e-12
}
let report := runFullSuite cfg
```

---

## 13. Diophantine Translator

Converts linear Diophantine equations to Ising Hamiltonians for QAOA resolution.

### Motivation

Given an equation $ax + by = c$ with integer variables, the problem of finding solutions is NP-complete. Quantum4Lean encodes each variable in $b$ bits and minimizes the cost functional:

$$C(x,y) = (ax + by - c)^2 = \\sum_i \\alpha_i Z_i + \\sum_{i<j} \\beta_{ij} Z_i Z_j$$

This Ising Hamiltonian is directly optimizable with QAOA.

### Usage

```lean
import Quantum4Lean

-- Equation: 3x + 5y = 22
let eq : Diophantine := {
  vars := [
    { coeff := 3, name := "x", bits := 4 },
    { coeff := 5, name := "y", bits := 4 }
  ],
  constant := 22
}

-- Convert to Ising Hamiltonian (8 qubits: 4 for x, 4 for y)
let H := toIsing eq 4

-- Solve via QAOA (p=1 layer, lr=0.05, 100 iterations)
let result := diophantineSolve eq 4

-- Verify manually
#eval checkSolution eq [("x", 4), ("y", 2)]
-- true  (3*4 + 5*2 = 12 + 10 = 22)
```

### Algorithm

| Step | Description |
|------|-------------|
| `toIsing` | Expands $(ax+by-c)^2$ into Pauli Z terms |
| Linear terms | $c \\cdot a \\cdot 2^j \\cdot Z_j$ per bit |
| Diagonal terms | $a^2 \\cdot 2^{j+l-1} \\cdot Z_j Z_l$ (same variable, $j<l$) |
| Cross terms | $a_i a_k \\cdot 2^{j+l-1} \\cdot Z_j Z_l$ (different variables) |
| `diophantineSolve` | Optimizes the Hamiltonian via QAOA |

### API

| Function | Description |
|----------|-------------|
| `Diophantine` | Equation (vars + constant) |
| `toIsing eq bitsPerVar` | Ising Observable |
| `diophantineSolve eq bitsPerVar` | QAOA result |
| `checkSolution eq values` | Verify solution |
| `decodeValues eq bitsPerVar sv` | Decode StateVector |

---

## 14. Polynomial Translator

Generalizes the linear translator. Supports monomials with exponents 1, 2, 3.
Enables attacking equations such as $x^2 = y^3 + 1$ (Tijdeman) via QAOA/VQE.

### Types

```lean
structure Monomial where
  coefficient : Int
  exponents   : List (Nat x Nat)   -- (variableIndex, exponent)

structure PolyEquation where
  monomials : List Monomial
  constant  : Int
  varBits   : List Nat             -- bits per variable

structure PolyResult where
  values    : List (String x Int)
  energy    : Float
  satisfied : Bool
```

### Method

Each variable $x$ with $b$ bits is encoded as $x = \\sum 2^j \\cdot \\frac{1-Z_j}{2}$.
$q_j = \\frac{1-Z_j}{2}$ is idempotent ($q_j^2 = q_j$). We expand $( \\sum \\text{monomials} - c)^2$.

Supports exponents <= 3. Exponents > 3 require recursion.

### Usage

```lean
import Quantum4Lean

-- Tijdeman equation: x^2 - y^3 = 1
let eq : PolyEquation := {
  monomials := [
    { coefficient := 1,  exponents := [(0, 2)] },
    { coefficient := -1, exponents := [(1, 3)] }
  ],
  constant := 1,
  varBits := [4, 4]  -- 4 bits for x, 4 for y
}

-- Convert to Ising Hamiltonian (8 qubits)
let H := polyToIsing eq
let n := polyTotalQubits eq  -- 8
```

### API

| Function | Description |
|----------|-------------|
| `Monomial` | Coefficient * product of variables |
| `PolyEquation` | Sum of monomials = constant |
| `polyToIsing eq` | Ising Observable for QAOA/VQE |
| `polyTotalQubits eq` | Total number of qubits |
| `expandVarPower startQ bits exp` | Expand x^e into PauliStrings |
| `expandMonomial m offsets varBits` | Expand full monomial |

### Expansion Algorithm

| Exponent | Generated Terms |
|----------|-----------------|
| 1 (linear) | I, Z_j |
| 2 (quadratic) | I, Z_j, Z_j Z_k (j<k) |
| 3 (cubic) | I, Z_j, Z_j Z_k, Z_j Z_k Z_l (j<k<l) |

---

## 15. ADAM Optimizer

VQE with ADAM optimizer (Adaptive Moment Estimation). Superior to SGD
on rugged landscapes such as Diophantine Hamiltonians.

### Algorithm

```
m_t = beta1 * m_{t-1} + (1 - beta1) * g_t
v_t = beta2 * v_{t-1} + (1 - beta2) * g_t^2
m_hat = m_t / (1 - beta1^t)
v_hat = v_t / (1 - beta2^t)
theta = theta - lr * m_hat / (sqrt(v_hat) + eps)
```

### Usage

```lean
let H := polyToIsing eq
let initialParams := List.replicate 8 0.1
-- ADAM: better convergence than standard VQE
let (energy, params, history) := adamVQE ansatz H initialParams 0.01 200

-- Manual ADAM step (for custom optimization)
let (newParams, newM, newV) := adamStep params m v grad 0.01 0.9 0.999 1e-8 t
```

Default parameters: lr=0.01, beta1=0.9, beta2=0.999, eps=1e-8.

---

## 16. Playground

Advanced demonstrations. Namespace: `Quantum4LeanPlayground.*`.

```lean
import Quantum4LeanPlayground

#eval Quantum4LeanPlayground.Diophantine.report   -- 4 cases
#eval Quantum4LeanPlayground.Beal.report          -- 3 scales
#eval Quantum4LeanPlayground.Fuzz.report          -- random tests
#eval Quantum4LeanPlayground.Tijdeman.report      -- dedicated QAOA
```

### Diophantine Solver (QuantumPlaygroundDiophantine)

4 predefined cases. Namespace: `Quantum4LeanPlayground.Diophantine`.

| Case | Equation | Solution |
|------|----------|----------|
| Tijdeman | $x^2 = y^3 + 1$ | $x=3, y=2$ |
| Pillai n=2 | $a^3 = b^2 + 2$ | $a=3, b=5$ |
| Pillai n=3 | $a^3 = b^2 + 3$ | None |
| Pythagoras | $x^2 + y^2 = z^2$ | $3,4,5$ |

```lean
import Quantum4LeanPlayground
#eval Quantum4LeanPlayground.Diophantine.report
```

### Beal (QuantumPlaygroundBeal)

5 cases of Beal's Conjecture with exhaustive search:

| Case | Equation | Qubits | Range |
|------|----------|--------|-------|
| 3+3=2 | $a^3 + b^3 = c^2$ | 12 | a,b:0..15 |
| 3+2=3 | $a^3 + b^2 = c^3$ | 9 | a,c:0..7 |
| 2+3=3 | $a^2 + b^3 = c^3$ | 13 | a,c:0..15 |
| 3+3=3 | $a^3 + b^3 = c^3$ | 12 | a,b,c:0..15 |
| 3+3=2 L | $a^3 + b^3 = c^2$ | 19 | a,b:0..63 |

Report includes gcd(a,b,c) analysis for each exact solution.

```lean
#eval Quantum4LeanPlayground.Beal.report
```

### FFI (QuantumPlaygroundFFI)

C++/Metal engine. CPU: up to 25 qubits (~1 GB). Metal GPU: Apple Silicon.

```bash
# CPU
bash buildCPU.sh && lake build quantum4lean-ffi
.lake/build/bin/quantum4lean-ffi

# Metal
bash buildMetal.sh && LEAN_CC=clang lake build quantum4lean-ffi-metal
.lake/build/bin/quantum4lean-ffi-metal
```

### Quantum Tijdeman (QuantumPlaygroundTijdeman)

Dedicated solution of $x^2 = y^3 + 1$ via QAOA with optimized ansatz.

```lean
#eval Quantum4LeanPlayground.Tijdeman.report
#eval Quantum4LeanPlayground.Tijdeman.testExactSolution
```

---

## 17. OpenQASM 3.0 Exporter

The `Quantum4LeanQASM` module exports any `Circuit n` to OpenQASM 3.0,
the standard format for execution on real quantum hardware (IBM Quantum, AWS Braket).

All 13 catalog gates have direct equivalence:

| Gate | OpenQASM 3.0 |
|------|---------------|
| `H q` | `h q[N];` |
| `X q` | `x q[N];` |
| `Y q` | `y q[N];` |
| `Z q` | `z q[N];` |
| `S q` | `s q[N];` |
| `T q` | `t q[N];` |
| `CNOT c t` | `cx q[C], q[T];` |
| `CZ c t` | `cz q[C], q[T];` |
| `SWAP a b` | `swap q[A], q[B];` |
| `RX q theta` | `rx(theta) q[N];` |
| `RY q theta` | `ry(theta) q[N];` |
| `RZ q theta` | `rz(theta) q[N];` |
| `Unitary q m` | not supported (WARNING comment) |

Usage:

```lean
import Quantum4Lean.QASM

def bell : Circuit 2 := ...
#eval circuitToQASM bell "bell_state"
-- // OpenQASM 3.0 generated by Quantum4Lean
-- OPENQASM 3.0;
-- include "stdgates.inc";
-- qubit[2] q;
--   h q[0];
--   cx q[0], q[1];

-- Export to file:
#eval exportCircuit bell "bell.qasm" "bell_state"
```

---

## 18. Density Matrix and Noise Channels

The `Quantum4LeanDensity` module implements the density matrix formalism
for open quantum system simulation (NISQ era).

### DensityMatrix n

Matrix 2^n x 2^n, Hermitian, trace 1. Flat representation in `Array Float`
(real/imag interleaved). Maximum 5 qubits (1024 complex numbers, ~16 KB).

Operations:
- `DensityMatrix.init n` -- pure state |0...0><0...0|
- `applyGate rho gate` -- applies U rho U^dagger (13 gates)
- `runCircuit rho circuit` -- runs full circuit
- `trace rho` -- trace (should be ~1.0)

### CPTP Noise Channels

| Channel | Formula | Parameter | Models |
|---------|---------|-----------|--------|
| `depolarize` | rho -> (1-p) rho + p I/d | p in [0,1] | Isotropic noise |
| `amplitudeDamping` | Kraus E0, E1 | gamma in [0,1] | T1 relaxation |
| `phaseDamping` | rho -> (1-lambda) rho + lambda Z rho Z | lambda in [0,1] | T2 dephasing |

Usage:

```lean
import Quantum4Lean.Density

let rho <- DensityMatrix.init 2
let rho := DensityMatrix.applyGate rho (Gate.H q0)
let rho := DensityMatrix.depolarize rho 0.01
let rho := DensityMatrix.amplitudeDamping rho 0 0.05
```

---

## 19. FFI Bridge (CPU + Metal)

The FFI bridge connects Quantum4Lean to the C++ engine (CoreQU4TRIX)
for simulations up to 25 qubits.

### Architecture

```
Lean 4 (Quantum4LeanFFI.lean)
  -> @[extern] quantum4LeanInit / ApplyGate / Measure
  -> FloatArray (shared memory)
C (Quantum4LeanBridge.c)
  -> calls qu4trix_* API
C++ (QuantumKitCore.mm)
  -> CPU Engine (GCD) + GPU (Metal 3, optional)
```

### Compilation

```bash
# CPU mode (recommended, links with ld64.lld):
bash buildCPU.sh && lake build quantum4lean-ffi

# Metal mode (requires system clang + Apple frameworks):
bash buildMetal.sh && LEAN_CC=clang lake build quantum4lean-ffi-metal
```

### Current Status

CPU mode: compiles, links, and runs (50/50 build). Up to 25 qubits.
Metal mode: compiles, requires `LEAN_CC=clang` to link Apple frameworks.

---

## 20. API Reference

### Public Types

| Type | Description |
|------|-------------|
| `Qubit n` | Valid index in n-qubit register (`Fin n`) |
| `Gate n` | Quantum gate (13 constructors) |
| `Circuit n` | Ordered sequence of gates |
| `StateVector` | State vector (Array Float interleaved) |
| `Complex` | Complex number (re, im) |
| `CliffordAmplitude` | Clifford amplitude (a+bi, a,b \u2208 Z) |
| `CliffordMatrix n` | Clifford matrix over Z[i] |
| `UnitaryMatrix n` | Unitary matrix $2^n \\times 2^n$ |
| `Pauli` | I, X, Y, Z |
| `PauliString` | Tensor product of Paulis with coefficient |
| `Observable` | Weighted sum of PauliStrings |
| `FuzzConfig` | Fuzzer configuration |
| `FuzzReport` | Fuzzer result |
| `Diophantine` | Diophantine equation (vars + constant) |
| `DiophantineVar` | Diophantine variable (coeff, name, bits) |
| `DiophantineResult` | Optimization result |
| `Monomial` | Monomial (coef * prod vars^exp) |
| `PolyEquation` | Polynomial equation |
| `PolyResult` | Polynomial solver result |

### Execution

| Function | Return |
|----------|--------|
| `executeSim c seed` | `Except String (List Nat)` |
| `executeSimProbs c seed` | `Except String (Array Float)` |
| `StateVector.init n seed` | `Except String StateVector` |
| `StateVector.runCircuit sv c` | `StateVector` |
| `StateVector.measure sv k` | `Int x StateVector` |
| `StateVector.measureAll sv` | `Nat x StateVector` |
| `StateVector.probabilities sv` | `Array Float` |
| `StateVector.amplitude sv i` | `Float x Float` |
| `StateVector.prob sv i` | `Float` |
| `StateVector.run c seed shots` | `Except String (List Nat)` |

### Observables

| Function | Description |
|----------|-------------|
| `Observable.zero` | Null observable |
| `Observable.pauli p q c` | c * P_q |
| `Observable.ising1D n J h` | 1D Ising |
| `Observable.heisenberg1D n J` | 1D Heisenberg |
| `expect sv obs` | `<H>` |
| `expectZ sv q` | `<Z_q>` |
| `expectX sv q` | `<X_q>` |
| `expectY sv q` | `<Y_q>` |
| `expectPauliString sv ps` | `<P>` |
| `expectString sv coeff terms` | `<c * P1...Pk>` |

### VQE

| Function | Description |
|----------|-------------|
| `isingAnsatz n d` | Ising Ansatz (RY + CNOT) |
| `evalCircuit ansatz obs params` | `<H(params)>` |
| `shiftedExpect ansatz obs params idx shift` | `<H(theta_i + shift)>` |
| `parameterShiftGradient ansatz obs params idx` | `d<H>/dtheta_i` |
| `gradient ansatz obs params` | Full gradient vector |
| `gradientDescentStep params grad lr` | Descent step |
| `vqe ansatz obs initParams lr maxIter tol` | `(E, params, history)` |

### QAOA

| Function | Description |
|----------|-------------|
| `qaoaMixingLayer n beta` | Mixing layer (RX) |
| `qaoaIsingCostLayer n gamma J h` | Ising cost layer |
| `qaoaIsingCircuit n p J h` | Full QAOA circuit |
| `qaoaIsing n p J h lr maxIter` | QAOA optimization |

### Verification

| Function | Description |
|----------|-------------|
| `compile c` | Circuit -> UnitaryMatrix |
| `circuitsEquiv c1 c2 eps` | Semantic equivalence (Float) |
| `cliffordEquiv c1 c2` | Formal equivalence (Z[i], `native_decide`) |
| `compileClifford c` | Circuit -> CliffordMatrix |
| `UnitaryMatrix.mul a b` | Multiplication |
| `UnitaryMatrix.adjoint u` | Conjugate transpose |
| `UnitaryMatrix.traceDistance a b` | Trace distance |
| `UnitaryMatrix.theoreticalProbs u` | `|U|0>|^2` |
| `UnitaryMatrix.firstColumn u` | First column |

### Simplifier and Transpiler

All functions are in the main namespace (`Quantum4Lean`). No additional `open` required.

| Function | Description |
|----------|-------------|
| `simplifyCircuit c` | Symbolic simplification |
| `simplificationSavings c` | Gates removed |
| `optimizeCircuit c` | Verified transpiler |
| `optimizationSavings c` | Gates removed |
| `verifyOptimization c` | `circuitsEquiv` runtime |
| `testOptimization c` | Engine probs comparison |
| `verifyAllRules` | 8 rules via `circuitsEquiv` |

### Fuzzer

| Function | Description |
|----------|-------------|
| `runFullSuite cfg` | Full suite |
| `reportToString report` | Human-readable report |
| `testGateIdentities` | Gate identities |
| `testBellState` | Bell state |
| `testGHZState` | GHZ state |
| `testPauliAlgebra` | XZ vs ZX |
| `fuzzRandomCircuits cfg` | Random circuits |

### Diophantine

| Function | Description |
|----------|-------------|
| `toIsing eq bitsPerVar` | Equation -> Ising Observable |
| `diophantineSolve eq bitsPerVar` | Solve via QAOA |
| `checkSolution eq values` | Verify solution |
| `decodeValues eq bitsPerVar sv` | StateVector -> values |

### Polynomial

| Function | Description |
|----------|-------------|
| `polyToIsing eq` | PolyEquation -> Ising Observable |
| `polyTotalQubits eq` | Total number of qubits |
| `expandVarPower startQ bits exp` | Expand x^e into PauliStrings |
| `expandMonomial m offsets varBits` | Expand full monomial |

### Tactics

Available after `import Quantum4Lean`. No `open` required.

| Tactic | Description |
|--------|-------------|
| `circuit_equiv` | Equivalence via `native_decide` |
| `quantum_simp` | Simplify + verify |

---

## 21. Project Architecture

```
Quantum4Lean/
+-- Quantum4Lean.lean              -- Main module (public API)
+-- Quantum4Lean/
|   +-- Quantum4LeanCore.lean      -- Qubit, Gate, Circuit
|   +-- Quantum4LeanError.lean     -- QuantumError inductive
|   +-- Quantum4LeanEngine.lean    -- StateVector, bit-exact simulator
|   +-- Quantum4LeanObservable.lean-- PauliString, Observable, expect
|   +-- Quantum4LeanVQE.lean       -- Parameter-shift, gradient, VQE
|   +-- Quantum4LeanQAOA.lean      -- Mixing layer, Ising cost layer
|   +-- Quantum4LeanUnitary.lean   -- Complex, UnitaryMatrix, circuitsEquiv
|   +-- Quantum4LeanSimp.lean      -- Symbolic simplifier (12 rules)
|   +-- Quantum4LeanTranspile.lean -- Verified transpiler (8 theorems)
|   +-- Quantum4LeanClifford.lean  -- Clifford verification (Z[i])
|   +-- Quantum4LeanFuzz.lean      -- Intra-Lean fuzzer
|   +-- Quantum4LeanDSL.lean       -- Macro circuit\!, q[i], Shortcuts
|   +-- Quantum4LeanTactic.lean    -- circuit_equiv, quantum_simp
|   +-- Quantum4LeanDiophantine.lean-- Linear Diophantine translator
|   +-- Quantum4LeanPolynomial.lean -- Polynomial translator
|   +-- Quantum4LeanSolver.lean     -- Shared utilities
|   +-- Quantum4LeanVerify.lean     -- Formal circuit verification
|   +-- Quantum4LeanQASM.lean       -- OpenQASM 3.0 exporter
|   +-- Quantum4LeanDensity.lean    -- Density Matrix + NISQ noise
|   +-- Quantum4LeanFFI.lean        -- @[extern] bridge (FloatArray)
|   +-- Quantum4LeanRunner.lean    -- Test runner
+-- Quantum4LeanPlayground.lean    -- Playground root
+-- Quantum4LeanPlayground/
|   +-- QuantumPlaygroundDiophantine.lean -- Diophantine solver
|   +-- QuantumPlaygroundBeal.lean        -- Beal (3 scales)
|   +-- QuantumPlaygroundTijdeman.lean    -- Tijdeman QAOA
|   +-- QuantumPlaygroundRiemann.lean     -- Riemann
|   +-- QuantumPlaygroundTRDU.lean        -- TRDU
|   +-- QuantumPlaygroundFFI.lean         -- FFI (Metal 3)
+-- .github/workflows/ci.yml       -- Continuous Integration
+-- lakefile.lean                  -- Build (Lean 4.31.0)
+-- README.md                      -- Documentation
+-- MANUAL.md                      -- This manual
```

### Data Flow

```
User -> DSL (circuit\! {})
     -> Circuit n (dependent types)
     -> StateVector.runCircuit (Pure-Lean Engine)
     -> StateVector.probabilities (measurement)
     -> executeSim (final result)

User -> Circuit n
     -> UnitaryMatrix.compile (verification)
     -> circuitsEquiv (equivalence)
     -> optimizeCircuit (transpiler)

User -> ParametricCircuit
     -> vqe (optimization)
     -> gradient (parameter-shift)
     -> qaoaIsing (QAOA)
```
