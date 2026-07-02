/-
Quantum4LeanVQE.lean
Variational Quantum Eigensolver (VQE) puro sobre StateVector.

Sin FFI, sin monada, sin IO. Todo es funcion pura.

Parameter-shift rule:
  d<H>/dtheta_i = (<H>(theta_i + pi/2) - <H>(theta_i - pi/2)) / 2

Exacta para puertas de la forma e^{-i theta P/2} (RX, RY, RZ).

Flujo:
  1. ansatz: List Float -> Circuit n   (construye el circuito parametrico)
  2. init: StateVector.init n          (|0...0>)
  3. runCircuit: Circuit n -> StateVector
  4. expect: StateVector -> Observable -> Float
  5. gradient: parameter-shift para cada parametro
  6. update: theta <- theta - lr * grad
  7. Repetir hasta convergencia

Compatible: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean.Quantum4LeanObservable

namespace Quantum4Lean

-- ===================================================================
-- Evaluacion de circuito parametrico
-- ===================================================================

/--
Ejecuta un circuito parametrico y devuelve <H>.
-/
def evalCircuit {n : Nat} (ansatz : List Float -> Circuit n) (obs : Observable)
    (params : List Float) : Float :=
  let circuit := ansatz params
  match StateVector.init n with
  | Except.error _ => 0.0
  | Except.ok sv0 =>
    let sv := StateVector.runCircuit sv0 circuit
    expect sv obs

/-- Modifica el elemento en indice `idx` de una lista aplicando `f`. --/
private def listModify {α : Type} (xs : List α) (idx : Nat) (f : α -> α) : List α :=
  match xs with
  | [] => []
  | x :: rest =>
    if idx == 0 then f x :: rest
    else x :: listModify rest (idx - 1) f

/--
Ejecuta ansatz con un parametro desplazado y mide <H>.
-/
def shiftedExpect {n : Nat} (ansatz : List Float -> Circuit n) (obs : Observable)
    (params : List Float) (idx : Nat) (shift : Float) : Float :=
  let shiftedParams := listModify params idx (fun x => x + shift)
  evalCircuit ansatz obs shiftedParams

-- ===================================================================
-- Parameter-shift gradient
-- ===================================================================

/--
Gradiente de <H> respecto al parametro `idx` via parameter-shift.

  d<H>/dtheta = (<H>(theta + pi/2) - <H>(theta - pi/2)) / 2

Exacta para puertas RX, RY, RZ.
-/
def parameterShiftGradient {n : Nat} (ansatz : List Float -> Circuit n)
    (obs : Observable) (params : List Float) (idx : Nat) : Float :=
  let shift := 3.141592653589793 / 2.0
  let expectPlus  := shiftedExpect ansatz obs params idx shift
  let expectMinus := shiftedExpect ansatz obs params idx (-shift)
  (expectPlus - expectMinus) / 2.0

/--
Gradiente completo: vector de derivadas parciales.

Realiza 2*k evaluaciones del circuito.
-/
def gradient {n : Nat} (ansatz : List Float -> Circuit n) (obs : Observable)
    (params : List Float) : List Float :=
  let k := params.length
  (List.range k).map fun i =>
    parameterShiftGradient ansatz obs params i

-- ===================================================================
-- Optimizacion
-- ===================================================================

/-- Paso de gradient descent: theta_new = theta - lr * grad. --/
def gradientDescentStep (params grad : List Float) (learningRate : Float := 0.01) : List Float :=
  params.zip grad |>.map fun (p, g) => p - learningRate * g

/--
Bucle VQE recursivo (sin mut, compatible 4.7.0).

Optimiza parametros para minimizar <H>.
Devuelve (energia final, parametros optimos, historial).
-/
partial def vqeLoop {n : Nat} (ansatz : List Float -> Circuit n) (obs : Observable)
    (params : List Float) (learningRate : Float) (maxIter : Nat) (tolerance : Float)
    (iter : Nat) (prevEnergy : Float) (history : List Float)
    : Float × List Float × List Float :=
  if iter >= maxIter then
    (prevEnergy, params, history.reverse)
  else
    let energy := evalCircuit ansatz obs params
    let newHistory := energy :: history
    -- Convergencia
    if iter > 0 && (energy - prevEnergy).abs < tolerance then
      (energy, params, newHistory.reverse)
    else
      let grad := gradient ansatz obs params
      let newParams := gradientDescentStep params grad learningRate
      vqeLoop ansatz obs newParams learningRate maxIter tolerance (iter + 1) energy newHistory

/--
VQE: optimizacion variacional de un circuito parametrico.

- ansatz: funcion de parametros a circuito
- obs: observable a minimizar (Hamiltoniano)
- initialParams: parametros iniciales
- learningRate: tasa de aprendizaje (default 0.01)
- maxIter: iteraciones maximas (default 100)
- tolerance: criterio de convergencia (default 1e-6)

Devuelve (energia final, parametros optimos, historial de energias).
-/
def vqe {n : Nat} (ansatz : List Float -> Circuit n) (obs : Observable)
    (initialParams : List Float) (learningRate : Float := 0.01)
    (maxIter : Nat := 100) (tolerance : Float := 1e-6)
    : Float × List Float × List Float :=
  vqeLoop ansatz obs initialParams learningRate maxIter tolerance 0 0.0 []

-- ===================================================================
-- Ansatz de Ising 1D
-- ===================================================================

/--
Ansatz de prueba para Ising 1D: capa RY + entrelazamiento CNOT.

Usa foldl anidados para evitar `mut` (compatible Lean 4.7.0).
-/
def isingAnsatz (numQubits : Nat) (depth : Nat := 1) : List Float -> Circuit numQubits :=
  fun params =>
    let buildLayer (c : Circuit numQubits) (pIdx : Nat) (_d : Nat) : Circuit numQubits × Nat :=
      -- Capa RY
      let (c1, p1) := (List.range numQubits).foldl
        (fun ((circ : Circuit numQubits), (pidx : Nat)) (q : Nat) =>
          if pidx < params.length then
            if h : q < numQubits then
              let qubit : Qubit numQubits := ⟨⟨q, h⟩⟩
              (circ.add (Gate.RY qubit (params.get! pidx)), pidx + 1)
            else (circ, pidx + 1)
          else (circ, pidx)
        ) (c, pIdx)
      -- Capa CNOT
      let c2 := (List.range (numQubits - 1)).foldl
        (fun (circ : Circuit numQubits) (q : Nat) =>
          if hq : q < numQubits then
            if hq1 : q + 1 < numQubits then
              let qa : Qubit numQubits := ⟨⟨q, hq⟩⟩
              let qb : Qubit numQubits := ⟨⟨q + 1, hq1⟩⟩
              circ.add (Gate.CNOT qa qb)
            else circ
          else circ
        ) c1
      (c2, p1)
    let (final, _) := (List.range depth).foldl
      (fun ((c : Circuit numQubits), (p : Nat)) (d : Nat) => buildLayer c p d)
      (Circuit.identity numQubits, 0)
    final

end Quantum4Lean
