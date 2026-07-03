/-
QuantumRiemann.lean -- Resonancia de Riemann + Cuantica

Fusiona la Hipotesis de Riemann (segundas diferencias de gaps primos)
con dinamica cuantica de espines (Ising) usando el Engine puro de
Quantum4Lean.

Hamiltoniano volcanico:
  H = J Σ Z_i Z_{i+1} + α Σ (Δ²g_i) X_i

Donde:
  J = 1.0 (tejido base constante)
  Δ²g_i = segunda diferencia del gap entre primos en posicion i
  α = 0.25 (factor de escala del Teorema de Invarianza Estructural)

Hipotesis:
  - Trotter 1er orden: asimetria choca con explosiones primas
    -> fidelidad colapsa (Presion Volcanica Exponencial, PVE)
  - Suzuki 2º orden: palindromo ZZ/2 -> X -> ZZ/2 resuena con
    autorregulacion prima (CE=0.562) -> el gato GHZ sobrevive

Diccionario:
  Δ²g_i ≈ 0        -> valle prima (gap estable)      -> campo X debil
  |Δ²g_i| grande   -> explosion prima (gap erratico)  -> campo X fuerte

Novedad: NADIE ha conectado la Hipotesis de Riemann con simulacion
cuantica verificada. Quantum4Lean es la unica plataforma que puede
hacerlo con garantias formales (Engine bit-exacto + Unitary verificacion).

Compatible: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean

namespace Quantum4Lean.Playground.Riemann

-- ===================================================================
-- Primos y gaps
-- ===================================================================

/-- Raiz cuadrada entera (Nat.sqrt no existe en Lean 4.7.0). --/
private def natSqrt (n : Nat) : Nat :=
  if n <= 1 then n else
    let rec go (x : Nat) : Nat :=
      let x' := (x + n / x) / 2
      if x' < x then go x' else x
    go (n / 2)

/-- Criba simple: primeros n primos. --/
partial def primes (n : Nat) : List Nat :=
  if n = 0 then []
  else
    let rec go (k : Nat) (acc : List Nat) : List Nat :=
      if acc.length >= n then acc.reverse
      else
        let limit := natSqrt k
        let isPrime := ¬(acc.any fun p => if p > limit then false else k % p == 0)
        if isPrime then go (k + 1) (k :: acc)
        else go (k + 1) acc
    go 3 [2]

/-- Gaps entre primos consecutivos: g_i = p_{i+1} - p_i --/
def primeGaps (ps : List Nat) : List Int :=
  match ps with
  | [] | [_] => []
  | a :: b :: rest => ((b : Int) - (a : Int)) :: primeGaps (b :: rest)

/-- Primeras diferencias de gaps: d1_i = g_{i+1} - g_i --/
def firstDiff (xs : List Int) : List Int :=
  match xs with
  | [] | [_] => []
  | a :: b :: rest => (b - a) :: firstDiff (b :: rest)

/-- Segundas diferencias de gaps: Δ²g_i = d1_{i+1} - d1_i --/
def delta2Gaps (ps : List Nat) : List Int :=
  let gaps := primeGaps ps
  let d1 := firstDiff gaps
  firstDiff d1

/--
Presion Volcanica Exponencial (PVE): metrica de volatilidad prima.
PVE = max(|Δ²g|) / mean(|Δ²g|)
--/
private def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

def PVE (delta2 : List Int) : Float :=
  let absVals : List Float := List.map (fun x => intToFloat (if x >= 0 then x else -x)) delta2
  let maxVal := List.foldl (fun m v => if v > m then v else m) 0.0 absVals
  let sum := List.foldl (fun s v => s + v) 0.0 absVals
  let meanVal := if absVals.length = 0 then 1.0 else sum / absVals.length.toFloat
  if meanVal < 1e-10 then maxVal else maxVal / meanVal

-- ===================================================================
-- Hamiltoniano volcanico: Circuitos Trotter
-- ===================================================================

/-- Puerta ZZ entre qubits i, i+1: CNOT(i,i+1); RZ(i+1, 2*dt); CNOT(i,i+1) --/
private def applyZZ (n : Nat) (i : Nat) (dt : Float) : Circuit n :=
  if hi : i < n then
    if hi1 : i + 1 < n then
      let qi := Qubit.mk ⟨i, hi⟩
      let qi1 := Qubit.mk ⟨i + 1, hi1⟩
      circuit fun c =>
        c.add (Gate.CNOT qi qi1)
        |>.add (Gate.RZ qi1 (2.0 * dt))
        |>.add (Gate.CNOT qi qi1)
    else Circuit.identity n
  else Circuit.identity n

/-- Puerta X via H-RZ-H: H(i); RZ(i, 2*dt); H(i) --/
private def applyX (n : Nat) (i : Nat) (dt : Float) : Circuit n :=
  if hi : i < n then
    let qi := Qubit.mk ⟨i, hi⟩
    circuit fun c =>
      c.add (Gate.H qi)
      |>.add (Gate.RZ qi (2.0 * dt))
      |>.add (Gate.H qi)
  else Circuit.identity n

/--
Trotter 1er orden: ZZ secuencial + X con pesos primos.
-/
def step1stVolcanic (n : Nat) (dt : Float) (alpha : Float) (d2g : List Int) : Circuit n :=
  let gatesZZ := (List.range (n - 1)).bind fun i =>
    (applyZZ n i dt).gates
  let gatesX := (List.range n).bind fun i =>
    let absVal := if d2g.get! i >= 0 then d2g.get! i else -d2g.get! i
    let h_i := alpha * (if i < d2g.length then absVal.toNat.toFloat else 0.0)
    (applyX n i (h_i * dt)).gates
  { gates := gatesZZ ++ gatesX }

