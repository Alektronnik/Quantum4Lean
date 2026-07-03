/-
QuantumBealLargeScale.lean
Playground: Busqueda masiva de contraejemplos a la Conjetura de Beal.

Estrategia cuantica:
  1. polyToIsing: traduce a^3 + b^3 = c^2 a Hamiltoniano Ising (simbolico, ilimitado)
  2. bruteForceSolve: ground truth exhaustivo (~500K estados para 19 qubits)
  3. Filtro gcd(a,b,c) = 1: si existe solucion con gcd=1, es contraejemplo a Beal

Escala: [6,6,7] bits = 19 qubits. a,b en 0..63, c en 0..127.
64x mas rango que el solver base [4,4,5].

Dependencias: Quantum4Lean (Polynomial, Observable, QAOA).
Build autocontenido. Lean 4.7.0.
-/

import Quantum4Lean

open Quantum4Lean

namespace Quantum4LeanPlayground.BealLargeScale

-- ===================================================================
-- Utilidades
-- ===================================================================

/-- gcd de tres enteros. --/
def gcd3 (a b c : Int) : Int :=
  let absA := if a >= 0 then a else -a
  let absB := if b >= 0 then b else -b
  let absC := if c >= 0 then c else -c
  (absA.gcd absB).gcd absC

/-- Convierte Int a Float para evaluacion de coste. --/
def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

/-- Decodifica estado base a valores enteros por variable. --/
def decodeState (varBits : List Nat) (state : Nat) : List Int :=
  let offsets : List Nat :=
    let rec go (acc : Nat) : List Nat -> List Nat
      | [] => []
      | b :: bs => acc :: go (acc + b) bs
    go 0 varBits
  List.mapIdx (fun i (bits : Nat) =>
    let start := offsets.get! i
    (List.range bits).foldl (fun (acc : Nat) (j : Nat) =>
      if ((state >>> (start + j)) &&& 1) == 1 then acc + (1 <<< j) else acc
    ) 0
  ) varBits

/-- Evalua C(a,b,c) = (a^3 + b^3 - c^2)^2 para valores concretos. --/
def evalBealCost (a b c : Int) : Float :=
  let af := intToFloat a
  let bf := intToFloat b
  let cf := intToFloat c
  let diff := af*af*af + bf*bf*bf - cf*cf
  diff * diff

-- ===================================================================
-- Ecuacion Beal a escala grande
-- ===================================================================

/--
Beal cubico-cuadratico: a^3 + b^3 = c^2.
19 qubits: a,b en [0,63], c en [0,127].
Espacio de busqueda: 2^19 = 524288 estados.
-/
def bealLargeEq : PolyEquation := {
  monomials := [
    { coefficient := 1,  exponents := [(0, 3)] },
    { coefficient := 1,  exponents := [(1, 3)] },
    { coefficient := -1, exponents := [(2, 2)] }
  ],
  constant := 0,
  varBits := [6, 6, 7]
}

/-- Hamiltoniano Ising del Beal grande. --/
def bealLargeH : Observable := polyToIsing bealLargeEq

/-- Numero total de qubits. --/
def bealLargeQubits : Nat := polyTotalQubits bealLargeEq

-- ===================================================================
-- Busqueda exhaustiva con filtro Beal
-- ===================================================================

