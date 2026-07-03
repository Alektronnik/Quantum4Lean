/-
Quantum4LeanUnitary.lean
Verificacion semantica via matrices unitarias. Lean 4.7.0 compatible.

Define:
  - Complex: numero complejo (re, im) con aritmetica completa
  - UnitaryMatrix n: matriz unitaria 2^n x 2^n
  - compile: Circuit n -> UnitaryMatrix n (expansion tensorial)
  - traceDistance, equiv, circuitsEquiv
  - Teoremas: H*H=I, X*X=I, CNOT*CNOT=I, CNOT decomposition = SWAP

Triangulo de verificacion:
  Engine.execute  -> probs empiricas (StateVector)
  Unitary.compile -> probs teoricas (|U|0>|^2)
  Fuzz.test       -> identidades algebraicas (Engine vs Fuzz)
  circuitsEquiv   -> equivalencia semantica (Unitary vs Unitary)

Los 4 caminos convergen al mismo resultado.
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean

-- ===================================================================
-- Numeros complejos
-- ===================================================================

structure Complex where
  re : Float
  im : Float
  deriving Inhabited

namespace Complex

def zero : Complex := { re := 0.0, im := 0.0 }
def one  : Complex := { re := 1.0, im := 0.0 }

def add (a b : Complex) : Complex := { re := a.re + b.re, im := a.im + b.im }
def sub (a b : Complex) : Complex := { re := a.re - b.re, im := a.im - b.im }
def mul (a b : Complex) : Complex :=
  { re := a.re * b.re - a.im * b.im, im := a.re * b.im + a.im * b.re }
def scale (s : Float) (a : Complex) : Complex := { re := s * a.re, im := s * a.im }
def conj (a : Complex) : Complex := { re := a.re, im := -a.im }
def norm2 (a : Complex) : Float := a.re * a.re + a.im * a.im

nonrec def toString (a : Complex) : String :=
  let reStr := ToString.toString a.re
  let imStr :=
    if a.im >= 0.0 then "+" ++ ToString.toString a.im ++ "i"
    else "-" ++ ToString.toString (-a.im) ++ "i"
  "(" ++ reStr ++ imStr ++ ")"

instance : ToString Complex where toString := toString
instance : Add Complex where add := add
instance : Sub Complex where sub := sub
instance : Mul Complex where mul := mul

end Complex

-- ===================================================================
-- Matriz unitaria 2^n x 2^n
-- ===================================================================

structure UnitaryMatrix (n : Nat) where
  rows : List (List Complex)
  dim  : Nat
  deriving Inhabited

namespace UnitaryMatrix

def identity (n : Nat) : UnitaryMatrix n :=
  let d := 1 <<< n
  let row (i : Nat) : List Complex :=
    (List.range d).map fun j =>
      if i == j then Complex.one else Complex.zero
  { rows := (List.range d).map row, dim := d }

def get {n : Nat} (u : UnitaryMatrix n) (i j : Nat) : Complex :=
  match u.rows[i]? with
  | some row => row[j]? |>.getD Complex.zero
  | none => Complex.zero

def mul {n : Nat} (a b : UnitaryMatrix n) : UnitaryMatrix n :=
  let d := a.dim
  let row (i : Nat) : List Complex :=
    (List.range d).map fun j =>
      (List.range d).foldl (fun acc k =>
        acc + get a i k * get b k j
      ) Complex.zero
  { rows := (List.range d).map row, dim := d }

def trace {n : Nat} (u : UnitaryMatrix n) : Complex :=
  (List.range u.dim).foldl (fun acc i => acc + get u i i) Complex.zero

def adjoint {n : Nat} (u : UnitaryMatrix n) : UnitaryMatrix n :=
  let d := u.dim
  let row (i : Nat) : List Complex :=
    (List.range d).map fun j => Complex.conj (get u j i)
  { rows := (List.range d).map row, dim := d }

def traceDistance {n : Nat} (a b : UnitaryMatrix n) : Float :=
  let d := a.dim.toFloat
  let prod := mul (adjoint a) b
  let tr := trace prod
  let absTr := Float.sqrt (Complex.norm2 tr)
  1.0 - absTr / d

def equiv (a b : UnitaryMatrix n) (epsilon : Float := 1e-6) : Bool :=
  traceDistance a b < epsilon

def firstColumn {n : Nat} (u : UnitaryMatrix n) : List Complex :=
  (List.range u.dim).map fun i => get u i 0

def theoreticalProbs {n : Nat} (u : UnitaryMatrix n) : List Float :=
  firstColumn u |>.map fun c => Complex.norm2 c

end UnitaryMatrix

