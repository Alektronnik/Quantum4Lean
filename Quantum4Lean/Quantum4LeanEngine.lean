/-
Quantum4LeanEngine.lean
Motor de simulacion cuantica PURO LEAN 4 — bit-exacto con CoreQU4TRIX (C++).

ALGORITMOS REPLICADOS (validados contra CoreQU4TRIX.mm):
  - State vector: 2 * 2^N Float (real/imag interleaved), |0...0> inicial
  - Aplicacion unitaria 1-qubit: U * [α, β]^T via bit-index pairing
  - CNOT: XOR del target cuando control = 1
  - CZ:   negacion de fase cuando control = target = 1
  - SWAP: intercambio de amplitudes cuando bits difieren
  - Medicion + colapso: P(|1>), LCG determinista, colapso + renormalizacion
  - LCG: seed = seed*6364136223846793005 + 1442695040888963407
  - Umbral de colapso: 1e-15 (identico a qu4trix_sqrt)

LIMITACION: ≤ 10 qubits (2048 complejos ≈ 32 KB). Para N > 10 usar FFI.

BIT-EXACTNESS: Mismas matrices (IEEE 754), mismo LCG, mismo orden de operaciones.

COMPATIBLE: Lean 4.7.0 (sin let mut, usa foldl para iteracion funcional).
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean

-- ===================================================================
-- Estado cuantico
-- ===================================================================

structure StateVector where
  data      : Array Float
  numQubits : Nat
  seed      : UInt64
  cycles    : Nat
  deriving Repr

namespace StateVector

-- ===================================================================
-- Constantes (identicas a CoreQU4TRIX.mm)
-- ===================================================================

private def COLLAPSE_THRESHOLD : Float := 1e-15
private def LCG_MUL : UInt64 := 6364136223846793005
private def LCG_ADD : UInt64 := 1442695040888963407
private def LCG_DIV : Float := 9007199254740992.0
private def DEFAULT_SEED : UInt64 := 123456789
private def INV_SQRT2 : Float := Float.sqrt 2.0 / 2.0

-- ===================================================================
-- LCG (identico a CoreQU4TRIX)
-- ===================================================================

private def lcgNext (seed : UInt64) : UInt64 × Float :=
  let newSeed := seed * LCG_MUL + LCG_ADD
  let random := (newSeed >>> 11).toFloat / LCG_DIV
  (newSeed, random)

-- ===================================================================
-- Inicializacion
-- ===================================================================

def init (n : Nat) (seed : UInt64 := DEFAULT_SEED) : Except String StateVector :=
  if n < 1 || n > 10 then
    Except.error s!"StateVector.init: n={n} fuera de [1,10] (pure-Lean max)"
  else
    let dim := 1 <<< n
    let elementos := 2 * dim
    let data := (List.range elementos).foldl (fun d _ => d.push 0.0) (Array.mkEmpty elementos)
    let data := data.set! 0 1.0
    Except.ok { data := data, numQubits := n, seed := seed, cycles := 0 }

def dim (sv : StateVector) : Nat := 1 <<< sv.numQubits

-- ===================================================================
-- Matrices de puertas (identicas a CoreQU4TRIX)
-- Formato: [U00r, U00i, U01r, U01i, U10r, U10i, U11r, U11i]
-- ===================================================================

private def GATE_I : Array Float := #[1,0, 0,0, 0,0, 1,0]
private def GATE_X : Array Float := #[0,0, 1,0, 1,0, 0,0]
private def GATE_Y : Array Float := #[0,0, 0,-1, 0,1, 0,0]
private def GATE_Z : Array Float := #[1,0, 0,0, 0,0, -1,0]
private def GATE_S : Array Float := #[1,0, 0,0, 0,0, 0,1]

private def GATE_H : Array Float :=
  let v := INV_SQRT2
  #[v,0, v,0, v,0, -v,0]

private def GATE_T : Array Float :=
  let v := INV_SQRT2
  #[1,0, 0,0, 0,0, v,v]

private def gateRX (theta : Float) : Array Float :=
  let cos_t2 := Float.cos (theta / 2.0)
  let sin_t2 := Float.sin (theta / 2.0)
  #[cos_t2, 0, 0, -sin_t2, 0, -sin_t2, cos_t2, 0]

private def gateRY (theta : Float) : Array Float :=
  let cos_t2 := Float.cos (theta / 2.0)
  let sin_t2 := Float.sin (theta / 2.0)
  #[cos_t2, 0, -sin_t2, 0, sin_t2, 0, cos_t2, 0]

private def gateRZ (theta : Float) : Array Float :=
  let cos_t2 := Float.cos (theta / 2.0)
  let sin_t2 := Float.sin (theta / 2.0)
  #[cos_t2, -sin_t2, 0, 0, 0, 0, cos_t2, sin_t2]

