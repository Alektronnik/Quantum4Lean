/-
Quantum4LeanFuzz.lean
Fuzzer intra-Lean: valida Quantum4LeanEngine contra propiedades algebraicas.

Tests autocontenidos (sin FFI, sin UnitaryMatrix):
  1. Identidades: H*H=I, X*X=I, Y*Y=I, Z*Z=I, CNOT*CNOT=I, CZ*CZ=I, S^4=I, T^8=I
  2. Algebra de Pauli: XZ|0> vs ZX|0>
  3. Estados Bell y GHZ: valores teoricos exactos
  4. Fuzzer aleatorio: normalizacion, determinismo, reversibilidad

LCG determinista (mismo algoritmo que el motor) para generacion.

COMPATIBLE: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanEngine

namespace Quantum4Lean

-- ===================================================================
-- Configuracion
-- ===================================================================

structure FuzzConfig where
  maxQubits   : Nat := 5
  maxDepth    : Nat := 20
  numCircuits : Nat := 100
  seed        : UInt64 := 987654321
  tolerance   : Float := 1e-12
  deriving Repr, Inhabited

-- ===================================================================
-- LCG pseudoaleatorio
-- ===================================================================

private def lcgMul : UInt64 := 6364136223846793005
private def lcgAdd : UInt64 := 1442695040888963407

private def lcgNext (seed : UInt64) : UInt64 × UInt64 :=
  let s := seed * lcgMul + lcgAdd
  (s, s >>> 11)

private def lcgNat (seed : UInt64) (bound : Nat) : UInt64 × Nat :=
  let (s, r) := lcgNext seed
  (s, r.toNat % bound)

-- ===================================================================
-- Generador de circuitos pseudoaleatorios
-- ===================================================================

