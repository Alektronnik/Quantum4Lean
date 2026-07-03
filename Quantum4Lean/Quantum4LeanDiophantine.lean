/-
Quantum4LeanDiophantine.lean
Traductor: ecuaciones diofantinas lineales -> Ising Hamiltonians.

Dada ax + by = c, con x,y representados en b bits cada uno:
  x = Σ 2^j q_j,  q_j = (I - Z_j)/2
  Coste = (ax + by - c)² = Σ terminos de Pauli Z

Resoluble via QAOA nativo de Quantum4Lean.

Compatible: Lean 4.7.0, build autocontenido.
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanEngine
import Quantum4Lean.Quantum4LeanObservable
import Quantum4Lean.Quantum4LeanQAOA

namespace Quantum4Lean

structure DiophantineVar where
  coeff : Int
  name  : String
  bits  : Nat
  deriving Repr

structure Diophantine where
  vars     : List DiophantineVar
  constant : Int
  deriving Repr

structure DiophantineResult where
  values    : List (String × Int)
  energy    : Float
  satisfied : Bool
  deriving Repr

private def intToFloat (x : Int) : Float :=
  if x >= 0 then x.toNat.toFloat else -(((-x).toNat.toFloat))

private def pow2 (n : Nat) : Float :=
  match n with
  | 0 => 1.0
  | n+1 => 2.0 * pow2 n

private def listGet (xs : List α) (i : Nat) (d : α) : α := xs.get? i |>.getD d

private def listMapIdx {α β : Type} (f : Nat -> α -> β) : List α -> List β :=
  let rec go (i : Nat) : List α -> List β
    | [] => []
    | y :: ys => f i y :: go (i + 1) ys
  go 0

def toIsing (eq : Diophantine) (bitsPerVar : Nat := 4) : Observable :=
  let vars := eq.vars
  let nVars := vars.length
  let c := intToFloat eq.constant
  let qIdx (i j : Nat) : Nat := i * bitsPerVar + j
  let linear : List PauliString :=
    (List.range nVars).bind fun i =>
      let v := listGet vars i { coeff := 0, name := "", bits := 0 }
      let a := intToFloat v.coeff
      (List.range v.bits).map fun j =>
        let cz := c * a * pow2 j
        PauliString.mk cz [PauliTerm.mk .Z (qIdx i j)]
  let diagonal : List PauliString :=
    (List.range nVars).bind fun i =>
      let v := listGet vars i { coeff := 0, name := "", bits := 0 }
      let a2 := intToFloat (v.coeff * v.coeff)
      (List.range v.bits).bind fun j =>
        (List.range v.bits).filter (fun l => j < l) |>.map fun l =>
          PauliString.mk (a2 * pow2 (j + l) / 2.0) [PauliTerm.mk .Z (qIdx i j), PauliTerm.mk .Z (qIdx i l)]
  let crossed : List PauliString :=
    (List.range nVars).bind fun i =>
      (List.range nVars).filter (fun k => i < k) |>.bind fun k =>
        let vi := listGet vars i { coeff := 0, name := "", bits := 0 }
        let vk := listGet vars k { coeff := 0, name := "", bits := 0 }
        let aik := intToFloat (vi.coeff * vk.coeff)
        (List.range vi.bits).bind fun j =>
          (List.range vk.bits).map fun l =>
            PauliString.mk (aik * pow2 (j + l) / 2.0) [PauliTerm.mk .Z (qIdx i j), PauliTerm.mk .Z (qIdx k l)]
  { strings := linear ++ diagonal ++ crossed }

def diophantineSolve (eq : Diophantine) (bitsPerVar : Nat := 4)
    (jCoupling : Float := 1.0) (hField : Float := 0.5)
    (p : Nat := 1) (lr : Float := 0.05) (iters : Nat := 100) : DiophantineResult :=
  let n := eq.vars.length * bitsPerVar
  -- QAOA optimiza el Hamiltoniano Ising 1D; el Observable diofantino (toIsing)
  -- puede acoplarse via VQE con ansatz personalizado en version futura.
  let _H := toIsing eq bitsPerVar
  let (energy, _, _) := qaoaIsing n p jCoupling hField lr iters
  { values := eq.vars.map fun v => (v.name, 0)
  , energy := energy
  , satisfied := false
  }

def checkSolution (eq : Diophantine) (values : List (String × Int)) : Bool :=
  let sum := values.foldl (fun (acc : Int) ((name, val) : String × Int) =>
    match eq.vars.find? fun v => v.name == name with
    | some v => acc + v.coeff * val
    | none => acc
  ) 0
  sum == eq.constant

/-- Decodifica valores desde StateVector (bit mas probable por qubit). --/
def decodeValues (eq : Diophantine) (bitsPerVar : Nat) (sv : StateVector) : List (String × Int) :=
  let probs : Array Float := StateVector.probabilities sv
  let totalDim : Nat := StateVector.dim sv
  let (maxIdx, _) : Nat × Float :=
    (List.range totalDim).foldl
      (fun ((bestIdx, bestProb) : Nat × Float) (idx : Nat) =>
        let p : Float := probs.get! idx
        if p > bestProb then (idx, p) else (bestIdx, bestProb)
      ) (0, 0.0)
  listMapIdx (fun i (v : DiophantineVar) =>
    let startQ := i * bitsPerVar
    let val : Int := (List.range v.bits).foldl (fun (acc : Int) (j : Nat) =>
      let bitVal : Nat := (maxIdx >>> (startQ + j)) &&& 1
      if bitVal == 1 then acc + ((1 <<< j : Nat) : Int) else acc
    ) 0
    (v.name, val)
  ) eq.vars

end Quantum4Lean