-- ===================================================================
-- Aplicacion unitaria 1-qubit (identico a aplicar_unitaria_cpu)
-- ===================================================================

private def applyUnitaryInPlace (sv : StateVector) (k : Nat) (gate : Array Float) : StateVector :=
  let numPares := sv.dim >>> 1
  let U00r := gate[0]!;  let U00i := gate[1]!
  let U01r := gate[2]!;  let U01i := gate[3]!
  let U10r := gate[4]!;  let U10i := gate[5]!
  let U11r := gate[6]!;  let U11i := gate[7]!
  let newData := (List.range numPares).foldl (fun (d : Array Float) (p : Nat) =>
    let low  := p &&& ((1 <<< k) - 1)
    let high := (p >>> k) <<< (k + 1)
    let idx0 := high ||| low
    let idx1 := idx0 ||| (1 <<< k)
    let ar := d[2 * idx0]!;  let ai := d[2 * idx0 + 1]!
    let br := d[2 * idx1]!;  let bi := d[2 * idx1 + 1]!
    let nAr := (U00r * ar - U00i * ai) + (U01r * br - U01i * bi)
    let nAi := (U00r * ai + U00i * ar) + (U01r * bi + U01i * br)
    let nBr := (U10r * ar - U10i * ai) + (U11r * br - U11i * bi)
    let nBi := (U10r * ai + U10i * ar) + (U11r * bi + U11i * br)
    let d := d.set! (2 * idx0)     nAr
    let d := d.set! (2 * idx0 + 1) nAi
    let d := d.set! (2 * idx1)     nBr
    d.set! (2 * idx1 + 1) nBi
  ) sv.data
  { sv with data := newData, cycles := sv.cycles + 1 }

-- ===================================================================
-- CNOT (identico a aplicar_cnot_cpu)
-- ===================================================================

private def applyCNOTInPlace (sv : StateVector) (control target : Nat) : StateVector :=
  let newData := (List.range sv.dim).foldl (fun (d : Array Float) (i : Nat) =>
    if ((i >>> control) &&& 1) = 1 then
      let iSwap := i ^^^ (1 <<< target)
      if i < iSwap then
        let curRe := d[2 * i]!;  let curIm := d[2 * i + 1]!
        let swapRe := d[2 * iSwap]!; let swapIm := d[2 * iSwap + 1]!
        let d := d.set! (2 * i)     swapRe
        let d := d.set! (2 * i + 1) swapIm
        let d := d.set! (2 * iSwap)     curRe
        d.set! (2 * iSwap + 1) curIm
      else
        d
    else
      d
  ) sv.data
  { sv with data := newData, cycles := sv.cycles + 1 }

-- ===================================================================
-- CZ (identico a aplicar_cz_cpu)
-- ===================================================================

private def applyCZInPlace (sv : StateVector) (control target : Nat) : StateVector :=
  let newData := (List.range sv.dim).foldl (fun (d : Array Float) (i : Nat) =>
    if ((i >>> control) &&& 1) = 1 && ((i >>> target) &&& 1) = 1 then
      let d := d.set! (2 * i)     (-d[2 * i]!)
      d.set! (2 * i + 1) (-d[2 * i + 1]!)
    else
      d
  ) sv.data
  { sv with data := newData, cycles := sv.cycles + 1 }

-- ===================================================================
-- SWAP (identico a aplicar_swap_cpu)
-- ===================================================================

private def applySWAPInPlace (sv : StateVector) (a b : Nat) : StateVector :=
  let newData := (List.range sv.dim).foldl (fun (d : Array Float) (i : Nat) =>
    let bitA := (i >>> a) &&& 1
    let bitB := (i >>> b) &&& 1
    if bitA ≠ bitB then
      let iSwap := i ^^^ (1 <<< a) ^^^ (1 <<< b)
      if i < iSwap then
        let ar := d[2 * i]!;  let ai := d[2 * i + 1]!
        let br := d[2 * iSwap]!; let bi := d[2 * iSwap + 1]!
        let d := d.set! (2 * i)     br
        let d := d.set! (2 * i + 1) bi
        let d := d.set! (2 * iSwap)     ar
        d.set! (2 * iSwap + 1) ai
      else
        d
    else
      d
  ) sv.data
  { sv with data := newData, cycles := sv.cycles + 1 }

-- ===================================================================
-- Medicion + colapso (identico a medir_y_colapsar_cpu)
-- ===================================================================