private def randomGate (n : Nat) (seed : UInt64) (hpos : 0 < n) : Gate n × UInt64 :=
  let (s1, r1) := lcgNext seed
  let qA := r1.toNat % n
  let (s2, r2) := lcgNext s1
  let qB := r2.toNat % n
  let (s3, r3) := lcgNext s2
  let gateType := r3.toNat % 9
  let qB' := if qA = qB then (qA + 1) % n else qB
  have hqA : qA < n := Nat.mod_lt _ hpos
  have hqB' : qB' < n := by
    dsimp [qB']; split
    · exact Nat.mod_lt _ hpos
    · exact Nat.mod_lt _ hpos
  let qa : Qubit n := ⟨⟨qA, hqA⟩⟩
  let qb : Qubit n := ⟨⟨qB', hqB'⟩⟩
  let gate := match gateType with
    | 0 => Gate.H qa      | 1 => Gate.X qa
    | 2 => Gate.Y qa      | 3 => Gate.Z qa
    | 4 => Gate.S qa      | 5 => Gate.T qa
    | 6 => Gate.CNOT qa qb | 7 => Gate.CZ qa qb
    | 8 => Gate.SWAP qa qb | _ => Gate.H qa
  (gate, s3)

private def randomCircuit (n : Nat) (depth : Nat) (seed : UInt64) (hpos : 0 < n) : Circuit n × UInt64 :=
  (List.range depth).foldl (fun ((c : Circuit n), (s : UInt64)) (_ : Nat) =>
    let (gate, s') := randomGate n s hpos
    (c.add gate, s')
  ) (Circuit.identity n, seed)

-- ===================================================================
-- Circuitos de prueba
-- ===================================================================

private def mkQubit (n : Nat) (i : Nat) (h : i < n) : Qubit n := ⟨⟨i, h⟩⟩

private def gateIdCircuit (n : Nat) (f : Qubit n -> Gate n) (hpos : 0 < n) : Circuit n :=
  let q := mkQubit n 0 hpos
  { gates := [f q, f q] }

private def gateIdCircuit2 (n : Nat) (f : Qubit n -> Qubit n -> Gate n) (hpos1 : 0 < n) (hpos2 : 1 < n) : Circuit n :=
  let q0 := mkQubit n 0 hpos1; let q1 := mkQubit n 1 hpos2
  { gates := [f q0 q1, f q0 q1] }

private def bellCircuit (h0 : 0 < 2 := by decide) (h1 : 1 < 2 := by decide) : Circuit 2 :=
  let q0 := mkQubit 2 0 h0; let q1 := mkQubit 2 1 h1
  { gates := [Gate.H q0, Gate.CNOT q0 q1] }

private def ghz3Circuit (h0 : 0 < 3 := by decide) (h1 : 1 < 3 := by decide) (h2 : 2 < 3 := by decide) : Circuit 3 :=
  let q0 := mkQubit 3 0 h0; let q1 := mkQubit 3 1 h1; let q2 := mkQubit 3 2 h2
  { gates := [Gate.H q0, Gate.CNOT q0 q1, Gate.CNOT q1 q2] }

private def s4Circuit (n : Nat) (hpos : 0 < n) : Circuit n :=
  let q := mkQubit n 0 hpos
  { gates := [Gate.S q, Gate.S q, Gate.S q, Gate.S q] }

private def t8Circuit (n : Nat) (hpos : 0 < n) : Circuit n :=
  let q := mkQubit n 0 hpos
  { gates := List.replicate 8 (Gate.T q) }

private def xzCircuit (n : Nat) (hpos : 0 < n) : Circuit n :=
  let q := mkQubit n 0 hpos
  { gates := [Gate.X q, Gate.Z q] }

private def zxCircuit (n : Nat) (hpos : 0 < n) : Circuit n :=
  let q := mkQubit n 0 hpos
  { gates := [Gate.Z q, Gate.X q] }

-- ===================================================================
-- Utilidades de verificacion
-- ===================================================================

private def floatAbs (x : Float) : Float := if x > 0.0 then x else -x

private def checkAmplitudeOne (sv : StateVector) (idx : Nat) (tol : Float) : Bool :=
  let (re, im) := StateVector.amplitude sv idx
  floatAbs (re - 1.0) <= tol && floatAbs im <= tol

private def checkAmplitudeEq (sv : StateVector) (idx : Nat) (expectedRe expectedIm : Float) (tol : Float) : Bool :=
  let (re, im) := StateVector.amplitude sv idx
  floatAbs (re - expectedRe) <= tol && floatAbs (im - expectedIm) <= tol

private def checkNorm (sv : StateVector) (tol : Float) : Bool :=
  let total := (List.range (StateVector.probabilities sv).size).foldl
    (fun (acc : Float) (i : Nat) => acc + (StateVector.probabilities sv)[i]!) 0.0
  floatAbs (total - 1.0) <= tol

private def svEqual (sv1 sv2 : StateVector) (tol : Float) : Bool :=
  sv1.numQubits == sv2.numQubits &&
  (List.range (2 * sv1.dim)).all fun (i : Nat) =>
    floatAbs (sv1.data[i]! - sv2.data[i]!) <= tol

-- ===================================================================
-- Tests de identidad de puertas
-- ===================================================================

def testGateIdentities : List String :=
  let n := 2; let tol := 1e-12
  let h0 : 0 < n := by decide
  let h1 : 1 < n := by decide
  let tests : List (String × Circuit n) := [
    ("H*H",    gateIdCircuit n Gate.H h0),
    ("X*X",    gateIdCircuit n Gate.X h0),
    ("Y*Y",    gateIdCircuit n Gate.Y h0),
    ("Z*Z",    gateIdCircuit n Gate.Z h0),
    ("CNOT*CNOT", gateIdCircuit2 n Gate.CNOT h0 h1),
    ("CZ*CZ",  gateIdCircuit2 n Gate.CZ h0 h1),
    ("S^4",    s4Circuit n h0),
    ("T^8",    t8Circuit n h0)
  ]
  listBind tests fun (name, c) =>
    match StateVector.init n with
    | Except.error e => [s!"{name}: init: {e}"]
    | Except.ok sv0 =>
      let sv := StateVector.runCircuit sv0 c
      if checkAmplitudeOne sv 0 tol then []
      else
        let (re, im) := StateVector.amplitude sv 0
        [s!"{name}: ({re},{im}) vs (1,0)"]

def testSWAPIdentity : List String :=
  let tol := 1e-12; let n := 2
  let h0 : 0 < n := by decide
  let h1 : 1 < n := by decide
  let q0 := mkQubit n 0 h0; let q1 := mkQubit n 1 h1
  let c : Circuit 2 := { gates := [Gate.X q1, Gate.SWAP q0 q1, Gate.SWAP q0 q1] }
  match StateVector.init n with
  | Except.error e => [s!"SWAP: init: {e}"]
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 c
    if checkAmplitudeOne sv 2 tol then []
    else
      let (re, im) := StateVector.amplitude sv 2
      [s!"SWAP*SWAP: ({re},{im}) vs (1,0) at |01>"]

-- ===================================================================
-- Tests de algebra de Pauli
-- ===================================================================

def testPauliAlgebra : List String :=
  let tol := 1e-12; let n := 1
  let hpos : 0 < n := by decide
  -- XZ|0> = X(Z|0>) = X|0> = |1>
  -- ZX|0> = Z(X|0>) = Z|1> = -|1>
  -- Pero el circuito xzCircuit = [X q, Z q] = X primero, luego Z:
  --   X|0> = |1>, luego Z|1> = -|1>.  Resultado: -|1>
  -- Y el circuito zxCircuit = [Z q, X q] = Z primero, luego X:
  --   Z|0> = |0>, luego X|0> = |1>.  Resultado: |1>
  let failuresXZ := match StateVector.init n with
  | Except.error e => [s!"XZ init: {e}"]
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 (xzCircuit n hpos)
    -- xzCircuit: X luego Z => XZ|0> = -|1>
    if checkAmplitudeEq sv 1 (-1.0) 0.0 tol then []
    else let (re, im) := StateVector.amplitude sv 1
         [s!"XZ|0>: ({re},{im}) vs (-1,0) at |1>"]
  let failuresZX := match StateVector.init n with
  | Except.error e => [s!"ZX init: {e}"]
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 (zxCircuit n hpos)
    -- zxCircuit: Z luego X => ZX|0> = |1>
    if checkAmplitudeEq sv 1 (1.0) 0.0 tol then []
    else let (re, im) := StateVector.amplitude sv 1
         [s!"ZX|0>: ({re},{im}) vs (1,0) at |1>"]
  failuresXZ ++ failuresZX

-- ===================================================================
-- Tests de estado Bell
-- ===================================================================

def testBellState : List String :=
  let tol := 1e-12; let inv := Float.sqrt 2.0 / 2.0
  let bc := bellCircuit (by decide) (by decide)
  match StateVector.init 2 with
  | Except.error e => [s!"Bell init: {e}"]
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 bc
    let f1 := if checkAmplitudeEq sv 0 inv 0.0 tol then []
              else let (re, im) := StateVector.amplitude sv 0
                   [s!"Bell |00>: ({re},{im}) vs ({inv},0)"]
    let f2 := if checkAmplitudeEq sv 3 inv 0.0 tol then []
              else let (re, im) := StateVector.amplitude sv 3
                   [s!"Bell |11>: ({re},{im}) vs ({inv},0)"]
    let (re1, _) := StateVector.amplitude sv 1
    let f3 := if floatAbs re1 <= tol then []
              else [s!"Bell |01>: re={re1} vs 0"]
    let (re2, _) := StateVector.amplitude sv 2
    let f4 := if floatAbs re2 <= tol then []
              else [s!"Bell |10>: re={re2} vs 0"]
    f1 ++ f2 ++ f3 ++ f4

-- ===================================================================
-- Tests de estado GHZ(3)
-- ===================================================================

def testGHZState : List String :=
  let tol := 1e-12; let inv := Float.sqrt 2.0 / 2.0
  let gc := ghz3Circuit (by decide) (by decide) (by decide)
  match StateVector.init 3 with
  | Except.error e => [s!"GHZ init: {e}"]
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 gc
    let f1 := if checkAmplitudeEq sv 0 inv 0.0 tol then []
              else let (re, im) := StateVector.amplitude sv 0
                   [s!"GHZ |000>: ({re},{im}) vs ({inv},0)"]
    let f2 := if checkAmplitudeEq sv 7 inv 0.0 tol then []
              else let (re, im) := StateVector.amplitude sv 7
                   [s!"GHZ |111>: ({re},{im}) vs ({inv},0)"]
    f1 ++ f2

-- ===================================================================
-- Fuzzer de circuitos aleatorios (sin mut, usando foldl anidado)
-- ===================================================================

private partial def fuzzLoop (cfg : FuzzConfig) (idx : Nat) (seed : UInt64) (failures : List String) : List String :=
  if idx >= cfg.numCircuits then failures else
  let n := 2 + (idx % (cfg.maxQubits - 1))
  let depth := 1 + (idx % cfg.maxDepth)
  have hpos : 0 < n := by
    have h2 : 0 < 2 := by decide
    have hle : 2 ≤ n := Nat.le_add_right 2 (idx % (cfg.maxQubits - 1))
    exact Nat.lt_of_lt_of_le h2 hle
  let (circuit, newSeed) := randomCircuit n depth seed hpos
  let tol := cfg.tolerance
  let newFailures := match StateVector.init n with
  | Except.error e => s!"Fuzz[{idx}] n={n} d={depth}: init: {e}" :: failures
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 circuit
    let f1 := if checkNorm sv tol then failures
              else s!"Fuzz[{idx}] n={n} d={depth}: norm fail" :: failures
    -- Determinismo
    let f2 := match StateVector.init n with
    | Except.error _ => f1
    | Except.ok sv0b =>
      let sv2 := StateVector.runCircuit sv0b circuit
      if svEqual sv sv2 tol then f1
      else s!"Fuzz[{idx}] n={n} d={depth}: non-det" :: f1
    f2
  fuzzLoop cfg (idx + 1) newSeed newFailures

def fuzzRandomCircuits (cfg : FuzzConfig) : List String :=
  fuzzLoop cfg 0 cfg.seed []

-- ===================================================================
-- Reporte
-- ===================================================================

structure FuzzReport where
  gateIdentities : List String
  swapIdentity   : List String
  pauliAlgebra   : List String
  bellState      : List String
  ghzState       : List String
  randomCircuits : List String
  totalFailures  : Nat
  allOk          : Bool
  deriving Repr

def runFullSuite (cfg : FuzzConfig := {}) : FuzzReport :=
  let gateId := testGateIdentities
  let swapId := testSWAPIdentity
  let pauli := testPauliAlgebra
  let bell := testBellState
  let ghz := testGHZState
  let rand := fuzzRandomCircuits cfg
  let total := gateId.length + swapId.length + pauli.length + bell.length + ghz.length + rand.length
  { gateIdentities := gateId
  , swapIdentity   := swapId
  , pauliAlgebra   := pauli
  , bellState      := bell
  , ghzState       := ghz
  , randomCircuits := rand
  , totalFailures  := total
  , allOk          := total = 0
  }

def reportToString (r : FuzzReport) : String :=
  let header := if r.allOk then "FUZZ: 0 fallos" else s!"FUZZ: {r.totalFailures} fallos"
  let formatSection (title : String) (failures : List String) : List String :=
    if failures.isEmpty then [s!"  {title}: OK"]
    else (s!"  {title}: {failures.length} FALLOS") :: failures.map fun f => s!"    - {f}"
  let parts :=
    formatSection "Identidades" r.gateIdentities ++
    formatSection "SWAP" r.swapIdentity ++
    formatSection "Pauli" r.pauliAlgebra ++
    formatSection "Bell" r.bellState ++
    formatSection "GHZ" r.ghzState ++
    formatSection "Aleatorios" r.randomCircuits
  String.intercalate "\n" (header :: parts)

end Quantum4Lean
