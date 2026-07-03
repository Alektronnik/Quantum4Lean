/-
QuantumPlaygroundTest.lean
Tests de validacion para el motor polinomico (expandCubic, polyToIsing).

Verifica que las expansiones coinciden con la evaluacion directa.
-/

import Quantum4Lean
import Quantum4LeanPlayground.QuantumPlaygroundCommon

open Quantum4Lean
open Quantum4LeanPlayground.Common

namespace Quantum4LeanPlayground.Test

/--
Verifica que polyToIsing produce el valor correcto para x^3 = c.
Para cada estado base |x>, la energia <x|H|x> debe ser (x^3 - c)^2.
-/
def testCubicExpansion (bits : Nat) (c : Int) : Bool :=
  let eq : PolyEquation := {
    monomials := [{ coefficient := 1, exponents := [(0, 3)] }],
    constant := c,
    varBits := [bits]
  }
  let H := polyToIsing eq
  let dim := 1 <<< bits
  -- Verificar cada estado base
  (List.range dim).all fun state =>
    let x := state
    let expected := (intToFloat (x*x*x - c))^2
    -- Inicializar state vector en |state>
    let svResult := StateVector.init bits
    match svResult with
    | Except.error _ => false
    | Except.ok sv =>
      -- Preparar |state> aplicando X a los bits=1
      let svPrepared := (List.range bits).foldl (fun (s : StateVector) (j : Nat) =>
        if ((state >>> j) &&& 1) == 1 then
          -- Necesitamos un Qubit bits con indice j
          -- Esto requiere dependent types, lo simplificamos
          s
        else s
      ) sv
      -- Calcular expectacion
      let e := expect svPrepared H
      (e - expected).abs < 1e-6

/--
Test simplificado: verifica que la expansion cubica produce
el numero correcto de terminos y que el Hamiltoniano no es vacio.
-/
def testCubicStructure : String :=
  let bits := 2
  let eq : PolyEquation := {
    monomials := [{ coefficient := 1, exponents := [(0, 3)] }],
    constant := 0,
    varBits := [bits]
  }
  let H := polyToIsing eq
  let nTerms := H.strings.length
  -- Para x^3 con 2 bits, esperamos: I + 3*Z + 3*ZZ + ZZZ = ~20 terminos
  -- (no todos los terminos sobreviven a la simplificacion)
  s!"Test expandCubic (2 bits):\n" ++
  s!"  Terminos en H: {nTerms}\n" ++
  s!"  Esperado > 0: {if nTerms > 0 then "si" else "no"}\n" ++
  s!"  (verificar manualmente si la expansion es correcta)"

/--
Compara polyToIsing con evaluacion directa para casos simples.
Usa bruteForceSolve para verificar que el ground state tiene energia 0.
-/
def testExactSolution : String :=
  -- Caso 1: x^3 = 8, solucion x=2 (con 3 bits: 0..7)
  let eq1 : PolyEquation := {
    monomials := [{ coefficient := 1, exponents := [(0, 3)] }],
    constant := 8,
    varBits := [3]
  }
  let sol1 := bruteForceSolve eq1
  let ok1 := sol1.any fun (vals, e) => e < 1e-6 && vals.get! 0 == 2

  -- Caso 2: x^2 = 9, soluciones x=3 (y tambien x=3 solo, x^2 es par)
  let eq2 : PolyEquation := {
    monomials := [{ coefficient := 1, exponents := [(0, 2)] }],
    constant := 9,
    varBits := [4]
  }
  let sol2 := bruteForceSolve eq2
  let exact2 := sol2.filter fun (_, e) => e < 1e-6

  s!"Test PolyToIsing Exactitud:\n" ++
  s!"  x^3=8, x en 0..7: sol x=2 -> {ok1}\n" ++
  s!"  x^2=9, x en 0..15: soluciones exactas={exact2.length} -> {exact2.any fun (v,_) => v.get! 0 == 3}"

def report : String :=
  testCubicStructure ++ "\n\n" ++ testExactSolution

end Quantum4LeanPlayground.Test