-- ===================================================================
-- Puertas elementales como matrices 2x2
-- ===================================================================

private def co : Complex := Complex.one
private def cz : Complex := Complex.zero
private def mkC (r i : Float) : Complex := { re := r, im := i }

private def gateH : List Complex :=
  let s := Float.sqrt 2.0 / 2.0
  [mkC s 0, mkC s 0, mkC s 0, mkC (-s) 0]

private def gateX : List Complex := [cz, co, co, cz]
private def gateY : List Complex := [cz, mkC 0 (-1), mkC 0 1, cz]
private def gateZ : List Complex := [co, cz, cz, mkC (-1) 0]
private def gateS : List Complex := [co, cz, cz, mkC 0 1]

private def gateT : List Complex :=
  let theta := 3.141592653589793 / 4.0
  [co, cz, cz, mkC (Float.cos theta) (Float.sin theta)]

private def gateRX (theta : Float) : List Complex :=
  let cT := Float.cos (theta / 2.0); let sT := Float.sin (theta / 2.0)
  [mkC cT 0, mkC 0 (-sT), mkC 0 (-sT), mkC cT 0]

private def gateRY (theta : Float) : List Complex :=
  let cT := Float.cos (theta / 2.0); let sT := Float.sin (theta / 2.0)
  [mkC cT 0, mkC (-sT) 0, mkC sT 0, mkC cT 0]

private def gateRZ (theta : Float) : List Complex :=
  let cT := Float.cos (theta / 2.0); let sT := Float.sin (theta / 2.0)
  [mkC cT (-sT), cz, cz, mkC cT sT]

-- ===================================================================
-- Expansion tensorial
-- ===================================================================

private def expand1Q {n : Nat} (g : List Complex) (q : Nat) : UnitaryMatrix n :=
  let d := 1 <<< n
  let dMinusOne := d - 1
  let mask := 1 <<< q
  let notMask := dMinusOne ^^^ mask
  let g00 := g[0]? |>.getD co
  let g01 := g[1]? |>.getD cz
  let g10 := g[2]? |>.getD cz
  let g11 := g[3]? |>.getD co
  let row (i : Nat) : List Complex :=
    (List.range d).map fun j =>
      if (i ^^^ j) &&& notMask == 0 then
        let iBit := (i >>> q) &&& 1
        let jBit := (j >>> q) &&& 1
        match iBit, jBit with
        | 0, 0 => g00 | 0, 1 => g01
        | 1, 0 => g10 | 1, 1 => g11
        | _, _ => cz
      else cz
  { rows := (List.range d).map row, dim := d }

private def expandCNOT {n : Nat} (c t : Nat) : UnitaryMatrix n :=
  let d := 1 <<< n
  let tMask := 1 <<< t
  let row (i : Nat) : List Complex :=
    (List.range d).map fun j =>
      let expected := if ((i >>> c) &&& 1) == 1 then i ^^^ tMask else i
      if j == expected then co else cz
  { rows := (List.range d).map row, dim := d }

private def expandCZ {n : Nat} (c t : Nat) : UnitaryMatrix n :=
  let d := 1 <<< n
  let row (i : Nat) : List Complex :=
    (List.range d).map fun j =>
      if i == j then
        if ((i >>> c) &&& 1) == 1 && ((i >>> t) &&& 1) == 1 then
          mkC (-1) 0
        else co
      else cz
  { rows := (List.range d).map row, dim := d }

private def expandSWAP {n : Nat} (a b : Nat) : UnitaryMatrix n :=
  let d := 1 <<< n
  let dMinusOne := d - 1
  let aMask := 1 <<< a
  let bMask := 1 <<< b
  let clearMask := dMinusOne ^^^ aMask ^^^ bMask
  let row (i : Nat) : List Complex :=
    (List.range d).map fun j =>
      let bitA := (i >>> a) &&& 1
      let bitB := (i >>> b) &&& 1
      let swapped := (i &&& clearMask) ||| (bitB <<< a) ||| (bitA <<< b)
      if j == swapped then co else cz
  { rows := (List.range d).map row, dim := d }