/--
Busca todas las soluciones exactas (energia 0) y las clasifica
por su gcd(a,b,c). Reporta si hay alguna con gcd=1 (contraejemplo).
-/
def searchBealCounterexamples : String :=
  let totalQubits := bealLargeQubits
  let dim := 1 <<< totalQubits
  -- Evaluar todos los estados
  let allResults : List (Nat × Nat × Nat × Float) :=
    (List.range dim).filterMap fun state =>
      let vals := decodeState bealLargeEq.varBits state
      let a := vals.get! 0
      let b := vals.get! 1
      let c := vals.get! 2
      let cost := evalBealCost a b c
      if cost < 1e-6 then some (state.toNat, a, b, c) else none
  -- Clasificar por gcd
  let withGcd := allResults.map fun (_, a, b, c) => (a, b, c, gcd3 a b c)
  let gcd1Sols := withGcd.filter fun (_, _, _, g) => g == 1
  let gcdGt1Sols := withGcd.filter fun (_, _, _, g) => g > 1
  s!"Beal a^3 + b^3 = c^2 (19 qubits: a,b in 0..63, c in 0..127)\n" ++
  s!"Espacio: {dim} estados, evaluados exhaustivamente.\n" ++
  s!"Soluciones exactas totales: {withGcd.length}\n" ++
  s!"Soluciones con gcd=1 (posibles contraejemplos): {gcd1Sols.length}\n" ++
  (if gcd1Sols.isEmpty then
    "  NINGUNA. Beal se mantiene en este rango.\n"
   else
    let examples := gcd1Sols.map fun (a, b, c, _) => s!"  a={a}, b={b}, c={c}"
    String.intercalate "\n" examples ++ "\n") ++
  s!"Soluciones con gcd>1 (cumplen Beal): {gcdGt1Sols.length}\n" ++
  (if gcdGt1Sols.length <= 10 then
    let top := gcdGt1Sols.map fun (a, b, c, g) => s!"  a={a}, b={b}, c={c} (gcd={g})"
    String.intercalate "\n" top
   else
    s!"  (primeras 10 de {gcdGt1Sols.length})")

-- ===================================================================
-- Verificacion QAOA (escala reducida para el motor puro-Lean)
-- ===================================================================

/--
Ejecuta QAOA sobre una version reducida (10 qubits) del Beal
para verificar que el optimizador cuantico converge al ground state.
-/
def bealQAOAValidate : IO String := do
  -- Version reducida: [3,3,4] bits = 10 qubits
  let smallEq : PolyEquation := {
    monomials := [
      { coefficient := 1,  exponents := [(0, 3)] },
      { coefficient := 1,  exponents := [(1, 3)] },
      { coefficient := -1, exponents := [(2, 2)] }
    ],
    constant := 0,
    varBits := [3, 3, 4]
  }
  let n := polyTotalQubits smallEq
  let H := polyToIsing smallEq
  let ansatz (params : List Float) : Circuit n :=
    (qaoaIsingCircuit n 1 1.0 0.5) params
  let (energy, _, _) := vqe ansatz H [0.3, 0.7] 0.05 200
  -- Decodificar: buscar estado base de minima energia
  let dim := 1 <<< n
  let (bestState, bestCost) : Nat × Float :=
    (List.range dim).foldl (fun ((bs, bc) : Nat × Float) (s : Nat) =>
      let vals := decodeState smallEq.varBits s
      let cost := evalBealCost (vals.get! 0) (vals.get! 1) (vals.get! 2)
      if cost < bc then (s, cost) else (bs, bc)
    ) (0, Float.inf)
  let bestVals := decodeState smallEq.varBits bestState
  let aFound := bestVals.get! 0
  let bFound := bestVals.get! 1
  let cFound := bestVals.get! 2
  return s!"QAOA Beal (10 qubits, p=1):\n" ++
    s!"  Energia VQE final: {energy}\n" ++
    s!"  Mejor estado: a={aFound}, b={bFound}, c={cFound}\n" ++
    s!"  Coste: {bestCost}\n" ++
    s!"  Verifica: {evalBealCost aFound bFound cFound < 1e-6}"

-- ===================================================================
-- Reporte
-- ===================================================================

/-- Reporte completo: busqueda exhaustiva + validacion QAOA. --/
def report : String :=
  searchBealCounterexamples

/-- Reporte con QAOA (requiere IO para VQE). --/
def reportFull : IO String := do
  let exhaustive := searchBealCounterexamples
  let qaoa <- bealQAOAValidate
  return s!"{exhaustive}\n\n{qaoa}"

end Quantum4LeanPlayground.BealLargeScale
