/-
Quantum4LeanDSL.lean
Notacion declarativa para circuitos cuanticos. Estilo Apple.

Uso:
  def bell : Circuit 2 := circuit! {
    Gate.H q[0];
    Gate.CNOT q[0] q[1]
  }

`q[i]` es azucar sintactico para `Qubit.ofNat i`. El tipo `Qubit n`
se infiere del contexto (Circuit 2 -> Qubit 2).

`circuit! { ... }` construye un Circuit n a partir de una secuencia
de puertas separadas por `;`. Equivale a llamadas anidadas de
`Circuit.add` sobre `Circuit.identity n`.

Sintaxis alternativa para puertas comunes:
  H q[i]    -> Gate.H (Qubit.ofNat i)
  X q[i]    -> Gate.X (Qubit.ofNat i)
  CNOT q[i] q[j] -> Gate.CNOT ...

Para usar los alias cortos, importar Quantum4Lean.DSL.Shortcuts.

Compatible: Lean 4.7.0.
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean.DSL

open Quantum4Lean

-- ===================================================================
-- q[i] -- azucar para creacion de qubits
-- ===================================================================

/--
`q[i]` crea un `Qubit n` con indice `i`.
El `n` se infiere del contexto (tipo esperado).
-/
syntax "q[" term "]" : term

macro_rules
  | `(q[$i]) => `(Qubit.ofNat $i)

-- ===================================================================
-- circuit! -- constructor de circuitos con DSL
-- ===================================================================

/--
`circuit! { puerta1; puerta2; ... }` construye un `Circuit n`.

Cada linea es una expresion de tipo `Gate n`. Las puertas se
componen secuencialmente via `Circuit.add`.

Ejemplo:
  def bell : Circuit 2 := circuit! {
    Gate.H q[0];
    Gate.CNOT q[0] q[1]
  }
-/
syntax "circuit!" "{" sepBy(term, ";") "}" : term

macro_rules
  | `(circuit! { $g:term }) => `(circuit fun c => c.add $g)
  | `(circuit! { $g:term; $[$gs:term];* }) =>
    `(circuit! { $[$gs];* } |>.add $g)

end Quantum4Lean.DSL

/-
Alias cortos para puertas.

Usar con `open Quantum4Lean.DSL.Shortcuts`:
  def bell : Circuit 2 := circuit! { H q[0]; CNOT q[0] q[1] }
-/
namespace Quantum4Lean.DSL.Shortcuts

def H  (q : Qubit n) : Gate n := Gate.H q
def X  (q : Qubit n) : Gate n := Gate.X q
def Y  (q : Qubit n) : Gate n := Gate.Y q
def Z  (q : Qubit n) : Gate n := Gate.Z q
def S  (q : Qubit n) : Gate n := Gate.S q
def T  (q : Qubit n) : Gate n := Gate.T q
def CNOT (c t : Qubit n) : Gate n := Gate.CNOT c t
def CZ   (c t : Qubit n) : Gate n := Gate.CZ c t
def SWAP (a b : Qubit n) : Gate n := Gate.SWAP a b
def RX (q : Qubit n) (theta : Float) : Gate n := Gate.RX q theta
def RY (q : Qubit n) (theta : Float) : Gate n := Gate.RY q theta
def RZ (q : Qubit n) (theta : Float) : Gate n := Gate.RZ q theta

end Quantum4Lean.DSL.Shortcuts
