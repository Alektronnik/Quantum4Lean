/-
QuantumPlaygroundChemistry.lean
Demo: VQE variacional sobre Hamiltonianos moleculares.

Usa el modulo Quantum4LeanChemistry para generar Observables
a partir de integrales moleculares (H2, LiH) y optimiza
la energia con VQE (parameter-shift + ADAM).
-/

import Quantum4Lean

open Quantum4Lean

namespace Quantum4LeanPlayground.Chemistry

/--
Ejecuta VQE sobre un Observable molecular y reporta resultados.
-/
def runMolecularVQE (name : String) (obs : Observable) (nQubits : Nat)
    (p : Nat := 1) (lr : Float := 0.05) (iters : Nat := 200) : IO Unit := do
  IO.println s!"\n=== {name} ==="
  IO.println s!"  Qubits: {nQubits}"
  IO.println s!"  PauliStrings: {obs.strings.length}"
  
  let ansatz (params : List Float) : Circuit nQubits :=
    (qaoaIsingCircuit nQubits p 1.0 0.5) params
  
  let nParams := 2 * p
  let initialParams := List.replicate nParams 0.1
  
  let (energy, _, _) := vqe ansatz obs initialParams lr iters
  
  IO.println s!"  E(VQE) = {energy}"
  IO.println s!"  Parametros: p={p}, lr={lr}, iters={iters}"

/--
Demo principal: H2 y LiH con VQE.
-/
def main : IO Unit := do
  IO.println "Quimica Cuantica con Quantum4Lean"
  IO.println "==================================="
  IO.println "Jordan-Wigner + VQE sobre Hamiltonianos moleculares"
  
  -- H2: 4 qubits, 240 PauliStrings
  runMolecularVQE "H2 (Hidrogeno Molecular)" h2Observable 4 1 0.05 200
  
  -- LiH: 6 qubits
  runMolecularVQE "LiH (Hidruro de Litio)" lihObservable 6 1 0.05 150
  
  IO.println "\nNota: Coeficientes aproximados (STO-3G)."
  IO.println "Para precision quimica (<1kcal/mol) se requieren"
  IO.println "integrales exactas de PySCF/libint."

end Quantum4LeanPlayground.Chemistry