private def gateMatrix {n : Nat} (g : Gate n) : UnitaryMatrix n :=
  match g with
  | .H q    => expand1Q gateH q.idx.val
  | .X q    => expand1Q gateX q.idx.val
  | .Y q    => expand1Q gateY q.idx.val
  | .Z q    => expand1Q gateZ q.idx.val
  | .S q    => expand1Q gateS q.idx.val
  | .T q    => expand1Q gateT q.idx.val
  | .CNOT ctrl tgt => expandCNOT ctrl.idx.val tgt.idx.val
  | .CZ   ctrl tgt => expandCZ   ctrl.idx.val tgt.idx.val
  | .SWAP a b      => expandSWAP a.idx.val b.idx.val
  | .RX q theta => expand1Q (gateRX theta) q.idx.val
  | .RY q theta => expand1Q (gateRY theta) q.idx.val
  | .RZ q theta => expand1Q (gateRZ theta) q.idx.val
  | .Unitary q matrix =>
    let m : List Complex := [mkC (matrix[0]!) (matrix[1]!), mkC (matrix[2]!) (matrix[3]!),
                             mkC (matrix[4]!) (matrix[5]!), mkC (matrix[6]!) (matrix[7]!)]
    expand1Q m q.idx.val

-- ===================================================================
-- Compilacion y verificacion semantica
-- ===================================================================

def compile {n : Nat} (c : Circuit n) : UnitaryMatrix n :=
  c.gates.foldl (fun (u : UnitaryMatrix n) (g : Gate n) =>
    UnitaryMatrix.mul (gateMatrix g) u
  ) (UnitaryMatrix.identity n)

def circuitsEquiv {n : Nat} (c1 c2 : Circuit n) (epsilon : Float := 1e-6) : Bool :=
  UnitaryMatrix.equiv (compile c1) (compile c2) epsilon

-- ===================================================================
-- Teoremas para n=2 (matrices 4x4, 16 complejos)
-- ===================================================================

section Tests

private def q (i : Nat) : Qubit 2 :=
  if h : i < 2 then
    ⟨⟨i, h⟩⟩
  else
    -- unreachable in tests where i in {0, 1}
    ⟨⟨0, by decide⟩⟩

/-- Test: H*H = I --/
def testHadamardIdentity : Bool :=
  circuitsEquiv
    (circuit fun c => (c.add (Gate.H (q 0))).add (Gate.H (q 0)))
    (Circuit.identity 2)

/-- Test: X*X = I --/
def testPauliXIdentity : Bool :=
  circuitsEquiv
    (circuit fun c => (c.add (Gate.X (q 0))).add (Gate.X (q 0)))
    (Circuit.identity 2)

/-- Test: Y*Y = I --/
def testPauliYIdentity : Bool :=
  circuitsEquiv
    (circuit fun c => (c.add (Gate.Y (q 0))).add (Gate.Y (q 0)))
    (Circuit.identity 2)

/-- Test: Z*Z = I --/
def testPauliZIdentity : Bool :=
  circuitsEquiv
    (circuit fun c => (c.add (Gate.Z (q 0))).add (Gate.Z (q 0)))
    (Circuit.identity 2)

/-- Test: CNOT*CNOT = I --/
def testCNOTIdentity : Bool :=
  circuitsEquiv
    (circuit fun c => (c.add (Gate.CNOT (q 0) (q 1))).add (Gate.CNOT (q 0) (q 1)))
    (Circuit.identity 2)

/-- Test: CZ*CZ = I --/
def testCZIdentity : Bool :=
  circuitsEquiv
    (circuit fun c => (c.add (Gate.CZ (q 0) (q 1))).add (Gate.CZ (q 0) (q 1)))
    (Circuit.identity 2)

/-- Test: SWAP*SWAP = I --/
def testSWAPIdentityMatrix : Bool :=
  circuitsEquiv
    (circuit fun c => (c.add (Gate.SWAP (q 0) (q 1))).add (Gate.SWAP (q 0) (q 1)))
    (Circuit.identity 2)

/-- Test: CNOT(0,1)*CNOT(1,0)*CNOT(0,1) = SWAP(0,1) --/
def testCNOTSwapDecomposition : Bool :=
  circuitsEquiv
    (circuit fun c =>
      ((c.add (Gate.CNOT (q 0) (q 1))).add (Gate.CNOT (q 1) (q 0))).add (Gate.CNOT (q 0) (q 1)))
    (circuit fun c => c.add (Gate.SWAP (q 0) (q 1)))

/-- Ejecuta todos los tests. Lista vacia = todo OK. --/
def runAllTests : List String :=
  let tests : List (String × Bool) := [
    ("H*H=I",      testHadamardIdentity),
    ("X*X=I",      testPauliXIdentity),
    ("Y*Y=I",      testPauliYIdentity),
    ("Z*Z=I",      testPauliZIdentity),
    ("CNOT*CNOT=I", testCNOTIdentity),
    ("CZ*CZ=I",    testCZIdentity),
    ("SWAP*SWAP=I", testSWAPIdentityMatrix),
    ("CNOT decomp = SWAP", testCNOTSwapDecomposition)
  ]
  tests.filterMap fun (name, result) =>
    if result then none else some s!"{name}: FAIL"

end Tests

end Quantum4Lean
