/-
Quantum4LeanExamples.lean
Ejemplos de uso de Quantum4Lean.

Dos estilos:
1. Via tipos dependientes (Circuit n, run) -- verificacion estatica
2. Via monada (QuantumM, runQuantum) -- el usuario nunca toca punteros
-/

import Quantum4Lean

namespace Quantum4Lean.Examples

-- =====================================================================
-- ESTILO 1: Tipos dependientes (Circuit n)
-- =====================================================================

-- --- Bell state -------------------------------------------------

def bell : Circuit 2 :=
  let q0 : Qubit 2 := ⟨⟨0, by decide⟩⟩
  let q1 : Qubit 2 := ⟨⟨1, by decide⟩⟩
  circuit fun c => (c.add (Gate.H q0)).add (Gate.CNOT q0 q1)

-- --- GHZ (Greenberger-Horne-Zeilinger) --------------------------

def ghz (n : Nat) (hn : n >= 1) : Circuit n :=
  let q0 : Qubit n := ⟨⟨0, by omega⟩⟩
  let step (c' : Circuit n) (i : Nat) : Circuit n :=
    if h : i < n then
      let qi : Qubit n := ⟨⟨i, h⟩⟩
      let qprev : Qubit n := ⟨⟨i-1, by omega⟩⟩
      c'.add (Gate.CNOT qprev qi)
    else
      c'
  let base := (Circuit.identity n).add (Gate.H q0)
  List.range n |>.foldl (fun c i => step c i) base

-- --- Grover 2-qubit ---------------------------------------------

def grover2 : Circuit 2 :=
  let q0 : Qubit 2 := ⟨⟨0, by decide⟩⟩
  let q1 : Qubit 2 := ⟨⟨1, by decide⟩⟩
  circuit fun c =>
    let c := (c.add (Gate.H q0)).add (Gate.H q1)
    let c := c.add (Gate.CZ q0 q1)
    let c := (c.add (Gate.H q0)).add (Gate.H q1)
    let c := (c.add (Gate.X q0)).add (Gate.X q1)
    let c := c.add (Gate.CZ q0 q1)
    let c := (c.add (Gate.X q0)).add (Gate.X q1)
    let c := (c.add (Gate.H q0)).add (Gate.H q1)
    c

-- --- Quantum Fourier Transform (3 qubits) -----------------------

def qft3 : Circuit 3 :=
  let q0 : Qubit 3 := ⟨⟨0, by decide⟩⟩
  let q1 : Qubit 3 := ⟨⟨1, by decide⟩⟩
  let q2 : Qubit 3 := ⟨⟨2, by decide⟩⟩
  circuit fun c =>
    let c := c.add (Gate.H q2)
    let c := c.add (Gate.RZ q1 (Float.pi / 2.0))
    let c := c.add (Gate.CNOT q2 q1)
    let c := c.add (Gate.RZ q1 (-Float.pi / 2.0))
    let c := c.add (Gate.CNOT q2 q1)
    let c := c.add (Gate.H q1)
    let c := c.add (Gate.RZ q0 (Float.pi / 4.0))
    let c := c.add (Gate.CNOT q2 q0)
    let c := c.add (Gate.RZ q0 (-Float.pi / 4.0))
    let c := c.add (Gate.CNOT q2 q0)
    let c := c.add (Gate.RZ q0 (Float.pi / 2.0))
    let c := c.add (Gate.CNOT q1 q0)
    let c := c.add (Gate.RZ q0 (-Float.pi / 2.0))
    let c := c.add (Gate.CNOT q1 q0)
    let c := c.add (Gate.H q0)
    let c := c.add (Gate.CNOT q0 q2)
    let c := c.add (Gate.CNOT q2 q0)
    let c := c.add (Gate.CNOT q0 q2)
    c

-- --- Verificacion de propiedades --------------------------------

#eval bell.depth

#eval grover2.depth

example : (bell.cancelHadamardPairs).depth <= bell.depth := by
  simp [Circuit.cancelHadamardPairs]

-- =====================================================================
-- ESTILO 2: Monada cuantica (QuantumM) -- cero punteros visibles
-- =====================================================================

/--
Bell state via monada.
El usuario escribe puertas directamente, sin Qubit n, sin Circuit n.
-/
def bellMonad : QuantumM Unit := do
  QuantumM.h 0
  QuantumM.cnot 0 1

/--
GHZ de 3 qubits via monada.
-/
def ghz3Monad : QuantumM Unit := do
  QuantumM.h 0
  QuantumM.cnot 0 1
  QuantumM.cnot 1 2

/--
Grover 2-qubit via monada.
-/
def grover2Monad : QuantumM Unit := do
  -- Superposicion uniforme
  QuantumM.h 0
  QuantumM.h 1
  -- Oraculo: marca |11>
  QuantumM.cz 0 1
  -- Difusor
  QuantumM.h 0
  QuantumM.h 1
  QuantumM.x 0
  QuantumM.x 1
  QuantumM.cz 0 1
  QuantumM.x 0
  QuantumM.x 1
  QuantumM.h 0
  QuantumM.h 1

/--
Ejecuta el Bell state y mide.
-/
def runBellMonad : IO (Except String (List Int)) :=
  runQuantum (numQubits := 2) do
    bellMonad
    QuantumM.measureAll

/--
Ejecuta GHZ-3 y devuelve bits + probabilidades.
-/
def runGHZ3Monad : IO (Except String (List Int × List Float)) :=
  runQuantum (numQubits := 3) do
    ghz3Monad
    let bits <- QuantumM.measureAll
    let probs <- QuantumM.probabilities
    pure (bits, probs)

/--
Ejecuta Grover-2.
-/
def runGrover2Monad : IO (Except String (List Int)) :=
  runQuantum (numQubits := 2) do
    grover2Monad
    QuantumM.measureAll

-- =====================================================================
-- MaxCut: benchmark de optimizacion combinatoria via QAOA
-- =====================================================================

/--
Grafo triangulo (3 vertices, 3 aristas).
MaxCut optimo: cortar 2 aristas de 3.
-/
def maxCutTriangle : Observable :=
  -- H_C = -0.5 * (Z_0 Z_1 + Z_1 Z_2 + Z_0 Z_2)
  -- Cada termino ZZ vale -1 si los vertices estan en el mismo conjunto
  let edges := [
    ([PauliTerm.mk .Z 0, PauliTerm.mk .Z 1], 0.5),
    ([PauliTerm.mk .Z 1, PauliTerm.mk .Z 2], 0.5),
    ([PauliTerm.mk .Z 0, PauliTerm.mk .Z 2], 0.5)
  ]
  { strings := edges.map fun (terms, coeff) =>
      PauliString.mk coeff terms
  }

/--
MaxCut en grafo lineal de 4 vertices.
Optimo: alternar conjuntos -> 3 aristas cortadas.
-/
def maxCutLine4 : Observable :=
  let edges := [
    ([PauliTerm.mk .Z 0, PauliTerm.mk .Z 1], 0.5),
    ([PauliTerm.mk .Z 1, PauliTerm.mk .Z 2], 0.5),
    ([PauliTerm.mk .Z 2, PauliTerm.mk .Z 3], 0.5)
  ]
  { strings := edges.map fun (terms, coeff) =>
      PauliString.mk coeff terms
  }

/--
Ejecuta QAOA(p=1) para MaxCut en triangulo.
Esperado: energia cercana al optimo -1.0.
-/
def runMaxCutTriangle : IO (Except String (Float × List Float × List Float)) :=
  runQuantum (numQubits := 3) do
    qaoa 3 maxCutTriangle 1 (learningRate := 0.1) (maxIter := 80)

/--
Ejecuta QAOA(p=2) para MaxCut en linea de 4.
-/
def runMaxCutLine4 : IO (Except String (Float × List Float × List Float)) :=
  runQuantum (numQubits := 4) do
    qaoa 4 maxCutLine4 2 (learningRate := 0.05) (maxIter := 100)

/--
Benchmark: VQE para Ising 4-qubit.
Comparable contra Qiskit/Cirq.
-/
def runIsingVQEBenchmark : IO (Except String (Float × List Float × List Float)) :=
  runQuantum (numQubits := 4) do
    let H := Observable.ising1D 4 1.0 0.5
    let params := List.replicate 8 0.1
    vqe (isingAnsatz 4 1) H params (learningRate := 0.05) (maxIter := 50)

end Quantum4Lean.Examples

