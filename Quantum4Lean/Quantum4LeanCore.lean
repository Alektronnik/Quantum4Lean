/-
Quantum4LeanCore.lean
Tipos cuanticos fundamentales: Qubit, Gate, Circuit, StateVector.

Diseno inspirado en la filosofia Apple:
- Tipos dependientes para seguridad en tiempo de compilacion
- Qubit indexado por numero total de qubits (Fin n)
- Circuito indexado por numero de qubits (Circuit n)
- Separacion clara entre construccion y ejecucion
-/

import Quantum4Lean.Quantum4LeanError

namespace Quantum4Lean

/--
`List.bind` sin depender de `Monad List` ni `List.join`
(no disponibles en Init de Lean 4.31.0).
Equivalente a: `xs >>= f` en Haskell.
-/
def listBind {α β : Type} (xs : List α) (f : α → List β) : List β :=
  match xs with
  | [] => []
  | x :: rest => f x ++ listBind rest f

-- --- Qubit indexado --------------------------------------------

/--
Un qubit dentro de un registro de `n` qubits.
`idx : Fin n` garantiza que el indice es valido (0 <= idx < n).
-/
structure Qubit (n : Nat) where
  idx : Fin n
  deriving BEq, DecidableEq, Repr

instance : ToString (Qubit n) where
  toString q := s!"q[{q.idx.val}]"

def Qubit.ofNat (i : Nat) (h : i < n := by omega) : Qubit n :=
  ⟨⟨i, h⟩⟩

-- --- Catalogo de puertas ---------------------------------------

/--
Puerta cuantica sobre `n` qubits.
Cada constructor incluye sus qubits objetivo indexados.
-/
inductive Gate (n : Nat) : Type where
  -- Clifford
  | H    (q : Qubit n)
  | X    (q : Qubit n)
  | Y    (q : Qubit n)
  | Z    (q : Qubit n)
  | S    (q : Qubit n)
  | T    (q : Qubit n)
  -- Dos qubits
  | CNOT (control target : Qubit n)
  | CZ   (control target : Qubit n)
  | SWAP (a b : Qubit n)
  -- Rotaciones parametricas
  | RX (q : Qubit n) (theta : Float)
  | RY (q : Qubit n) (theta : Float)
  | RZ (q : Qubit n) (theta : Float)
  -- Unitaria arbitraria 2x2 (8 floats: [U00r, U00i, U01r, U01i, U10r, U10i, U11r, U11i])
  | Unitary (q : Qubit n) (matrix : Array Float)
  deriving Repr

/--
Convierte una puerta a su codigo de tipo para el motor C.
-/
def Gate.toCode : Gate n -> Int
  | .H ..    => 0
  | .X ..    => 1
  | .Y ..    => 2
  | .Z ..    => 3
  | .S ..    => 4
  | .T ..    => 5
  | .CNOT .. => 6
  | .CZ ..   => 7
  | .SWAP .. => 8
  | .RX ..   => 9
  | .RY ..   => 10
  | .RZ ..   => 11
  | .Unitary .. => 12

def Gate.qubits : Gate n -> List (Qubit n)
  | .H q => [q] | .X q => [q] | .Y q => [q] | .Z q => [q]
  | .S q => [q] | .T q => [q]
  | .CNOT c t => [c, t] | .CZ c t => [c, t] | .SWAP a b => [a, b]
  | .RX q _ => [q] | .RY q _ => [q] | .RZ q _ => [q]
  | .Unitary q _ => [q]

-- --- Circuito --------------------------------------------------

/--
Circuito cuantico sobre `n` qubits.
`gates` es la secuencia ordenada de puertas a aplicar.
-/
structure Circuit (n : Nat) where
  gates : List (Gate n)
  deriving Repr

instance : Inhabited (Circuit n) := ⟨{ gates := [] }⟩

/--
Circuito vacio (identidad sobre n qubits).
-/
def Circuit.identity (n : Nat) : Circuit n := { gates := [] }

/--
Anade una puerta al final del circuito.
-/
def Circuit.add (c : Circuit n) (g : Gate n) : Circuit n :=
  { c with gates := c.gates ++ [g] }

/--
Compone dos circuitos secuencialmente: c1 luego c2.
-/
def Circuit.comp (c1 c2 : Circuit n) : Circuit n :=
  { gates := c1.gates ++ c2.gates }

/--
Repite un circuito `k` veces.
-/
def Circuit.repeat (c : Circuit n) (k : Nat) : Circuit n :=
  match k with
  | 0 => Circuit.identity n
  | k + 1 => c.comp (c.repeat k)

/--
Profundidad del circuito (numero de puertas).
-/
def Circuit.depth (c : Circuit n) : Nat := c.gates.length

-- --- Notacion constructora -------------------------------------

/--
Construye un circuito: `circuit { c => ... }`.
-/
def circuit {n : Nat} (build : Circuit n -> Circuit n) : Circuit n :=
  build (Circuit.identity n)

end Quantum4Lean