def measure (sv : StateVector) (k : Nat) : Int × StateVector :=
  let probUno := (List.range sv.dim).foldl (fun (prob : Float) (i : Nat) =>
    if ((i >>> k) &&& 1) = 1 then
      let re := sv.data[2 * i]!; let im := sv.data[2 * i + 1]!
      prob + re * re + im * im
    else
      prob
  ) 0.0
  let (newSeed, aleatorio) := lcgNext sv.seed
  let bitMedido := if aleatorio < probUno then 1 else 0
  let probColapso := if bitMedido = 1 then probUno else (1.0 - probUno)
  let normaInv := if probColapso > COLLAPSE_THRESHOLD then 1.0 / Float.sqrt probColapso else 0.0
  let newData := (List.range sv.dim).foldl (fun (d : Array Float) (i : Nat) =>
    if ((i >>> k) &&& 1) ≠ bitMedido then
      let d := d.set! (2 * i)     0.0
      d.set! (2 * i + 1) 0.0
    else
      let d := d.set! (2 * i)     (d[2 * i]! * normaInv)
      d.set! (2 * i + 1) (d[2 * i + 1]! * normaInv)
  ) sv.data
  let newSv := { sv with data := newData, seed := newSeed, cycles := sv.cycles + 1 }
  (bitMedido, newSv)

-- ===================================================================
-- Probabilidades
-- ===================================================================

def probabilities (sv : StateVector) : Array Float :=
  (List.range sv.dim).foldl (fun (probs : Array Float) (i : Nat) =>
    let re := sv.data[2 * i]!; let im := sv.data[2 * i + 1]!
    probs.push (re * re + im * im)
  ) (Array.mkEmpty sv.dim)

-- ===================================================================
-- Medir todos los qubits
-- ===================================================================

def measureAll (sv : StateVector) : Nat × StateVector :=
  let n := sv.numQubits
  (List.range n).foldl (fun ((val : Nat), (cur : StateVector)) (k : Nat) =>
    let (bit, next) := measure cur k
    let bitNat : Nat := if bit = 0 then 0 else 1
    (val ||| (bitNat <<< k), next)
  ) (0, sv)

-- ===================================================================
-- Router de puertas
-- ===================================================================

def applyGate (sv : StateVector) (gate : Gate n) : StateVector :=
  let getIdx (q : Qubit n) : Nat := q.idx.val
  match gate with
  | .H q    => applyUnitaryInPlace sv (getIdx q) GATE_H
  | .X q    => applyUnitaryInPlace sv (getIdx q) GATE_X
  | .Y q    => applyUnitaryInPlace sv (getIdx q) GATE_Y
  | .Z q    => applyUnitaryInPlace sv (getIdx q) GATE_Z
  | .S q    => applyUnitaryInPlace sv (getIdx q) GATE_S
  | .T q    => applyUnitaryInPlace sv (getIdx q) GATE_T
  | .RX q theta => applyUnitaryInPlace sv (getIdx q) (gateRX theta)
  | .RY q theta => applyUnitaryInPlace sv (getIdx q) (gateRY theta)
  | .RZ q theta => applyUnitaryInPlace sv (getIdx q) (gateRZ theta)
  | .Unitary q matrix => applyUnitaryInPlace sv (getIdx q) matrix
  | .CNOT c t => applyCNOTInPlace sv (getIdx c) (getIdx t)
  | .CZ c t   => applyCZInPlace sv (getIdx c) (getIdx t)
  | .SWAP a b => applySWAPInPlace sv (getIdx a) (getIdx b)

-- ===================================================================
-- Ejecutar circuito
-- ===================================================================

def runCircuit (sv : StateVector) (circuit : Circuit n) : StateVector :=
  circuit.gates.foldl (fun (cur : StateVector) (g : Gate n) => applyGate cur g) sv

def run (circuit : Circuit n) (seed : UInt64 := DEFAULT_SEED) (shots : Nat := 1) :
    Except String (List Nat) := do
  let sv <- StateVector.init n seed
  let finalSv := runCircuit sv circuit
  let (results, _) := (List.range shots).foldl (fun ((res : List Nat), (cur : StateVector)) (_ : Nat) =>
    let (bits, next) := measureAll cur
    (bits :: res, next)
  ) ([], finalSv)
  Except.ok results.reverse

def amplitude (sv : StateVector) (i : Nat) : Float × Float :=
  if i >= sv.dim then (0.0, 0.0)
  else (sv.data[2 * i]!, sv.data[2 * i + 1]!)

def prob (sv : StateVector) (i : Nat) : Float :=
  let (re, im) := amplitude sv i
  re * re + im * im

end StateVector

-- ===================================================================
-- API publica
-- ===================================================================

def executeSim {n : Nat} (c : Circuit n) (seed : UInt64 := 123456789) : Except String (List Nat) :=
  StateVector.run c seed 1

def executeSimProbs {n : Nat} (c : Circuit n) (seed : UInt64 := 123456789) : Except String (Array Float) := do
  let sv <- StateVector.init n seed
  let finalSv := StateVector.runCircuit sv c
  Except.ok (StateVector.probabilities finalSv)

end Quantum4Lean
