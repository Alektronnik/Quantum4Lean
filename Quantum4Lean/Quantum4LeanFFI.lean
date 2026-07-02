/-
Quantum4LeanFFI.lean
Interfaz de Funciones Foraneas (FFI) -- Bindings directos a Quantum4LeanBridge.c

Las declaraciones @[extern] mapean 1:1 con las firmas C de Quantum4LeanBridge.h.
Tipos Lean -> C:
  USize   -> uint64_t (token, semilla)
  Float   -> double   (amplitudes, parametros)
  Int     -> int      (codigos de error, indices)
  Ptr Float -> double* (state vector, buffers)
-/

import Lean

namespace Quantum4Lean.FFI

-- --- Codigos de error ------------------------------------------

def errorOK               : Int := 0
def errorNoInit           : Int := 201
def errorQubitRange       : Int := 202
def errorQubitsMax        : Int := 203
def errorNullPointer      : Int := 205
def errorTokenMismatch    : Int := 207
def errorMemoria          : Int := 208

-- --- Ciclo de vida ---------------------------------------------

@[extern "Quantum4LeanInit"]
opaque quantum4LeanInit (numQubits : Int) (estadoInicial : Ptr Float)
                         (semilla : USize) (tokenOut : Ptr USize) : IO Int

@[extern "Quantum4LeanFinalize"]
opaque quantum4LeanFinalize (token : USize) : IO Int

@[extern "Quantum4LeanMemoryEstimate"]
opaque quantum4LeanMemoryEstimate (numQubits : Int) : IO USize

-- --- Puertas ---------------------------------------------------

@[extern "Quantum4LeanApplyGate"]
opaque quantum4LeanApplyGate (token : USize) (tipo : Int) (qA qB : Int)
                              (parametro : Float) (estadoIO : Ptr Float) : IO Int

@[extern "Quantum4LeanApplyUnitary"]
opaque quantum4LeanApplyUnitary (token : USize) (q : Int)
                                 (matriz : Ptr Float) (estadoIO : Ptr Float) : IO Int

-- --- Medicion --------------------------------------------------

@[extern "Quantum4LeanMeasure"]
opaque quantum4LeanMeasure (token : USize) (qubitK : Int)
                            (estadoIO : Ptr Float) (bitOut : Ptr Int) : IO Int

-- --- Probabilidades --------------------------------------------

@[extern "Quantum4LeanProbabilities"]
opaque quantum4LeanProbabilities (token : USize) (estado : Ptr Float)
                                  (probsOut : Ptr Float) : IO Int

-- --- Telemetria ------------------------------------------------

@[extern "Quantum4LeanTelemetry"]
opaque quantum4LeanTelemetry (token : USize) (nOut dimOut cyclesOut : Ptr Int) : IO Int

-- --- Utilidades de memoria -------------------------------------

@[extern "Quantum4LeanAllocState"]
opaque quantum4LeanAllocState (numQubits : Int) : IO (Ptr Float)

@[extern "Quantum4LeanFreeState"]
opaque quantum4LeanFreeState (estado : Ptr Float) : IO Unit

end Quantum4Lean.FFI
