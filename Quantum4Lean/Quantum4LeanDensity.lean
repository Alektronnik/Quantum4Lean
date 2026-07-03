/-
Quantum4LeanDensity.lean
Matrices de densidad + canales de ruido cuantico CPTP.

Formalismo riguroso:
  - DensityMatrix n: matriz 2^n x 2^n, Hermitica, traza 1
  - applyGate: rho -> U rho U^dagger via operadores de Kraus elementales
  - depolarize, amplitudeDamping, phaseDamping

Limitacion: max 5 qubits (1024 complejos por matriz).

Compatible: Lean 4.31.0.
-/

import Quantum4Lean.Quantum4LeanCore
import Quantum4Lean.Quantum4LeanObservable

namespace Quantum4Lean

structure DensityMatrix (n : Nat) where
  data      : Array Float
  numQubits : Nat
  dim       : Nat
  deriving Repr

namespace DensityMatrix

def init (n : Nat) : Except String (DensityMatrix n) :=
  if n < 1 || n > 5 then
    Except.error s!"DensityMatrix.init: n={n} fuera de [1,5]"
  else
    let d := 1 <<< n
    let elems := 2 * d * d
    let data := (List.range elems).foldl (fun arr _ => arr.push 0.0) (Array.mkEmpty elems)
    let data := data.set! 0 1.0
    Except.ok { data := data, numQubits := n, dim := d }

def get (rho : DensityMatrix n) (i j : Nat) : Float × Float :=
  let idx := 2 * (i * rho.dim + j)
  if idx + 1 < rho.data.size then (rho.data[idx]!, rho.data[idx + 1]!) else (0.0, 0.0)

def set (rho : DensityMatrix n) (i j : Nat) (re im : Float) : DensityMatrix n :=
  let idx := 2 * (i * rho.dim + j)
  if idx + 1 < rho.data.size then
    { rho with data := (rho.data.set! idx re).set! (idx + 1) im }
  else rho

def trace (rho : DensityMatrix n) : Float :=
  (List.range rho.dim).foldl (fun acc i => acc + (get rho i i).1) 0.0

private def GATE_I   : Array Float := #[1.0,0.0, 0.0,0.0, 0.0,0.0, 1.0,0.0]
private def GATE_X   : Array Float := #[0.0,0.0, 1.0,0.0, 1.0,0.0, 0.0,0.0]
private def GATE_Y   : Array Float := #[0.0,0.0, 0.0,-1.0, 0.0,1.0, 0.0,0.0]
private def GATE_Z   : Array Float := #[1.0,0.0, 0.0,0.0, 0.0,0.0, -1.0,0.0]
private def GATE_S   : Array Float := #[1.0,0.0, 0.0,0.0, 0.0,0.0, 0.0,1.0]
private def GATE_H   : Array Float :=
  let v := Float.sqrt 2.0 / 2.0
  #[v,0.0, v,0.0, v,0.0, -v,0.0]
private def GATE_T   : Array Float :=
  let v := Float.sqrt 2.0 / 2.0
  #[1.0,0.0, 0.0,0.0, 0.0,0.0, v,v]

private def gateRX (theta : Float) : Array Float :=
  let c := Float.cos (theta / 2.0); let s := Float.sin (theta / 2.0)
  #[c,0.0, 0.0,-s, 0.0,-s, c,0.0]

private def gateRY (theta : Float) : Array Float :=
  let c := Float.cos (theta / 2.0); let s := Float.sin (theta / 2.0)
  #[c,0.0, -s,0.0, s,0.0, c,0.0]

private def gateRZ (theta : Float) : Array Float :=
  let c := Float.cos (theta / 2.0); let s := Float.sin (theta / 2.0)
  #[c,-s, 0.0,0.0, 0.0,0.0, c,s]