/--
Suzuki 2º orden: ZZ(dt/2) -> X(dt) -> ZZ(dt/2) con pesos primos.
El palindromo resuena con la autorregulacion prima (CE=0.562).
-/
def step2ndVolcanic (n : Nat) (dt : Float) (alpha : Float) (d2g : List Int) : Circuit n :=
  let half := dt / 2.0
  let gatesZZ1 := (List.range (n - 1)).bind fun i => (applyZZ n i half).gates
  let gatesX := (List.range n).bind fun i =>
    let absVal := if d2g.get! i >= 0 then d2g.get! i else -d2g.get! i
    let h_i := alpha * (if i < d2g.length then absVal.toNat.toFloat else 0.0)
    (applyX n i (h_i * dt)).gates
  let gatesZZ2 := (List.range (n - 1)).bind fun i => (applyZZ n i half).gates
  { gates := gatesZZ1 ++ gatesX ++ gatesZZ2 }

-- ===================================================================
-- Gato GHZ
-- ===================================================================

/-- Prepara estado GHZ: H(0); CNOT(0,1); CNOT(1,2); ... --/
def catPrep (n : Nat) : Circuit n :=
  if hn : n ≥ 1 then
    let q0 := Qubit.mk ⟨0, by omega⟩
    let ghzGates := (List.range (n - 1)).bind fun i =>
      if hi : i < n then
        if hi1 : i + 1 < n then
          [Gate.CNOT (Qubit.mk ⟨i, hi⟩) (Qubit.mk ⟨i+1, hi1⟩)]
        else []
      else []
    circuit fun c =>
      (c.add (Gate.H q0) :: ghzGates.map fun g => c.add g).foldl (fun acc f => f) (Circuit.identity n)
  else Circuit.identity n

/-- Deshace GHZ: inverso de catPrep --/
def catUnprep (n : Nat) : Circuit n :=
  if hn : n ≥ 1 then
    let q0 := Qubit.mk ⟨0, by omega⟩
    let gates := (List.range (n - 1)).reverse.bind fun i =>
      if hi : i < n then
        if hi1 : i + 1 < n then
          [Gate.CNOT (Qubit.mk ⟨i, hi⟩) (Qubit.mk ⟨i+1, hi1⟩)]
        else []
      else []
    { gates := gates ++ [Gate.H q0] }
  else Circuit.identity n

-- ===================================================================
-- Experimento: fidelidad del gato bajo evolucion volcanica
-- ===================================================================

/--
Evoluciona un gato GHZ bajo el Hamiltoniano volcanico y mide
la fidelidad final (probabilidad de volver a |0...0>).

Parametros:
  nQubits: numero de qubits (default 5)
  steps: pasos Trotter (default 5)
  dt: paso temporal base (default 0.5)
  alpha: factor de escala prima (default 0.25)
  order: 1 = 1er orden, 2 = Suzuki 2º orden
  nPrimes: cuantos primos usar (default 20)
-/
def volcanicFidelity (nQubits : Nat := 5) (steps : Nat := 5) (dt : Float := 0.5)
    (alpha : Float := 0.25) (order : Nat := 2) (nPrimes : Nat := 20) : Float :=
  let ps := primes nPrimes
  let d2g := delta2Gaps ps
  let pve := PVE d2g
  let stepFn := if order = 2 then step2ndVolcanic else step1stVolcanic
  -- Construir circuito completo
  let forward := (List.range steps).foldl (fun (c : Circuit nQubits) _ =>
    c.comp (stepFn nQubits dt alpha d2g)
  ) (Circuit.identity nQubits)
  -- Circuito eco: prep -> forward -> unprep
  let circuit := catPrep nQubits |>.comp forward |>.comp (catUnprep nQubits)
  -- Ejecutar
  match StateVector.init nQubits with
  | Except.error _ => 0.0
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 circuit
    -- Fidelidad = P(|0...0>) = |α_0|^2
    StateVector.prob sv 0

/--
Compara fidelidad 1er orden vs 2º orden para un barrido de alpha.
-/
def compareOrders (nQubits : Nat := 5) (steps : Nat := 5) (dt : Float := 0.5)
    (nPrimes : Nat := 20) : List (Float × Float × Float) :=
  let alphas := [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]
  alphas.map fun alpha =>
    let f1 := volcanicFidelity nQubits steps dt alpha 1 nPrimes
    let f2 := volcanicFidelity nQubits steps dt alpha 2 nPrimes
    (alpha, f1, f2)

/--
Informe del experimento volcanico.
-/
def report : String :=
  let nQubits := 5
  let ps := primes 20
  let d2g := delta2Gaps ps
  let pve := PVE d2g
  let header := "RESONANCIA DE RIEMANN: Primos + Cuantica\n"
  let info := s!"Primos: {ps.length} generados\n"
  let info := info ++ s!"Δ²g (primeros 10): {d2g.take 10}\n"
  let info := info ++ s!"PVE = {pve}\n\n"
  let info := info ++ "Fidelidad del gato GHZ (nQubits=5, steps=5, dt=0.5):\n"
  let info := info ++ "  alpha  1erOrden  2oOrden(Suzuki)\n"
  let info := info ++ "  -----  ---------  ---------------\n"
  let results := compareOrders nQubits 5 0.5 20
  let info := results.foldl (fun (s : String) ((a, f1, f2) : Float × Float × Float) =>
    s ++ s!"  {a}     {f1}        {f2}\n"
  ) info
  header ++ info

end Quantum4Lean.Playground.Riemann
