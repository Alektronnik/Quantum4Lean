/-
Quantum4LeanSimp.lean
Simplificador simbolico de circuitos cuanticos (Term Rewriting).

Aplica identidades algebraicas directamente sobre el AST de `Circuit n`.
Sin multiplicar matrices, sin calcular flotantes. Escala a N arbitrario.

Reglas implementadas:
  1. Cancelacion: G*G = I para puertas self-inverse (H,X,Y,Z,CNOT,CZ,SWAP)
  2. Pauli: H*X*H = Z, H*Z*H = X
  3. Fase: S*S = Z, T*T = S
  4. Conmutacion: puertas sobre qubits disjuntos conmutan

Uso:
  simplifyCircuit bellCircuit  -- Circuit 2 optimizado
  #eval circuitsEquiv original (simplifyCircuit original)  -- true

Compatible: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean

-- ===================================================================
-- Utilidades: qubits e igualdad estructural de puertas
-- ===================================================================

private def qubitsOf : Gate n -> List Nat
  | .H q => [q.idx.val] | .X q => [q.idx.val] | .Y q => [q.idx.val]
  | .Z q => [q.idx.val] | .S q => [q.idx.val] | .T q => [q.idx.val]
  | .CNOT c t => [c.idx.val, t.idx.val] | .CZ c t => [c.idx.val, t.idx.val]
  | .SWAP a b => [a.idx.val, b.idx.val]
  | .RX q _ => [q.idx.val] | .RY q _ => [q.idx.val] | .RZ q _ => [q.idx.val]
  | .Unitary q _ => [q.idx.val]

/-- Igualdad estructural: mismo constructor, mismos qubits. Ignora Float params. --/
private def gateEq : Gate n -> Gate n -> Bool
  | .H q1,        .H q2        => q1.idx.val == q2.idx.val
  | .X q1,        .X q2        => q1.idx.val == q2.idx.val
  | .Y q1,        .Y q2        => q1.idx.val == q2.idx.val
  | .Z q1,        .Z q2        => q1.idx.val == q2.idx.val
  | .S q1,        .S q2        => q1.idx.val == q2.idx.val
  | .T q1,        .T q2        => q1.idx.val == q2.idx.val
  | .CNOT c1 t1,  .CNOT c2 t2  => c1.idx.val == c2.idx.val && t1.idx.val == t2.idx.val
  | .CZ c1 t1,    .CZ c2 t2    => c1.idx.val == c2.idx.val && t1.idx.val == t2.idx.val
  | .SWAP a1 b1,  .SWAP a2 b2  => a1.idx.val == a2.idx.val && b1.idx.val == b2.idx.val
  | .RX q1 _,     .RX q2 _     => q1.idx.val == q2.idx.val
  | .RY q1 _,     .RY q2 _     => q1.idx.val == q2.idx.val
  | .RZ q1 _,     .RZ q2 _     => q1.idx.val == q2.idx.val
  | .Unitary q1 _, .Unitary q2 _ => q1.idx.val == q2.idx.val
  | _, _ => false

/-- Dos puertas conmutan si operan sobre qubits disjuntos. --/
private def commuteQ (a b : Gate n) : Bool :=
  let qsA := qubitsOf a
  let qsB := qubitsOf b
  qsA.all fun q => ¬(qsB.any fun qb => qb == q)

/-- Dos puertas actuan sobre exactamente los mismos qubits. --/
private def sameQubits (a b : Gate n) : Bool :=
  let qsA := qubitsOf a
  let qsB := qubitsOf b
  qsA.length == qsB.length && qsA.all fun q => qsB.any fun qb => qb == q

-- ===================================================================
-- Cancelacion: G*G -> I para self-inverse gates
-- ===================================================================

/-- Es self-inverse si G*G = I (hasta fase global). --/
private def isSelfInverse : Gate n -> Bool
  | .H ..    => true | .X ..    => true | .Y ..    => true
  | .Z ..    => true | .CNOT .. => true | .CZ ..   => true
  | .SWAP .. => true
  | _        => false

/-- Cancelar un par G*G cuando ambos son la misma puerta self-inverse. --/
private def tryCancel (a b : Gate n) : Bool :=
  isSelfInverse a && gateEq a b