/--
Aplica puerta 1-qubit (matriz 2x2, 8 floats) sobre qubit k.
rho -> U_k rho U_k^dagger.
-/
private def apply1Q (rho : DensityMatrix n) (k : Nat) (g : Array Float) : DensityMatrix n :=
  let d := rho.dim
  let mask := 1 <<< k
  let g00r := g[0]!; let g00i := g[1]!
  let g01r := g[2]!; let g01i := g[3]!
  let g10r := g[4]!; let g10i := g[5]!
  let g11r := g[6]!; let g11i := g[7]!
  -- U^dagger (conjugada transpuesta)
  let h00r := g00r; let h00i := -g00i
  let h01r := g10r; let h01i := -g10i
  let h10r := g01r; let h10i := -g01i
  let h11r := g11r; let h11i := -g11i
  let result : DensityMatrix n :=
    { data := (List.range (2 * d * d)).foldl (fun arr _ => arr.push 0.0) (Array.mkEmpty (2 * d * d))
    , numQubits := rho.numQubits, dim := d }
  let maskM1 := mask - 1
  (List.range (d >>> 1)).foldl (fun (m : DensityMatrix n) (pIdx : Nat) =>
    let r0 := ((pIdx >>> k) <<< (k + 1)) ||| (pIdx &&& maskM1)
    let r1 := r0 ||| mask
    (List.range (d >>> 1)).foldl (fun (m2 : DensityMatrix n) (qIdx : Nat) =>
      let c0 := ((qIdx >>> k) <<< (k + 1)) ||| (qIdx &&& maskM1)
      let c1 := c0 ||| mask
      let (a,b) := get rho r0 c0; let (c,d) := get rho r0 c1
      let (e,f) := get rho r1 c0; let (g,h) := get rho r1 c1
      -- temp = U * block
      let t00r := g00r*a - g00i*b + g01r*e - g01i*f
      let t00i := g00r*b + g00i*a + g01r*f + g01i*e
      let t01r := g00r*c - g00i*d + g01r*g - g01i*h
      let t01i := g00r*d + g00i*c + g01r*h + g01i*g
      let t10r := g10r*a - g10i*b + g11r*e - g11i*f
      let t10i := g10r*b + g10i*a + g11r*f + g11i*e
      let t11r := g10r*c - g10i*d + g11r*g - g11i*h
      let t11i := g10r*d + g10i*c + g11r*h + g11i*g
      -- result = temp * U^dagger
      let n00r := t00r*h00r - t00i*h00i + t01r*h10r - t01i*h10i
      let n00i := t00r*h00i + t00i*h00r + t01r*h10i + t01i*h10r
      let n01r := t00r*h01r - t00i*h01i + t01r*h11r - t01i*h11i
      let n01i := t00r*h01i + t00i*h01r + t01r*h11i + t01i*h11r
      let n10r := t10r*h00r - t10i*h00i + t11r*h10r - t11i*h10i
      let n10i := t10r*h00i + t10i*h00r + t11r*h10i + t11i*h10r
      let n11r := t10r*h01r - t10i*h01i + t11r*h11r - t11i*h11i
      let n11i := t10r*h01i + t10i*h01r + t11r*h11i + t11i*h11r
      let m3 := set m2 r0 c0 n00r n00i
      let m3 := set m3 r0 c1 n01r n01i
      let m3 := set m3 r1 c0 n10r n10i
      set m3 r1 c1 n11r n11i
    ) m
  ) result

