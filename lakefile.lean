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
  roots := #[`Quantum4Lean]

/--
Ejecutable de validacion: tests unitarios + fuzzer.
  lake build && ./build/bin/quantum4lean-test
-/
lean_exe «quantum4lean-test» where
  root := `Quantum4Lean.Quantum4LeanRunner
