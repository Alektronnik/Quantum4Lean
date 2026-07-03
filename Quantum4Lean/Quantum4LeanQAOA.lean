/-
Quantum4LeanQAOA.lean
Quantum Approximate Optimization Algorithm (QAOA) puro sobre StateVector.

Sin FFI, sin monada, sin IO. Todo es funcion pura.

QAOA alterna p capas de:
  1. Cost layer:   e^{-i*gamma*H_C}  (codifica el problema)
  2. Mixing layer: e^{-i*beta*H_M}   (explora el espacio)

Cada capa construye fragmentos de Circuit n que se componen.
La optimizacion usa VQE (parameter-shift + gradient descent).

Uso:
  def H := Observable.ising1D 4 1.0 0.5
  let (energy, params, history) := qaoaIsing 4 1 1.0 0.5

Compatible: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean.Quantum4LeanVQE

namespace Quantum4Lean

-- ===================================================================
-- Helpers para construir puertas con Nat indices
-- ===================================================================

private def mkQ (n : Nat) (q : Nat) (h : q < n) : Qubit n := ⟨⟨q, h⟩⟩

-- ===================================================================
-- Capas QAOA como fragmentos de Circuit
-- ===================================================================

/--
Capa de mixing: e^{-i*beta*H_M} con H_M = sum_i X_i.
= RX(2*beta) en cada qubit.
-/
def qaoaMixingLayer (numQubits : Nat) (beta : Float) : Circuit numQubits :=
  let gates := (List.range numQubits).filterMap fun q =>
    if h : q < numQubits then
      some (Gate.RX (mkQ numQubits q h) (2.0 * beta))
    else none
  { gates := gates }

/--
Capa de coste para Ising: e^{-i*gamma*H_C}
  H_C = -J sum Z_i Z_{i+1} - h sum Z_i

Cada Z_i Z_{i+1}: CNOT(i,i+1); RZ_{i+1}(-2*gamma*J); CNOT(i,i+1)
Cada Z_i: RZ_i(-2*gamma*h)
-/
def qaoaIsingCostLayer (numQubits : Nat) (gamma : Float)
    (jCoupling : Float) (hField : Float) : Circuit numQubits :=
  let gatesZZ := listBind (List.range (numQubits - 1)) fun i =>
    if hi : i < numQubits then
      if hi1 : i + 1 < numQubits then
        let qi := mkQ numQubits i hi
        let qi1 := mkQ numQubits (i+1) hi1
        [Gate.CNOT qi qi1,
         Gate.RZ qi1 (-2.0 * gamma * jCoupling),
         Gate.CNOT qi qi1]
      else []
    else []
  let gatesZ := (List.range numQubits).filterMap fun i =>
    if h : i < numQubits then
      some (Gate.RZ (mkQ numQubits i h) (-2.0 * gamma * hField))
    else none
  { gates := gatesZZ ++ gatesZ }

private def qaoaIsingObservable (numQubits : Nat) (jCoupling : Float) (hField : Float) : Observable :=
  let pairs := List.range (numQubits - 1) |>.map fun i =>
    PauliString.mk (-jCoupling)
      [PauliTerm.mk .Z i, PauliTerm.mk .Z (i+1)]
  let fields := List.range numQubits |>.map fun i =>
    PauliString.mk (-hField) [PauliTerm.mk .Z i]
  { strings := pairs ++ fields }

/--
Circuito QAOA completo para Ising de p capas.

Inicializa en |+...+> (H en todos los qubits), luego
alterna cost y mixing p veces.

Parametros: [gamma_1..gamma_p, beta_1..beta_p] = 2p total.
-/
def qaoaIsingCircuit (numQubits : Nat) (p : Nat)
    (jCoupling : Float) (hField : Float) : List Float -> Circuit numQubits :=
  fun params =>
    -- Inicializar en superposicion uniforme
    let initGates := (List.range numQubits).filterMap fun q =>
      if h : q < numQubits then some (Gate.H (mkQ numQubits q h)) else none
    let init : Circuit numQubits := { gates := initGates }
    -- p capas
    let layers := (List.range p).foldl (fun (c : Circuit numQubits) (layer : Nat) =>
      let gamma := params[layer]? |>.getD 0.0
      let beta  := params[p + layer]? |>.getD 0.0
      let costLayer := qaoaIsingCostLayer numQubits gamma jCoupling hField
      let mixLayer := qaoaMixingLayer numQubits beta
      c.comp costLayer |>.comp mixLayer
    ) init
    layers

-- ===================================================================
-- Optimizacion QAOA
-- ===================================================================

/--
QAOA para Ising: optimiza gamma_1..gamma_p, beta_1..beta_p.

- numQubits: numero de qubits
- p: profundidad (numero de capas)
- jCoupling: acoplamiento J del modelo de Ising
- hField: campo transversal h
- learningRate: tasa de aprendizaje
- maxIter: iteraciones maximas

Devuelve (energia final, parametros optimos, historial).
-/
def qaoaIsing (numQubits : Nat) (p : Nat) (jCoupling : Float) (hField : Float)
    (learningRate : Float := 0.05) (maxIter : Nat := 100) : Float × List Float × List Float :=
  let obs := qaoaIsingObservable numQubits jCoupling hField
  let circuit := qaoaIsingCircuit numQubits p jCoupling hField
  let initialParams := List.replicate (2 * p) 0.1
  vqe circuit obs initialParams learningRate maxIter

end Quantum4Lean
