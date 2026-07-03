/-
Quantum4LeanFFI.lean
FFI a Quantum4LeanBridge.c via FloatArray (Lean 4.7.0 compatible).

El motor C++ opera in-place sobre FloatArray (double*).
La memoria se gestiona desde Lean.
-/

import Lean

namespace Quantum4Lean.FFI

def errorOK : Int := 0

/-- Inicializa motor: devuelve token (0 = error). --/
@[extern "Quantum4LeanInit"]
opaque quantum4LeanInit (numQubits : Int) (estado : FloatArray) (semilla : USize) : IO USize

/-- Finaliza motor. --/
@[extern "Quantum4LeanFinalize"]
opaque quantum4LeanFinalize (token : USize) : IO Int

/-- Memoria estimada para N qubits (bytes). --/
@[extern "Quantum4LeanMemoryEstimate"]
opaque quantum4LeanMemoryEstimate (numQubits : Int) : IO USize

/-- Aplica puerta in-place sobre estado. --/
@[extern "Quantum4LeanApplyGate"]
opaque quantum4LeanApplyGate (token : USize) (tipo : Int) (qA qB : Int)
                              (parametro : Float) (estado : FloatArray) : IO Int

/-- Mide qubit k. Devuelve bit (0 o 1). Estado colapsado in-place. --/
@[extern "Quantum4LeanMeasure"]
opaque quantum4LeanMeasure (token : USize) (qubitK : Int) (estado : FloatArray) : IO Int

/-- Calcula probabilidades (requiere pre-alocar probs de tamano 2^N). --/
@[extern "Quantum4LeanProbabilities"]
opaque quantum4LeanProbabilities (token : USize) (estado : FloatArray) (probs : FloatArray) : IO Int

end Quantum4Lean.FFI
