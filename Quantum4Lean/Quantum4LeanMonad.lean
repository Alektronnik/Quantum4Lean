/-
Quantum4LeanMonad.lean
Monada cuantica segura. Encapsula la gestion manual de memoria (token,
state vector, FFI) detras de una API limpia.

Errores tipados: QuantumError en lugar de strings. El usuario puede
hacer pattern matching sobre el error para decidir recuperacion.

  def bell : QuantumM Unit := do
    QuantumM.h 0
    QuantumM.cnot 0 1
    QuantumM.measureAll

  #eval runQuantum (numQubits := 2) bell

La monada garantiza:
  - init/finalize automatico del motor
  - alloc/free del state vector via bracket
  - propagacion de errores del motor como QuantumError
-/

import Quantum4Lean.Quantum4LeanFFI
import Quantum4Lean.Quantum4LeanError

namespace Quantum4Lean

-- --- Contexto del motor -----------------------------------------

structure QuantumContext where
  token     : USize
  statePtr  : Ptr Float
  numQubits : Nat
  seed      : USize
  deriving Inhabited

-- --- Monada cuantica -------------------------------------------

abbrev QuantumM (α : Type) := StateT QuantumContext (ExceptT QuantumError IO) α

namespace QuantumM

-- --- Operaciones internas (FFI) --------------------------------

private def applyGate (code : Int) (qA qB : Int) (theta : Float := 0.0) : QuantumM Unit := do
  let ctx <- get
  let ret <- Quantum4Lean.FFI.quantum4LeanApplyGate ctx.token code qA qB theta ctx.statePtr
  if ret ≠ Quantum4Lean.FFI.errorOK then
    throw (.internal s\!"applyGate({code},{qA}) fallo: codigo {ret}")
  let ctx' <- get
  if ctx'.token \!= ctx.token then
    throw .tokenMismatch

private def applyUnitary (q : Int) (matrix : FloatArray 8) : QuantumM Unit := do
  let ctx <- get
  let matPtr : Ptr Float := .ofAddr (ptrAddr matrix)
  let ret <- Quantum4Lean.FFI.quantum4LeanApplyUnitary ctx.token q matPtr ctx.statePtr
  if ret ≠ Quantum4Lean.FFI.errorOK then
    throw (.internal s\!"applyUnitary({q}) fallo: codigo {ret}")

-- --- Puertas de 1 qubit ----------------------------------------

def h (q : Int) : QuantumM Unit := applyGate 0 q 0
def x (q : Int) : QuantumM Unit := applyGate 1 q 0
def y (q : Int) : QuantumM Unit := applyGate 2 q 0
def z (q : Int) : QuantumM Unit := applyGate 3 q 0
def s (q : Int) : QuantumM Unit := applyGate 4 q 0
def t (q : Int) : QuantumM Unit := applyGate 5 q 0

def rx (q : Int) (theta : Float) : QuantumM Unit := applyGate 9 q 0 theta
def ry (q : Int) (theta : Float) : QuantumM Unit := applyGate 10 q 0 theta
def rz (q : Int) (theta : Float) : QuantumM Unit := applyGate 11 q 0 theta

-- --- Puertas de 2 qubits ---------------------------------------

def cnot (c t : Int) : QuantumM Unit := applyGate 6 c t
def cz (c t : Int) : QuantumM Unit := applyGate 7 c t
def swap (a b : Int) : QuantumM Unit := applyGate 8 a b

-- --- Medicion --------------------------------------------------

def measure (q : Int) : QuantumM Int := do
  let ctx <- get
  let mut bit : Int := 0
  let bitPtr : Ptr Int := .ofAddr (ptrAddr bit)
  let ret <- Quantum4Lean.FFI.quantum4LeanMeasure ctx.token q ctx.statePtr bitPtr
  if ret ≠ Quantum4Lean.FFI.errorOK then
    throw (.internal s\!"measure({q}) fallo: codigo {ret}")
  pure bit

