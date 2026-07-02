/-
Quantum4LeanError.lean
Sistema de errores tipados para Quantum4Lean.

Mapea 1:1 los codigos de error del motor C++ (QuantumKitCore)
a un tipo inductivo de Lean. Esto permite que el Except de la monada
transporte errores con semantica precisa en lugar de strings.

El usuario puede hacer pattern matching sobre el error para decidir
si reintentar con menos qubits, liberar memoria, etc.
-/

namespace Quantum4Lean

/--
Errores del motor cuantico. Mapean directamente a los codigos
definidos en Quantum4LeanBridge.h y QuantumKitCore.h.
-/
inductive QuantumError : Type where
  | noInit
  | qubitRange (qubit max : Int)
  | qubitsMax (requested max : Int)
  | nullPointer
  | tokenMismatch
  | memoria (bytes : USize)
  | gpuFailure
  | internal (msg : String)
  deriving Repr, Inhabited

namespace QuantumError

/--
Convierte un codigo de error del motor C a QuantumError.
-/
def fromCode (code : Int) : QuantumError :=
  match code with
  | 201 => .noInit
  | 202 => .qubitRange 0 0
  | 203 => .qubitsMax 0 0
  | 205 => .nullPointer
  | 207 => .tokenMismatch
  | 208 => .memoria 0
  | 300 => .gpuFailure
  | _   => .internal s!"codigo desconocido: {code}"

/--
Representacion legible del error.
-/
def toString : QuantumError -> String
  | .noInit         => "motor no inicializado"
  | .qubitRange q m => s!"qubit {q} fuera de rango [0, {m-1}]"
  | .qubitsMax r m  => s!"{r} qubits solicitados, maximo {m}"
  | .nullPointer    => "puntero nulo"
  | .tokenMismatch  => "token de instancia no coincide"
  | .memoria b      => s!"memoria insuficiente ({b} bytes)"
  | .gpuFailure     => "fallo de GPU"
  | .internal msg   => s!"error interno: {msg}"

instance : ToString QuantumError where
  toString := toString

end QuantumError

/--
Limite maximo de qubits en funcion de la RAM disponible.
En Apple Silicon con 16 GB unified: ~28 qubits.
Con 32 GB: ~29 qubits. Con 64 GB: ~30 qubits.
-/
def maxQubitsForRAM (ramGB : USize) : Nat :=
  if ramGB >= 64 then 30
  else if ramGB >= 32 then 29
  else if ramGB >= 16 then 28
  else if ramGB >= 8  then 26
  else 24

/--
Estima los bytes necesarios para N qubits (state vector double precision).
-/
def estimateBytes (numQubits : Nat) : USize :=
  let dim := 1 <<< numQubits
  -- 2 * dim doubles, 8 bytes cada uno, mas buffers temporales (~4x)
  dim.toUSize * 16 * 4

end Quantum4Lean
