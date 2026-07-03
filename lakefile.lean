import Lake

open Lake DSL

/--
Quantum4Lean — Computacion Cuantica Verificada en Lean 4.

Motor puro-Lean bit-exacto con CoreQU4TRIX (C++/Metal).
Stack NISQ completo: StateVector, Observables, VQE, QAOA.
Fuzzer intra-Lean, verificacion semantica (UnitaryMatrix).

Build autocontenido. Cero dependencias externas.
  lake build && ./build/bin/quantum4lean-test

Puente FFI a Apple Silicon/Metal 3 opcional.
-/

package «Quantum4Lean» where
  leanOptions := #[⟨`pp.unicode.fun, true⟩]

@[default_target]
lean_lib «Quantum4Lean» where
  roots := #[`Quantum4Lean, `Quantum4LeanPlayground]

/--
Ejecutable de validacion: tests unitarios + fuzzer.
  lake build && ./build/bin/quantum4lean-test
-/
lean_exe «quantum4lean-test» where
  root := `Quantum4Lean.Quantum4LeanRunner

/--
Ejecutable de teoremas: verificacion formal + computacional.
  lake build quantum4lean-theorems && .lake/build/bin/quantum4lean-theorems
-/
lean_exe «quantum4lean-theorems» where
  root := `Quantum4Lean.Quantum4LeanTheorems

/--
Ejecutable FFI (CPU-only): puente a motor C++ sin Metal.
  bash buildCPU.sh && lake build quantum4lean-ffi
-/
lean_exe «quantum4lean-ffi» where
  root := `Quantum4LeanPlayground.QuantumPlaygroundFFICPU
  moreLinkArgs := #[
    "-L.", "-lQuantum4LeanCPU",
    "-L", "/Users/bezalelizquierdoperez/.elan/toolchains/leanprover--lean4---v4.31.0/lib",
    "-lgmp"
  ]

/--
Ejecutable FFI (Metal GPU): puente a motor C++ con Metal en Apple Silicon.
  bash buildMetal.sh && LEAN_CC=clang lake build quantum4lean-ffi-metal
Requiere LEAN_CC=clang para enlazar frameworks Apple.
-/
lean_exe «quantum4lean-ffi-metal» where
  root := `Quantum4LeanPlayground.QuantumPlaygroundFFIMetal
  moreLinkArgs := #[
    "-L.", "-lQuantum4LeanMetal",
    "-L", "/Users/bezalelizquierdoperez/.elan/toolchains/leanprover--lean4---v4.31.0/lib",
    "-lgmp",
    "-framework", "Metal", "-framework", "Foundation"
  ]
