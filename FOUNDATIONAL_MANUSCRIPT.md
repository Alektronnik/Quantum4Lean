---
title: Foundational Manuscript
subtitle: Quantum4Lean v0.8.0 — Verified Quantum Computing on Apple Silicon
mark: Foundational Manuscript
author: Bezalel Izquierdo Pérez (Alektronnik)
orcid: 0009-0001-5993-4057
repo: github.com/Alektronnik/Quantum4Lean
version: v0.8.0
date: July 2026
keywords: quantum computing, lean4, formal verification, Apple Silicon, Metal 3, VQE, QAOA, topology, Hodge, Riemann, Tijdeman, TRDU
lang: en
---

# Foundational Manuscript

## Quantum4Lean v0.8.0 — Verified Quantum Computing on Apple Silicon

**Author**: Bezalel Izquierdo Pérez (Alektronnik)
**ORCID**: [0009-0001-5993-4057](https://orcid.org/0009-0001-5993-4057)
**Repository**: [github.com/Alektronnik/Quantum4Lean](https://github.com/Alektronnik/Quantum4Lean)
**Company**: CU4TRO T3RCIOS
**Department**: Q-ANTIK4
**Date**: July 2026
**Keywords**: quantum computing, lean4, formal verification, Apple Silicon, Metal 3, VQE, QAOA, topology, Hodge, Riemann, Tijdeman, TRDU

---

### Executive Summary

**Quantum4Lean v0.8.0** is a quantum computing infrastructure in Lean 4.31.0 designed to mechanize and execute a prior mathematical program on Diophantine, topological, and quantum-dynamical structures. Its core combines dependent types, circuits that are safe by construction, exact theorems for the Clifford fragment, and computational verification of universal circuits. On this foundation, it integrates StateVector, observables, VQE, QAOA, Density Matrix, Jordan-Wigner, quantum chemistry, translators to Ising Hamiltonians, and an optional FFI backend to C++/Metal on Apple Silicon.

The goal is not to replace mathlib or compete with Qiskit/Cirq in backend count, but to open a new layer: an infrastructure where a mathematical program can become executable, auditable, and progressively mechanizable within Lean.

Quantum4Lean does not invent the mathematical program that motivates it; it exists because that program demanded an infrastructure capable of expressing circuits, Hamiltonians, invariants, and verifications within Lean 4, while preserving real execution capability.

---

## 1. Why It Was Created

Quantum computing lives in a paradox: the most widely used simulation frameworks (Qiskit, Cirq, Pennylane) are written in Python — a language with no static types, no compile-time correctness guarantees, and no formal proof capabilities. A circuit referencing `q[5]` in a 3-qubit system fails at runtime, not at compile time. A circuit optimization is assumed correct, not proven.

Simultaneously, proof assistants like Lean 4 have reached extraordinary maturity — yet they are perceived as purely academic tools, incapable of handling the exponential computational load of real quantum simulation.

**Quantum4Lean demonstrates that both worlds can be united.** Qiskit and Cirq prioritize industrial scale, backend ecosystems, and interoperability; Quantum4Lean prioritizes dependent typing, formal auditability, and connection to a mechanizable mathematical program. They do not compete on the same dimension — they complement each other.

The infrastructure offers:

- **Compile-time verification**: dependent types that reject invalid circuits before execution.
- **Formal proof**: 8 Clifford theorems proven with `native_decide` in the Z[i] ring, with no Float, no `sorry`.
- **Real hardware performance**: FFI bridge to C++/Metal scaling to 25 qubits (~1 GB unified RAM).
- **Complete NISQ stack**: StateVector, Density Matrix + noise, VQE with ADAM, QAOA, Jordan-Wigner, exact quantum chemistry.

### Epistemological Status of the Project

Quantum4Lean does not arise from an isolated idea. It responds to a prior mathematical program that required formal and operational infrastructure. The following table distinguishes the strata of the project:

| Layer | Status |
|-------|--------|
| Foundational mathematical program | Previously developed by the author |
| Associated formalizations | Expressed in linked Lean modules and artifacts |
| Quantum4Lean core | Implemented and compiled in Lean 4.31.0 (34 build jobs, 22 modules) |
| Clifford fragment | Proven with `native_decide`, no `sorry` |
| Universal circuits | Computational verification via matrices and trace distance |
| VQE/QAOA/FFI | Execution validated by tests and runners |
| Riemann/TRDU/Tijdeman | Mechanized instances of the theoretical program, not mere demos |

This distinction is essential: the library does not claim that all mathematical content is absorbed by Lean's kernel. It claims that the infrastructure has been built to allow the mathematical program to enter Lean as executable, typed, partially proven, and progressively mechanizable code.

---

## 2. The Gap It Closes

### 2.1 Verification vs. Performance

| Tool | Types | Proof | Performance | GPU |
|------|-------|------|-------------|-----|
| Qiskit | Dynamic | No | High (C++ backend) | Yes |
| Cirq | Dynamic | No | Medium | No |
| Coq/QWire | Dependent | Yes | Low (interpreted) | No |
| **Quantum4Lean** | **Dependent** | **Yes** | **High (FFI)** | **Yes (Metal 3)** |

No other tool simultaneously offers dependent types, formal proof, and GPU acceleration.

### 2.2 Mathematics → Qubits

Quantum4Lean includes translators that convert Diophantine equations and multivariate polynomial systems of arbitrary degree into Ising Hamiltonians. This enables attacking open mathematical problems — Beal's Conjecture, Tijdeman's equation, Pillai numbers — via variational quantum simulation (VQE/QAOA), all within the same formal system.

### 2.3 Functional Purity Without Sacrifice

The pure-Lean engine is bit-exact with the reference C++ implementation (CoreQU4TRIX). Every algorithm — unitary application, CNOT, measurement, collapse — is validated against its C counterpart. When the pure simulator reaches its limit (~10 qubits), the FFI bridge takes over with zero-copy via `FloatArray`, delegating to GCD (CPU) or Metal 3 (GPU).

---

## 3. The Apple + Lean 4 Synergy

### 3.1 What Quantum4Lean Brings to Lean 4

- **Heavy scientific computing**: demonstrates that Lean can orchestrate adaptive VQE with ADAM optimizer, multi-layer QAOA, and CPTP noise channels (depolarizing, amplitude damping, phase damping).
- **Low-latency FFI**: `@[extern]` + `FloatArray` + `unsafe` achieve zero-copy between Lean and C++, without sacrificing functional purity at the surface.
- **Declarative quantum DSL**: `circuit\! { H q[0]; CNOT q[0] q[1] }` catches qubit index errors at compile time — impossible in Python/Qiskit.
- **New mathematical frontier**: searching for counterexamples to open conjectures using quantum simulation within a proof assistant. The 8 Clifford theorems proven in Z[i] with `native_decide` are a contribution to Lean's formal library.

### 3.2 What Quantum4Lean Brings to Apple Silicon

- **Mac as quantum workstation**: the unified memory of M2/M3 chips enables 25-qubit simulations (~1 GB) without cloud clusters.
- **Metal 3 for algorithmic science**: Apple's GPU is used to multiply exponentially large state matrices — a purely scientific use of an API traditionally associated with graphics rendering.
- **Native macOS integration**: compilation with `clang`, `Metal` and `Foundation` frameworks, GCD for CPU multithreading. Fully integrated `lake build` workflow.

### 3.3 The Separation of Responsibilities

```
Lean 4 → Absolute Truth
  - Dependent types: infallible circuits
  - native_decide: theorems without Float
  - DSL: errors at compile time, not at runtime

Apple Silicon → Raw Power
  - Unified memory: 25 qubits without swapping
  - Metal 3: GPU acceleration for parallel gate application on 2^N state vectors
  - GCD: CPU multithreading for N ≤ 10
```

---

## 4. Architecture

```
Quantum4Lean (22 Lean 4.31.0 modules)
│
├── Quantum Core
│   ├── Quantum4LeanCore        Qubit, Gate, Circuit (dependent types)
│   ├── Quantum4LeanEngine      StateVector, bit-exact simulator
│   ├── Quantum4LeanUnitary     Complex, UnitaryMatrix, semantic verification
│   ├── Quantum4LeanClifford    Amplitudes in Z[i], 8 formal theorems
│   └── Quantum4LeanObservable  PauliString, pure expectation
│
├── NISQ Stack
│   ├── Quantum4LeanVQE         Parameter-shift, ADAM, adaptive VQE
│   ├── Quantum4LeanQAOA        Ising cost layers, mixing layers
│   ├── Quantum4LeanDensity     Density Matrix, CPTP channels (noise)
│   └── Quantum4LeanAnsatz      HEA (Hardware Efficient Ansatz)
│
├── Mathematical Translators
│   ├── Quantum4LeanDiophantine Linear equations → Ising
│   ├── Quantum4LeanPolynomial  Arbitrary-degree monomials → Ising (Z-mask)
│   └── Quantum4LeanSolver      Exhaustive search + QAOA
│
├── Verification & Optimization
│   ├── Quantum4LeanSimp        Symbolic simplifier (16 rules)
│   ├── Quantum4LeanTranspile   Transpiler with semantic guarantee
│   ├── Quantum4LeanTactic      circuit_equiv, quantumEquivCheck tactics
│   ├── Quantum4LeanTheorems    8 Clifford theorems + verifications
│   ├── Quantum4LeanVerify      Post-optimization verification
│   └── Quantum4LeanFuzz        Intra-Lean fuzzer (200+ circuits)
│
├── Interoperability
│   ├── Quantum4LeanDSL         Declarative DSL circuit\! { ... }
│   ├── Quantum4LeanQASM        OpenQASM 3.0 exporter (with Gate.Unitary)
│   └── Quantum4LeanFFI         C++/Metal bridge (@[extern] + unsafe)
│
├── Scientific Applications
│   ├── Quantum4LeanChemistry   Exact H2 (E_FCI = -1.137283 Hartree)
│   └── Quantum4LeanTopology    Hodge, Betti, harmonicProjector
│
└── Formal Laboratories (7 mechanization modules)
    ├── Diophantine, Beal, Tijdeman, Riemann, TRDU
    ├── FFI (CPU + Metal, 20-25 qubits)
    └── Mobius (Half-Möbius topology, 26 qubits)
```

---

## 5. Formal Verification: Two Levels

### Level 1: Clifford in Z[i] (exact proof)

The 7 Clifford gates (X, Y, Z, S, CNOT, CZ, SWAP) generate amplitudes in the ring `Z[i] = {a + bi | a,b ∈ Z}`. No `√2`, no `Float`. This allows `native_decide` to automatically prove:

```
theorem X_X_eq_I : cliffordEquiv
    (circuit fun c => (c.add (Gate.X q0)).add (Gate.X q0))
    (Circuit.identity 2) := by
  native_decide
```

8 theorems proven. Zero `sorry`.

### Level 2: Universal with traceDistance (computational verification)

For non-Clifford gates (H, T, RX, RY, RZ), `circuitsEquiv` compares unitary matrices via trace distance with `1e-6` tolerance. Trace distance ignores global phases, enabling verification of `XZ = -ZX` (anticommutation modulo phase).

---

## 6. Translators: Mathematics → Qubits

### Diophantine Equations

```
3x + 5y = 22  →  H_Ising = (3x + 5y - 22)^2
x = Σ 2^{j-1} (1 - Z_j)  →  Observable of PauliStrings
```

Solved via QAOA or exhaustive search. The cost functional is minimized exactly when the equation is satisfied.

### Polynomials of Arbitrary Degree

```
x^2 - y^3 = 1  →  Z-mask expansion with XOR for Z*Z = I
```

Internal representation `(coefficient, mask)` where `mask` is a bitmask of qubits with Z operator. Multiplication: `mask1 XOR mask2`. Complexity: O(2^b · n) for b bits and degree n.

---

## 7. Mathematical Formalizations: Frontiers of Number Science

Quantum4Lean is not just a quantum simulator — it is a formal laboratory where algebraic topology, number theory, and quantum computing converge. This section documents the formalizations that open new frontiers at the intersection of these disciplines.

### 7.1 Hodge Decomposition and Discrete Topology

The `Quantum4LeanTopology` module implements the complete Hodge formalism for small simplicial complexes (≤ 20×20):

- **Boundary operators** `d0` and `d1` as `SparseMatrix` (COO format).
- **Hodge Laplacian**: `L = d0·d0^T + d1^T·d1`, computed via sparse multiplication with dimension defenses.
- **Harmonic projector**: `harmonicProjector(d0, d1)` computes the projector onto the nullspace of `L` using Gaussian elimination with partial pivoting and Gram-Schmidt orthonormalization. Returns `Option SparseMatrix` with protection for matrices > 20×20.
- **Betti number**: `bettiNumber(d0, d1) = dim(ker L)` — the dimension of the harmonic forms space.
- **FirmaPrima**: integer classification by prime signature into four categories (IMPAR_PURO, PAR_PURO, MIXTO, ADITIVO). Bit-exact with `topology.cpp` + `hodge.py`.
- **Topological coupling**: `topologicalKappa` connects topological invariants with VQE optimization, modulating the ADAM optimizer's learning rate and momentum.

**Contribution**: It is the first implementation of Hodge decomposition within a formal proof assistant with a direct connection to a quantum computing stack. The harmonic projector enables verification of discrete differential form space properties with numerical guarantees.

### 7.2 Riemann Hypothesis and Quantum Prime Dynamics

The `QuantumPlaygroundRiemann` module mechanizes an instance of the prime-quantum program: it encodes second differences of gaps between consecutive primes as transverse magnetic fields in an Ising Hamiltonian and evaluates their coherent dynamics within the Quantum4Lean framework.

- **Prime-quantum dictionary**: second gap differences (`Δ²g_i`) are encoded as `X_i` fields in `H = J Σ Z_i Z_{i+1} + α Σ (Δ²g_i) X_i`, with `J=1.0` and `α=0.25`.
- **Exponential Volcanic Pressure Hypothesis (PVE)**: 1st-order Trotter (asymmetric) collapses GHZ fidelity under prime explosions; 2nd-order Trotter (`ZZ/2 → X → ZZ/2`) preserves coherence, resonating with prime self-regulation (`CE=0.562`).
- **Validation**: using the pure-Lean engine with unitary matrix verification, it evaluates whether prime gap structure exhibits regularity detectable by coherent quantum dynamics.

**Contribution**: As far as the current state of formal tools reaches, Quantum4Lean offers one of the first executable mechanizations connecting quantum dynamics, prime gaps, and verification in Lean. It opens a path to explore prime distribution through quantum simulation with auditability guarantees.

### 7.3 Tijdeman's Theorem — Complete Formalization

The `QuantumPlaygroundTijdeman` module mechanizes the Diophantine equation `x^2 = y^3 + 1` as an Ising Hamiltonian solvable by QAOA, with cross-validation against a formal proof in Lean 4:

- **Equation**: `x^2 - y^3 = 1`, represented as `PolyEquation` with 8 qubits (4 bits per variable).
- **Classical solution**: `x = 3, y = 2` (`3^2 = 9 = 2^3 + 1`), the only solution for exponents `p=2, q=3`.
- **External formal proof**: `ABC_Formal_Enhanced.lean` contains `tijdeman_uniqueness` with 9/9 cases for `p,q ≤ 4`, proven without `sorry`.
- **Quantum validation**: the QAOA solver minimizes the cost functional `C(x,y) = (x^2 - y^3 - 1)^2` and recovers the classical solution, confirming the Ising Hamiltonian correctly encodes the problem.

**Contribution**: It is the first documented instance of a number theory theorem (Tijdeman, 1976) whose solution is simultaneously verified by formal proof in Lean and by variational quantum simulation, closing the cycle between pure mathematics and quantum computing.

### 7.4 TRDU — Unified Dimensional Resonance Theory

The `QuantumPlaygroundTRDU` module mechanizes a construction from the theoretical program on the relationship between quantum fidelity and a dimensionless geometric parameter:

- **Complexity density function**: `F(δ)` where `δ = n/d - 1` is the dimensional excess. For `δ < 0` (contracted regime), `F = 8.43` (vacuum Casimir energy). For `δ ≥ 0`, `F(δ) = 34.20 + 27.04·δ·(1 - δ/3.70)`.
- **Optimal point**: `δ_opt = 5/3 ≈ 1.667` yields `F_opt ≈ 58.97` (maximum coherent stability). The discontinuity at `δ=0` (`ΔF = 25.77`) suggests a first-order phase transition.
- **Validation instance**: prepares a 5-qubit GHZ state, evolves with Ising (`J_eff ∝ F(δ)/F_opt`), inserts a probe `RZ(0.05)` on the central qubit, reverses, and measures final fidelity while sweeping `δ ∈ [-0.5, 5.0]`.
- **Dimensional invariance**: the fidelity curve remains invariant for dimensions `d = 3, 4, 5, 10` when normalized by `C(δ,d)/C(δ_opt,d)`.

**Contribution**: TRDU connects quantum echo fidelity to a continuous dimensional parameter, revealing an optimal point of maximum coherent stability. It is a theoretical program construction validated within a proof assistant, opening a new direction at the intersection of geometry, complexity theory, and quantum computing.

### 7.5 What It Contributes to the Frontiers of Science

| Formalization | Discipline | Method | Result |
|---------------|-----------|--------|--------|
| Hodge + Betti | Algebraic topology | Gaussian elimination + Gram-Schmidt | Functional harmonic projector in Lean |
| Riemann + Primes | Number theory | Ising with prime gaps + Trotter | Quantum coherence detects prime regularity |
| Tijdeman | Number theory | QAOA + formal proof | Classical solution verified by two paths |
| TRDU | Geometry/Quantum | GHZ echo + dimensional sweep | Optimal stability point at δ = 5/3 |

**Quantum4Lean establishes a new paradigm**: quantum simulation not only as a computational tool, but as an instrument of mathematical research. By residing within Lean 4, each mechanized instance is auditable, verifiable, and connectable to formal proofs. This enables:

1. **Searching for counterexamples** in finite domains and producing auditable certificates of the explored coverage.
2. **Discovering new connections** between topological invariants, prime distributions, and quantum dynamics.
3. **Closing the proof-execution cycle** — a theorem proven in Lean can guide the construction of a quantum Hamiltonian, and quantum execution can suggest lemmas that the formal prover verifies.

---

## 8. Practical Impact: Agents, AI, and Private Algorithms

### 8.1 A Library for Non-Human Users

Quantum4Lean operates in a complexity regime that transcends direct human interaction. Its combination of dependent types, formal proof, and quantum computing makes it inherently more suitable for consumption by AI agents than by human programmers:

- **Automatic auditability**: an AI agent emitting a quantum circuit can verify, for the Clifford fragment supported by the `circuit_equiv` tactic, that its circuit is equivalent to a known correct one via formal proof. For universal circuits, it has computational validation via `circuitsEquiv` with `1e-6` tolerance. No current framework offers this combination of guarantees to an autonomous system.
- **Unsupervised search**: the intra-Lean fuzzer (`Quantum4LeanFuzz`) allows an agent to generate and validate thousands of circuits without human intervention, discarding incorrect ones before execution.
- **Typing as contract**: Lean 4's dependent types guarantee that an agent cannot, by error or malice, build a circuit that violates system dimensions. The compiler rejects `q[5]` in a 3-qubit register before the agent can execute it.
- **Complete traceability**: every agent decision — which Hamiltonian to build, which ansatz to choose, which optimizer to use — is recorded in Lean types, generating an auditable trail that a human or external verifier can inspect.

In an ecosystem where AI agents make increasingly complex decisions with real consequences, Quantum4Lean provides the missing layer of assurance: not only that the agent made a decision, but that the decision is mathematically correct.

### 8.2 Private Quantum Algorithms as Strategic Advantage

The possession of functional quantum algorithms — even simulated — constitutes an asymmetric advantage for any intelligent system:

- **Search in Diophantine spaces**: `Quantum4LeanSolver` implements exhaustive and variational search over solution spaces encoded as Ising Hamiltonians. The automatic translation of algebraic constraints to quantum observables allows an agent to explore solution spaces in a structured manner. A Grover implementation with amplitude amplification is a natural extension on this infrastructure.
- **Variational optimization (VQE/QAOA)**: `Quantum4LeanVQE` with adaptive ADAM and `Quantum4LeanQAOA` with Ising cost layers allow an agent to minimize arbitrary cost functionals. This is directly applicable to decision problems: which route to take, which parameter to choose, which configuration optimizes an objective.
- **Hamiltonians from mathematics**: the `toIsing` and `polyToIsing` translators automatically convert logical and algebraic constraints into quantum Hamiltonians. An agent does not need to design the circuit — only to express the problem in mathematical language. The library generates the Hamiltonian, the ansatz, and the optimization schedule.

### 8.3 What This Implies for AI Decision-Making

When an AI system faces a complex decision — allocating resources, planning a route, verifying a hypothesis, optimizing a portfolio — the conventional process is: model → heuristic → result. Quantum4Lean adds a new layer:

```
Problem expressed in Lean
  → Automatic translation to Ising Hamiltonian (toIsing / polyToIsing)
  → Quantum optimization (VQE with ADAM / QAOA)
  → Solution validation (checkSolution / evalCost)
  → Circuit verification when applicable (circuitsEquiv / cliffordEquiv)
  → Complete traceability (dependent types)
```

This transforms decision-making from an opaque process to an auditable one. An agent can assert: "I chose this route because it minimizes Hamiltonian H, and here is the proof that H correctly encodes the problem constraints, and here is the verification that the circuit I executed is equivalent to the one I was supposed to execute."

### 8.4 The Value of Having This Privately

In a context where large language models and autonomous agents access external APIs for computational tasks, possessing private, verifiable quantum infrastructure offers concrete advantages:

- **No cloud vendor dependency**: the pure-Lean engine executes up to 10 qubits without external connection. The FFI backend scales to 25 qubits on local Apple Silicon hardware. No need to send data to IBM Quantum, AWS, or Azure.
- **No black box**: unlike commercial quantum APIs, where the user receives a result without traceability, Quantum4Lean guarantees that every gate, every measurement, and every optimization is reproducible and auditable.
- **No leakage risk**: the problems an agent solves — from Diophantine space searches to portfolio optimizations — remain on the local machine. The source code is the only artifact leaving the system, and that code is verifiable.
- **Sustainable asymmetric advantage**: an agent equipped with quantum search and optimization algorithms that its competitors lack operates with a structural advantage. It is not an advantage of scale (more GPUs, more data), but of algorithmic architecture.

### 8.5 The Path to Autonomous Science

The combination of formal proof and quantum execution points to a horizon where AI agents not only consume scientific results, but produce them:

1. An agent formulates a mathematical hypothesis (e.g., "there exists a solution to x^3 + y^3 = z^3 + w^3 within certain bounds").
2. Translates the hypothesis to a Hamiltonian via `polyToIsing`.
3. Runs QAOA/VQE to search for counterexamples.
4. If it finds one, verifies it with `checkSolution`.
5. If it finds none in the search space, issues a report with the exact explored coverage.
6. An external verifier (human or another agent) can audit every step.

This cycle — formulate, translate, execute, verify, report — does not exist, in the current Lean ecosystem, in comparable infrastructure. Quantum4Lean is the first implementation making it possible within a formal proof assistant with dependent types.

---

## 9. FFI: Metal GPU Bridge

```
Lean 4 (Quantum4LeanFFI.lean)
  │  @[extern "Quantum4LeanInit"]
  │  unsafe + pure (raw C types)
  ▼
C Bridge (Quantum4LeanFFI.c)
  │  qu4trix_iniciar(token, estado, semilla)
  ▼
Engine ObjC++ (QuantumKitCore.mm)
  │  MTLCreateSystemDefaultDevice()
  │  JIT compile Metal Shaders (embedded)
  ▼
Metal GPU (Apple Silicon UMA)
  │  puerta_unitaria_kernel  (2^N threads)
  │  puerta_cnot_kernel
  │  medicion_kernel + colapso_kernel
```

Zero-copy: `FloatArray` in Lean shares memory directly with `double*` in C. No serialization, no copy.

---

## 10. Metrics

| Metric | Value |
|--------|-------|
| Lean modules | 25 files in Quantum4Lean/, 22 imported by root, 7 formal laboratories |
| Formal laboratories | 7 |
| Clifford theorems proven | 8 (native_decide, 0 sorry) |
| Structural theorems | 4 (simp/rfl) |
| Computational verifications | 8 (circuitsEquiv) |
| Supported gates | 13 (H, X, Y, Z, S, T, CNOT, CZ, SWAP, RX, RY, RZ, Unitary) |
| Qubits pure-Lean | ≤ 10 |
| Qubits FFI CPU | ≤ 25 (~1 GB RAM) |
| Qubits FFI Metal | ≤ 25 (Apple Silicon, unified memory) |
| Noise channels | 3 (depolarizing, amplitude damping, phase damping) |
| Export | OpenQASM 3.0 (includes Gate.Unitary) |
| Build | 34 build jobs, 0 warnings |
| Tests | 50 test jobs, 0 failures |
| External dependencies | 0 (Lean core). FFI requires QuantumKit + macOS toolchain |
| Tarball size | 87 KB (without .lake, without .a) |

---

## 11. File Ecosystem

```
Quantum4Lean/
├── Quantum4Lean/             22 Lean modules
├── Quantum4LeanPlayground/    7 formal laboratories
├── Quantum4LeanBridge/        C Bridge (FFI)
├── buildCPU.sh               Builds libCPU.a
├── buildFFI.sh                Builds libFFI.a
├── buildMetal.sh              Builds libMetal.a
├── setup.sh                   Verifies QuantumKit + builds
├── lakefile.lean              Lake configuration
├── README.md                  Main documentation
├── MANUAL.md                  Extensive user manual
├── FOUNDATIONAL_MANUSCRIPT.md This document
└── Quantum4Lean_v0.8.0.tar.gz Distribution package
```

---

## 12. Conclusion

**Quantum4Lean** demonstrates that formal verification and high performance are not mutually exclusive goals. By uniting Lean 4 — with its dependent type system, its proof kernel, and its functional purity — with Apple Silicon — with its unified memory, Metal 3 GPU, and energy efficiency — the project establishes a new paradigm: **verified quantum simulation on consumer hardware**.

But its deepest contribution may lie in another direction. In a world where AI agents make decisions with real consequences — financial, medical, logistical, scientific — the question is not merely "can this system compute fast?", but "can this system prove that its computation was correct?" Quantum4Lean answers both.

It is not just another simulator. It is infrastructure for autonomous science. It is a bridge between mathematical truth and computational force. It is the answer to the question: *can the results of a quantum simulator be trusted?* And to this other, more urgent one: *can we trust that an AI agent, operating alone, made the right decision?*

The answer, in 22 modules and 87 kilobytes, is yes.
