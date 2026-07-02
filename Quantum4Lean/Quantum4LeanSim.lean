/-
Quantum4LeanSim.lean
Motor de ejecucion: Compila circuitos a llamadas FFI sobre QuantumKitCore.

Flujo:
  1. Quantum4LeanInit(N, |0...0>) -> token
  2. Quantum4LeanAllocState(N)    -> state vector
  3. Por cada gate en circuit.gates -> Quantum4LeanApplyGate / Quantum4LeanApplyUnitary
  4. Quantum4LeanMeasure / Quantum4LeanProbabilities
  5. Quantum4LeanFreeState + Quantum4LeanFinalize

Toda la gestion de memoria es explicita y segura via finally/IO.
-/

import Quantum4Lean.Quantum4LeanFFI
import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean

-- --- Resultado de medicion -------------------------------------

/--
Resultado de una medicion: lista de bits (0 o 1).
`shots` es el numero de repeticiones para muestreo.
-/
structure MeasureResult where
  bits      : List Int
  probs     : Option (List Float)
  dimension : Int
  cycles    : Int
  deriving Repr

-- --- Motor de simulacion ---------------------------------------

/--
Ejecuta un circuito sobre `n` qubits y devuelve el resultado de medicion.

`shots` controla el muestreo probabilistico. Si `shots = 1`, hace
una sola medicion proyectiva.

Lanza `IO.userError` si hay error en el motor (token invalido, etc.).
-/
def run {n : Nat} (c : Circuit n) (seed : USize := 42) (shots : Nat := 1) :
    IO MeasureResult := do
  let numQ := n.toNat
  if numQ < 1 || numQ > 30 then
    throw <| IO.userError s!"Quantum4LeanInit: numQubits={numQ} fuera de [1,30]"

  let mut token : USize := 0
  let tokenPtr : Ptr USize := .ofAddr (ptrAddr token)
  let initRet <- Quantum4Lean.FFI.quantum4LeanInit numQ.toInt' (.null) seed tokenPtr
  if initRet ≠ Quantum4Lean.FFI.errorOK then
    throw <| IO.userError s!"Quantum4LeanInit fallo: codigo {initRet}"

  let sv <- Quantum4Lean.FFI.quantum4LeanAllocState numQ.toInt'
  if sv.isNull then
    Quantum4Lean.FFI.quantum4LeanFinalize token |>.ignore
    throw <| IO.userError "Quantum4LeanAllocState: memoria insuficiente"

  try
    -- Aplicar puertas secuencialmente
    for g in c.gates do
      match g with
      | .Unitary q m =>
          let matPtr : Ptr Float := .ofAddr (ptrAddr m)
          let qIdx := q.idx.val.toInt'
          let ret <- Quantum4Lean.FFI.quantum4LeanApplyUnitary token qIdx matPtr sv
          if ret ≠ Quantum4Lean.FFI.errorOK then
            throw <| IO.userError s!"quantum4LeanApplyUnitary({qIdx}) fallo: {ret}"
      | gate =>
          let code := gate.toCode
          let qQubits := gate.qubits
          let qIdx := qQubits.head?.map (·.idx.val.toInt') |>.getD 0
          let qBIdx :=
            if qQubits.length >= 2 then qQubits.tail.head.idx.val.toInt' else 0
          let theta : Float :=
            match gate with
            | .RX _ t | .RY _ t | .RZ _ t => t
            | _ => 0.0
          let ret <- Quantum4Lean.FFI.quantum4LeanApplyGate token code qIdx qBIdx theta sv
          if ret ≠ Quantum4Lean.FFI.errorOK then
            throw <| IO.userError s!"quantum4LeanApplyGate({code}, {qIdx}) fallo: {ret}"

    -- Medicion
    let mut allBits : List Int := []

    if shots == 1 then
      for qi in [0:numQ.toInt'] do
        let mut bit : Int := 0
        let bitPtr : Ptr Int := .ofAddr (ptrAddr bit)
        let ret <- Quantum4Lean.FFI.quantum4LeanMeasure token qi sv bitPtr
        if ret ≠ Quantum4Lean.FFI.errorOK then
          throw <| IO.userError s!"quantum4LeanMeasure({qi}) fallo: {ret}"
        allBits := bit :: allBits
      allBits := allBits.reverse
    else
      for _ in [0:shots.toInt'] do
        let newSv <- Quantum4Lean.FFI.quantum4LeanAllocState numQ.toInt'
        if newSv.isNull then
          throw <| IO.userError "Quantum4LeanAllocState: memoria insuficiente en muestreo"
        for g in c.gates do
          match g with
          | .Unitary q m =>
              let ret <- Quantum4Lean.FFI.quantum4LeanApplyUnitary token q.idx.val.toInt'
                        (.ofAddr (ptrAddr m)) newSv
              if ret ≠ Quantum4Lean.FFI.errorOK then
                throw <| IO.userError s!"unitary fail: {ret}"
          | gate =>
              let code := gate.toCode
              let qIdx := gate.qubits.head?.map (·.idx.val.toInt') |>.getD 0
              let qBIdx :=
                if gate.qubits.length >= 2 then gate.qubits.tail.head.idx.val.toInt'
                else 0
              let theta := match gate with
                | .RX _ t | .RY _ t | .RZ _ t => t | _ => 0.0
              let ret <- Quantum4Lean.FFI.quantum4LeanApplyGate token code qIdx qBIdx theta newSv
              if ret ≠ Quantum4Lean.FFI.errorOK then
                throw <| IO.userError s!"gate fail: {ret}"
        let mut bit : Int := 0
        let bitPtr : Ptr Int := .ofAddr (ptrAddr bit)
        let ret <- Quantum4Lean.FFI.quantum4LeanMeasure token 0 newSv bitPtr
        if ret ≠ Quantum4Lean.FFI.errorOK then
          throw <| IO.userError s!"measure fail: {ret}"
        allBits := bit :: allBits
        Quantum4Lean.FFI.quantum4LeanFreeState newSv

    -- Probabilidades (opcional)
    let dim := 1 <<< numQ
    let probPtr <- Quantum4Lean.FFI.quantum4LeanAllocState numQ.toInt'
    let mut probs : List Float := []
    if !probPtr.isNull then
      let ret <- Quantum4Lean.FFI.quantum4LeanProbabilities token sv probPtr
      if ret == Quantum4Lean.FFI.errorOK then
        for i in [0:dim.toInt'] do
          probs := (probPtr.addr ⟨i⟩).getFloat |> probs.cons
        probs := probs.reverse
      Quantum4Lean.FFI.quantum4LeanFreeState probPtr

    -- Telemetria
    let mut cycles : Int := 0
    let cdPtr : Ptr Int := .ofAddr (ptrAddr cycles)
    let nPtr  : Ptr Int := .ofAddr (ptrAddr numQ.toInt')
    let dPtr  : Ptr Int := .ofAddr (ptrAddr dim.toInt')
    Quantum4Lean.FFI.quantum4LeanTelemetry token nPtr dPtr cdPtr |>.ignore

    return {
      bits      := allBits
      probs     := some probs
      dimension := dim.toInt'
      cycles    := cycles
    }

  finally
    Quantum4Lean.FFI.quantum4LeanFreeState sv
    Quantum4Lean.FFI.quantum4LeanFinalize token |>.ignore

end Quantum4Lean