def measureAll : QuantumM (List Int) := do
  let ctx <- get
  let mut bits : List Int := []
  for qi in [0:ctx.numQubits.toInt'] do
    let mut bit : Int := 0
    let bitPtr : Ptr Int := .ofAddr (ptrAddr bit)
    let ret <- Quantum4Lean.FFI.quantum4LeanMeasure ctx.token qi ctx.statePtr bitPtr
    if ret ≠ Quantum4Lean.FFI.errorOK then
      throw (.internal s\!"measureAll({qi}) fallo: codigo {ret}")
    bits := bit :: bits
  pure bits.reverse

-- --- Probabilidades --------------------------------------------

def probabilities : QuantumM (List Float) := do
  let ctx <- get
  let dim := 1 <<< ctx.numQubits
  let probPtr <- Quantum4Lean.FFI.quantum4LeanAllocState ctx.numQubits.toInt'
  if probPtr.isNull then
    throw (.memoria (dim.toUSize * 8))
  let ret <- Quantum4Lean.FFI.quantum4LeanProbabilities ctx.token ctx.statePtr probPtr
  if ret ≠ Quantum4Lean.FFI.errorOK then
    Quantum4Lean.FFI.quantum4LeanFreeState probPtr
    throw (.internal s\!"probabilities fallo: codigo {ret}")
  let mut probs : List Float := []
  for i in [0:dim.toInt'] do
    probs := (probPtr.addr ⟨i⟩).getFloat :: probs
  Quantum4Lean.FFI.quantum4LeanFreeState probPtr
  pure probs.reverse

-- --- Telemetria ------------------------------------------------

def telemetry : QuantumM (Int × Int × Int) := do
  let ctx <- get
  let mut nOut : Int := 0
  let mut dimOut : Int := 0
  let mut cyclesOut : Int := 0
  let nPtr  : Ptr Int := .ofAddr (ptrAddr nOut)
  let dPtr  : Ptr Int := .ofAddr (ptrAddr dimOut)
  let cdPtr : Ptr Int := .ofAddr (ptrAddr cyclesOut)
  Quantum4Lean.FFI.quantum4LeanTelemetry ctx.token nPtr dPtr cdPtr |>.ignore
  pure (nOut, dimOut, cyclesOut)

end QuantumM

-- --- Ejecutor --------------------------------------------------

/--
Ejecuta una accion cuantica segura.

Inicializa el motor, aloja el state vector, ejecuta action,
y libera todo automaticamente (incluso si hay error).

Uso:
  #eval runQuantum (numQubits := 2) do
    QuantumM.h 0; QuantumM.cnot 0 1; QuantumM.measureAll
-/
def runQuantum {α : Type} [Inhabited α] (numQubits : Nat)
    (seed : USize := 42) (action : QuantumM α) : IO (Except QuantumError α) := do
  if numQubits < 1 || numQubits > 30 then
    return .error (.qubitsMax numQubits.toInt' 30)

  let mut token : USize := 0
  let tokenPtr : Ptr USize := .ofAddr (ptrAddr token)
  let initRet <- Quantum4Lean.FFI.quantum4LeanInit numQubits.toInt' (.null) seed tokenPtr
  if initRet ≠ Quantum4Lean.FFI.errorOK then
    return .error (.internal s\!"init fallo: codigo {initRet}")

  let sv <- Quantum4Lean.FFI.quantum4LeanAllocState numQubits.toInt'
  if sv.isNull then
    Quantum4Lean.FFI.quantum4LeanFinalize token |>.ignore
    return .error (.memoria (estimateBytes numQubits))

  try
    let ctx : QuantumContext :=
      { token := token, statePtr := sv, numQubits := numQubits, seed := seed }
    let resultIO := action.run ctx
    let result <- resultIO
    match result with
    | .error e => return .error e
    | .ok (val, _) => return .ok val
  finally
    Quantum4Lean.FFI.quantum4LeanFreeState sv
    Quantum4Lean.FFI.quantum4LeanFinalize token |>.ignore

end Quantum4Lean
