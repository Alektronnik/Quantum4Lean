/-
Quantum4LeanCompile.lean
Traductor automatico: Circuit n -> QuantumM Unit.

El matematico demuestra su circuito en el entorno de tipos dependientes
(seguridad en compilacion) y luego lo ejecuta sin reescribir las puertas:

  def miCircuito : Circuit 3 := ...
  #eval runQuantum (numQubits := 3) (compileCircuit miCircuito)

La funcion `compileCircuit` itera las puertas del circuito y genera
las llamadas correspondientes a `QuantumM.h`, `.cnot`, etc.
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanMonad

namespace Quantum4Lean

/--
Compila un `Circuit n` a una secuencia de operaciones `QuantumM Unit`.

Cada puerta del circuito se traduce a la llamada monadica equivalente.
El resultado se puede pasar directamente a `runQuantum`.
-/
def compileCircuit {n : Nat} (c : Circuit n) : QuantumM Unit := do
  for g in c.gates do
    match g with
    | .H q    => QuantumM.h q.idx.val.toInt'
    | .X q    => QuantumM.x q.idx.val.toInt'
    | .Y q    => QuantumM.y q.idx.val.toInt'
    | .Z q    => QuantumM.z q.idx.val.toInt'
    | .S q    => QuantumM.s q.idx.val.toInt'
    | .T q    => QuantumM.t q.idx.val.toInt'
    | .CNOT ctrl tgt =>
        QuantumM.cnot ctrl.idx.val.toInt' tgt.idx.val.toInt'
    | .CZ ctrl tgt =>
        QuantumM.cz ctrl.idx.val.toInt' tgt.idx.val.toInt'
    | .SWAP a b =>
        QuantumM.swap a.idx.val.toInt' b.idx.val.toInt'
    | .RX q theta => QuantumM.rx q.idx.val.toInt' theta
    | .RY q theta => QuantumM.ry q.idx.val.toInt' theta
    | .RZ q theta => QuantumM.rz q.idx.val.toInt' theta
    | .Unitary _ _ =>
        throw (.internal "compileCircuit: unitary arbitraria no soportada en monada (usar run)")

/--
Ejecuta un circuito verificable con una sola llamada.

Equivale a `runQuantum (numQubits := n) (compileCircuit c)`.
-/
def runCircuit {n : Nat} (c : Circuit n) (seed : USize := 42) :
    IO (Except String (List Int)) :=
  runQuantum (numQubits := n) (seed := seed) do
    compileCircuit c
    QuantumM.measureAll

end Quantum4Lean
