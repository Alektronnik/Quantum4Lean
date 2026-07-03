/-
Quantum4LeanFFI.lean
FFI a Quantum4LeanBridge.c via FloatArray (Lean 4.31.0 compatible).

Las funciones `@[extern]` NO usan `IO` en su firma C; retornan tipos crudos.
Se envuelven en `unsafe` + `pure` para producirlas en el contexto `IO`.

Tipos FFI Lean -> C:
  UInt32     -> uint32_t
  UInt64     -> uint64_t
  Float      -> double
  FloatArray -> double*  (puntero crudo al array subyacente)

El motor C++ opera in-place sobre FloatArray (double*).
La memoria se gestiona desde Lean.
-/

import Lean

namespace Quantum4Lean.FFI

-- ===================================================================
-- Capa cruda: @[extern] sin IO. unsafe en el llamador.
-- ===================================================================

-- Test minimo: verifica que FFI funciona
@[extern "Quantum4LeanTestPing"]
private opaque quantum4LeanTestPingRaw (x : UInt32) : UInt32

def quantum4LeanTestPing (x : UInt32) : IO UInt32 :=
  pure (unsafe quantum4LeanTestPingRaw x)

@[extern "Quantum4LeanInit"]
private opaque quantum4LeanInitRaw (numQubits : UInt32) (estado : FloatArray) (semilla : UInt64) : UInt64

@[extern "Quantum4LeanFinalize"]
private opaque quantum4LeanFinalizeRaw (token : UInt64) : UInt32

@[extern "Quantum4LeanMemoryEstimate"]
private opaque quantum4LeanMemoryEstimateRaw (numQubits : UInt32) : UInt64

@[extern "Quantum4LeanApplyGate"]
private opaque quantum4LeanApplyGateRaw (token : UInt64) (tipo : UInt32) (qA qB : UInt32)
                              (parametro : Float) (estado : FloatArray) : UInt32

@[extern "Quantum4LeanMeasure"]
private opaque quantum4LeanMeasureRaw (token : UInt64) (qubitK : UInt32) (estado : FloatArray) : UInt32

@[extern "Quantum4LeanProbabilities"]
private opaque quantum4LeanProbabilitiesRaw (token : UInt64) (estado : FloatArray) (probs : FloatArray) : UInt32

-- ===================================================================
-- Capa publica: envuelve unsafe en IO puro
-- ===================================================================

def errorOK : UInt32 := 0

def quantum4LeanInit (numQubits : UInt32) (estado : FloatArray) (semilla : UInt64) : IO UInt64 :=
  pure (unsafe quantum4LeanInitRaw numQubits estado semilla)

def quantum4LeanFinalize (token : UInt64) : IO UInt32 :=
  pure (unsafe quantum4LeanFinalizeRaw token)

def quantum4LeanMemoryEstimate (numQubits : UInt32) : IO UInt64 :=
  pure (unsafe quantum4LeanMemoryEstimateRaw numQubits)

def quantum4LeanApplyGate (token : UInt64) (tipo : UInt32) (qA qB : UInt32)
    (parametro : Float) (estado : FloatArray) : IO UInt32 :=
  pure (unsafe quantum4LeanApplyGateRaw token tipo qA qB parametro estado)

def quantum4LeanMeasure (token : UInt64) (qubitK : UInt32) (estado : FloatArray) : IO UInt32 :=
  pure (unsafe quantum4LeanMeasureRaw token qubitK estado)

def quantum4LeanProbabilities (token : UInt64) (estado : FloatArray) (probs : FloatArray) : IO UInt32 :=
  pure (unsafe quantum4LeanProbabilitiesRaw token estado probs)

end Quantum4Lean.FFI