def applyGate (rho : DensityMatrix n) (gate : Gate n) : DensityMatrix n :=
  let k (q : Qubit n) : Nat := q.idx.val
  match gate with
  | .H q    => apply1Q rho (k q) GATE_H
  | .X q    => apply1Q rho (k q) GATE_X
  | .Y q    => apply1Q rho (k q) GATE_Y
  | .Z q    => apply1Q rho (k q) GATE_Z
  | .S q    => apply1Q rho (k q) GATE_S
  | .T q    => apply1Q rho (k q) GATE_T
  | .RX q theta => apply1Q rho (k q) (gateRX theta)
  | .RY q theta => apply1Q rho (k q) (gateRY theta)
  | .RZ q theta => apply1Q rho (k q) (gateRZ theta)
  | .Unitary q m => apply1Q rho (k q) m
  | .CNOT c t =>
    let kc := k c; let kt := k t
    let maskT := 1 <<< kt
    let d := rho.dim
    let result : DensityMatrix n :=
      { data := (List.range (2*d*d)).foldl (fun arr _ => arr.push 0.0) (Array.mkEmpty (2*d*d))
      , numQubits := rho.numQubits, dim := d }
    (List.range d).foldl (fun (m : DensityMatrix n) (i : Nat) =>
      let ci := (i >>> kc) &&& 1
      (List.range d).foldl (fun (m2 : DensityMatrix n) (j : Nat) =>
        let cj := (j >>> kt) &&& 1
        let i2 := i ^^^ (ci * maskT)
        let j2 := j ^^^ (cj * maskT)
        let (re, im) := get rho i2 j2
        set m2 i j re im
      ) m
    ) result
  | .CZ c t =>
    let kc := k c; let kt := k t
    let d := rho.dim
    let result : DensityMatrix n :=
      { data := (List.range (2*d*d)).foldl (fun arr _ => arr.push 0.0) (Array.mkEmpty (2*d*d))
      , numQubits := rho.numQubits, dim := d }
    (List.range d).foldl (fun (m : DensityMatrix n) (i : Nat) =>
      (List.range d).foldl (fun (m2 : DensityMatrix n) (j : Nat) =>
        let pI := ((i >>> kc) &&& 1) * ((i >>> kt) &&& 1)
        let pJ := ((j >>> kc) &&& 1) * ((j >>> kt) &&& 1)
        let (re, im) := get rho i j
        if (pI + pJ) % 2 == 1 then set m2 i j (-re) (-im)
        else set m2 i j re im
      ) m
    ) result
  | .SWAP a b =>
    let ka := k a; let kb := k b
    let maskA := 1 <<< ka; let maskB := 1 <<< kb
    let d := rho.dim
    let result : DensityMatrix n :=
      { data := (List.range (2*d*d)).foldl (fun arr _ => arr.push 0.0) (Array.mkEmpty (2*d*d))
      , numQubits := rho.numQubits, dim := d }
    (List.range d).foldl (fun (m : DensityMatrix n) (i : Nat) =>
      let ia := (i >>> ka) &&& 1; let ib := (i >>> kb) &&& 1
      let iS := i ^^^ ((ia ^^^ ib) * maskA) ^^^ ((ia ^^^ ib) * maskB)
      (List.range d).foldl (fun (m2 : DensityMatrix n) (j : Nat) =>
        let ja := (j >>> ka) &&& 1; let jb := (j >>> kb) &&& 1
        let jS := j ^^^ ((ja ^^^ jb) * maskA) ^^^ ((ja ^^^ jb) * maskB)
        let (re, im) := get rho iS jS
        set m2 i j re im
      ) m
    ) result

def runCircuit (rho : DensityMatrix n) (circuit : Circuit n) : DensityMatrix n :=
  circuit.gates.foldl (fun (cur : DensityMatrix n) (g : Gate n) => applyGate cur g) rho

-- ===================================================================
-- Canales de ruido
-- ===================================================================

def depolarize (rho : DensityMatrix n) (p : Float) : DensityMatrix n :=
  let d := rho.dim
  let factor := p / d.toFloat
  let scaledData := rho.data.map fun x => (1.0 - p) * x
  let result := { rho with data := scaledData }
  (List.range d).foldl (fun (m : DensityMatrix n) (i : Nat) =>
    let idx := 2 * (i * d + i)
    { m with data := m.data.set! idx (m.data[idx]! + factor) }
  ) result

