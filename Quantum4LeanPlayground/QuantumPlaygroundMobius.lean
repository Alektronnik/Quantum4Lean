/-
QuantumPlaygroundMobius.lean
Simulacion del experimento "Half-Mobius" C13Cl2 (IBM, Science 2026).

Recrea la topologia electronica de media cinta de Mobius:
  - Jordan-Wigner + Hardware Efficient Ansatz
  - adamVQE sobre Hamiltonianos moleculares
  - Carga dinamica de Observables masivos (26 qubits)

Modos:
  - Dry Run (LiH, 6 qubits): validacion del pipeline
  - Completo (C13Cl2, 26 qubits): requiere FFI + ObservableLoader
-/

import Quantum4Lean
import Quantum4LeanPlayground.MobiusAnsatz

open Quantum4Lean
open Quantum4LeanPlayground.Mobius

namespace Quantum4LeanPlayground.Mobius

/--
Ejecuta VQE con Hardware Efficient Ansatz + ADAM.
Modo Dry Run: ansatz de baja profundidad, pocas iteraciones.
-/
def runMobiusVQE (name : String) (obs : Observable) (nQubits : Nat)
    (depth : Nat := 2) (lr : Float := 0.01) (iters : Nat := 100) : IO Unit := do
  IO.println s!"\n=== {name} ==="
  IO.println s!"  Qubits: {nQubits}"
  IO.println s!"  PauliStrings: {obs.strings.length}"
  IO.println s!"  Ansatz: HEA depth={depth} ({2 * nQubits * depth} params)"

  let nParams := 2 * nQubits * depth
  let ansatz (params : List Float) : Circuit nQubits :=
    mobiusAnsatz nQubits depth params

  let initialParams := List.replicate nParams 0.1
  let m0 := List.replicate nParams 0.0
  let v0 := List.replicate nParams 0.0

  let (energy, _, _) := adamVQELoop ansatz obs initialParams m0 v0
    lr 0.9 0.999 1e-8 iters 1e-6 0 0.0 []

  IO.println s!"  E(ADAM-VQE) = {energy}"
  IO.println s!"  Parametros: depth={depth}, lr={lr}, iters={iters}"

/--
Demo principal: Experimento Half-Mobius.
Modo Dry Run con H2 y LiH (6 qubits max, sin FFI).
-/
def main : IO Unit := do
  IO.println "Experimento Half-Mobius C13Cl2"
  IO.println "==================================="
  IO.println "IBM Research / Science, Marzo 2026"
  IO.println "Simulacion con Quantum4Lean + Jordan-Wigner + HEA + ADAM"
  IO.println ""
  IO.println "Modo: Dry Run (validacion del pipeline)"
  IO.println "Limitacion: Motor puro-Lean (max 10 qubits)"
  IO.println ""

  -- Dry Run: H2 (4 qubits)
  runMobiusVQE "H2 (Hidrogeno Molecular)" h2Observable 4 2 0.01 80

  -- Dry Run: LiH (6 qubits)
  runMobiusVQE "LiH (Hidruro de Litio)" lihObservable 6 2 0.01 60

  IO.println ""
  IO.println "---"
  IO.println "Para C13Cl2 (26 qubits) se requiere:"
  IO.println "  1. ObservableLoader + JSON externo"
  IO.println "  2. Motor FFI (Metal 3) vinculado"
  IO.println "  3. Ansatz depth >= 4, iters >= 500"
  IO.println "Infraestructura lista. FFI pendiente de enlace."

end Quantum4LeanPlayground.Mobius