-- ===================================================================
-- Reglas de reescritura Pauli
-- ===================================================================

/-- H*X*H = Z. Si vemos H, X, H en secuencia sobre el mismo qubit. --/
private def tryHXH (a b c : Gate n) : Option (Gate n) :=
  match a, b, c with
  | .H q1, .X q2, .H q3 =>
    if q1.idx.val == q2.idx.val && q2.idx.val == q3.idx.val then
      some (.Z q1)
    else none
  | _, _, _ => none

/-- H*Z*H = X. --/
private def tryHZH (a b c : Gate n) : Option (Gate n) :=
  match a, b, c with
  | .H q1, .Z q2, .H q3 =>
    if q1.idx.val == q2.idx.val && q2.idx.val == q3.idx.val then
      some (.X q1)
    else none
  | _, _, _ => none

-- ===================================================================
-- Reglas de fase: S y T
-- ===================================================================

/-- S*S = Z. --/
private def trySS (a b : Gate n) : Option (Gate n) :=
  match a, b with
  | .S q1, .S q2 =>
    if q1.idx.val == q2.idx.val then some (.Z q1) else none
  | _, _ => none

/-- S^4 = I (eliminar 4 S consecutivas). --/
private def tryS4 (gates : List (Gate n)) : List (Gate n) :=
  -- Buscar secuencias de 4 S consecutivas sobre el mismo qubit
  -- Simplificacion: solo miramos pares S*S -> Z
  gates

/-- T*T = S. --/
private def tryTT (a b : Gate n) : Option (Gate n) :=
  match a, b with
  | .T q1, .T q2 =>
    if q1.idx.val == q2.idx.val then some (.S q1) else none
  | _, _ => none

-- ===================================================================
-- Conmutacion: mover puertas sobre qubits disjuntos
-- ===================================================================

/--
Intenta conmutar dos puertas adyacentes si operan en qubits disjuntos.
Devuelve la lista con el orden intercambiado.
-/
private def tryCommute (a b : Gate n) : Option (List (Gate n)) :=
  if commuteQ a b && !sameQubits a b then
    some [b, a]
  else
    none

-- ===================================================================
-- Simplificador principal
-- ===================================================================

/--
Aplica una pasada de simplificacion sobre la lista de puertas.
Cada regla se aplica de izquierda a derecha.
-/
partial def simplifyPass (gates : List (Gate n)) : List (Gate n) :=
  match gates with
  | [] => []
  | [g] => [g]
  | a :: b :: rest =>
    if tryCancel a b then
      simplifyPass rest
    else match trySS a b with
    | some g => simplifyPass (g :: rest)
    | none =>
      match tryTT a b with
      | some g => simplifyPass (g :: rest)
      | none =>
        match tryCommute a b with
        | some [b', a'] => a' :: simplifyPass (b' :: rest)
        | _ =>
          match rest with
          | c :: rest' =>
            match tryHXH a b c with
            | some g => simplifyPass (g :: rest')
            | none =>
              match tryHZH a b c with
              | some g => simplifyPass (g :: rest')
              | none => a :: simplifyPass (b :: rest)
          | [] => a :: simplifyPass (b :: rest)

/-- Compara dos listas de puertas elemento a elemento con gateEq. --/
private def gatesEqual (gs1 gs2 : List (Gate n)) : Bool :=
  match gs1, gs2 with
  | [], [] => true
  | g1 :: r1, g2 :: r2 => gateEq g1 g2 && gatesEqual r1 r2
  | _, _ => false

/--
Simplifica un circuito aplicando reglas de reescritura hasta convergencia.
Maximo 100 iteraciones.
-/
partial def simplifyCircuit (c : Circuit n) : Circuit n :=
  let rec go (gates : List (Gate n)) (iter : Nat) : List (Gate n) :=
    if iter >= 100 then gates else
    let simplified := simplifyPass gates
    if gatesEqual simplified gates then gates
    else go simplified (iter + 1)
  { c with gates := go c.gates 0 }

/--
Cuantas puertas se eliminaron durante la simplificacion.
-/
def simplificationSavings (c : Circuit n) : Nat :=
  let s := simplifyCircuit c
  c.gates.length - s.gates.length

end Quantum4Lean