def amplitudeDamping (rho : DensityMatrix n) (k : Nat) (gamma : Float) : DensityMatrix n :=
  let d := rho.dim
  let mask := 1 <<< k
  let sqrt1mG := Float.sqrt (1.0 - gamma)
  let result : DensityMatrix n :=
    { data := (List.range (2*d*d)).foldl (fun arr _ => arr.push 0.0) (Array.mkEmpty (2*d*d))
    , numQubits := rho.numQubits, dim := d }
  (List.range d).foldl (fun (m : DensityMatrix n) (i : Nat) =>
    (List.range d).foldl (fun (m2 : DensityMatrix n) (j : Nat) =>
      let bi := (i >>> k) &&& 1; let bj := (j >>> k) &&& 1
      let (re, im) := get rho i j
      let (re2, im2) :=
        if bi == 0 && bj == 0 then
          let (xr, xi) := get rho (i ||| mask) (j ||| mask)
          (re + gamma * xr, im + gamma * xi)
        else if bi == bj then
          ((1.0 - gamma) * re, (1.0 - gamma) * im)
        else
          (sqrt1mG * re, sqrt1mG * im)
      set m2 i j re2 im2
    ) m
  ) result

def phaseDamping (rho : DensityMatrix n) (k : Nat) (lambda : Float) : DensityMatrix n :=
  let d := rho.dim
  let factor := 1.0 - 2.0 * lambda
  (List.range d).foldl (fun (m : DensityMatrix n) (i : Nat) =>
    (List.range d).foldl (fun (m2 : DensityMatrix n) (j : Nat) =>
      let bi := (i >>> k) &&& 1; let bj := (j >>> k) &&& 1
      let (re, im) := get rho i j
      if bi == bj then set m2 i j re im
      else set m2 i j (factor * re) (factor * im)
    ) m
  ) rho

/--
Valor esperado de un Observable sobre la density matrix.

Tr(O rho) = sum_{P in O} P.coeff * Tr(P rho)

Para cada PauliString P:
  P actua sobre la base computacional como P|j> = phase(j) * |j XOR mask>
  donde mask tiene 1s en qubits con X o Y.

  Tr(P rho) = sum_i phase(i) * rho[i_XOR_mask, i]

Fase por termino Pauli sobre qubit q en estado |b>:
  I: 1
  X: 1  (bit flip, sin fase)
  Y: i * (-1)^b  (bit flip, fase compleja)
  Z: (-1)^b  (sin bit flip, fase real)
-/
def expect (rho : DensityMatrix n) (obs : Observable) : Float :=
  obs.strings.foldl (fun (acc : Float) (ps : PauliString) =>
    let mask := ps.terms.foldl (fun (m : Nat) (t : PauliTerm) =>
      match t.pauli with
      | .X | .Y => m ||| (1 <<< t.qubit)
      | _ => m
    ) 0
    let d := rho.dim
    let trP := (List.range d).foldl (fun (sum : Float) (i : Nat) =>
      let j := i ^^^ mask    -- i XOR mask
      -- Calcular fase en estado j (el estado de entrada a P)
      let phase := ps.terms.foldl (fun (ph : Float × Float) (t : PauliTerm) =>
        let bit := (j >>> t.qubit) &&& 1
        let (re, im) := ph
        match t.pauli with
        | .I => (re, im)
        | .X => (re, im)                    -- X: fase 1
        | .Z => (if bit == 0 then (re, im) else (-re, -im))  -- Z: (-1)^bit
        | .Y =>                               -- Y: i * (-1)^bit
          if bit == 0 then (-im, re)          -- i * 1 = i
          else (im, -re)                      -- i * (-1) = -i
      ) (1.0, 0.0)
      let (rhoRe, rhoIm) := get rho j i
      -- Tr(P rho) = sum phase * rho[j,i]
      -- Real part: phase.re * rhoRe - phase.im * rhoIm
      sum + (phase.1 * rhoRe - phase.2 * rhoIm)
    ) 0.0
    acc + ps.coefficient * trP
  ) 0.0

end DensityMatrix

end Quantum4Lean
