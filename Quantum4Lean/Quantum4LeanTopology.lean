/-
Quantum4LeanTopology.lean
Topologia discreta para Quantum4Lean: Hodge decomposition, Betti, FirmaPrima.

Extraido de hrsnn + topology (Hodge-Riemannian Spectral Networks,
Topological Hodge-Riemann SAT Converter).

Formalismo:
  Ω¹(M) = d(Ω⁰) ⊕ δ(Ω²) ⊕ H¹(M)
           exact    coexact   harmonic

  P_harmonic = I - d0(d0†d0)⁻¹d0† - d1†(d1d1†)⁻¹d1
  b₁ = trace(P_harmonic) = dim(H¹)

Operaciones:
  - SparseMatrix: COO format, matvec, transpose, trace
  - Hodge decomposition para matrices pequeñas (≤ 20x20)
  - FirmaPrima: clasificacion de enteros por signatura prima
  - topologicalKappa: acoplamiento topologia-optimizacion

Compatible: Lean 4.31.0, puro, sin dependencias externas.
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean

-- ===================================================================
-- SparseMatrix (COO format)
-- ===================================================================

/--
Matriz dispersa en formato COO (coordinate list).
Filas, columnas y valores como listas paralelas.
-/
structure SparseMatrix where
  rows   : List Nat
  cols   : List Nat
  values : List Float
  nrows  : Nat
  ncols  : Nat
  deriving Repr

namespace SparseMatrix

/-- Matriz identidad dispersa n x n. -/
def identity (n : Nat) : SparseMatrix :=
  { rows   := List.range n
  , cols   := List.range n
  , values := List.replicate n 1.0
  , nrows  := n
  , ncols  := n }

/-- Numero de elementos no nulos. -/
def nnz (m : SparseMatrix) : Nat := m.values.length

/-- Traza de la matriz (suma de elementos diagonales). -/
def trace (m : SparseMatrix) : Float :=
  let triples := List.zip m.rows (List.zip m.cols m.values)
  triples.foldl (fun (acc : Float) ((r, (c, v)) : Nat × (Nat × Float)) =>
    if r == c then acc + v else acc
  ) 0.0

/-- Multiplicacion matriz dispersa × vector denso: y = A * x. -/
def matvec (m : SparseMatrix) (x : List Float) : List Float :=
  let n := m.nrows
  let pairs := List.zip m.rows (List.zip m.cols m.values)
  (List.range n).map fun i =>
    pairs.foldl (fun (acc : Float) ((r, (c, v)) : Nat × (Nat × Float)) =>
      if r == i then
        let xc := x[c]? |>.getD 0.0
        acc + v * xc
      else acc
    ) 0.0

/-- Transpuesta de la matriz dispersa. -/
def transpose (m : SparseMatrix) : SparseMatrix :=
  { rows   := m.cols
  , cols   := m.rows
  , values := m.values
  , nrows  := m.ncols
  , ncols  := m.nrows }

/-- Construye matriz desde lista densa (para matrices pequeñas). -/
def fromDense (dense : List (List Float)) : SparseMatrix :=
  let nrows := dense.length
  let ncols := if nrows == 0 then 0 else dense[0]!.length
  let triples : List (Nat × Nat × Float) :=
    listBind (List.range nrows) fun i =>
      let row := dense[i]!
      (List.range ncols).filterMap fun j =>
        let v := row[j]? |>.getD 0.0
        if v.abs < 1e-15 then none
        else some (i, j, v)
  { rows   := triples.map fun (r, _, _) => r
  , cols   := triples.map fun (_, c, _) => c
  , values := triples.map fun (_, _, v) => v
  , nrows  := nrows
  , ncols  := ncols }

end SparseMatrix

-- ===================================================================
-- Operaciones densas auxiliares (matrices ≤ 20x20)
-- ===================================================================

/-- Convierte SparseMatrix a densa (lista de filas). --/
private def toDense (m : SparseMatrix) : List (List Float) :=
  let zeroRow : List Float := List.replicate m.ncols 0.0
  let empty : List (List Float) := List.replicate m.nrows zeroRow
  let triples := List.zip m.rows (List.zip m.cols m.values)
  triples.foldl (fun (dense : List (List Float)) ((r, (c, v)) : Nat × (Nat × Float)) =>
    if r < m.nrows && c < m.ncols then
      let oldRow := dense[r]!
      let newRow := (List.range m.ncols).map fun j =>
        if j == c then oldRow[j]! + v else oldRow[j]!
      (List.range m.nrows).map fun i => if i == r then newRow else dense[i]!
    else dense
  ) empty

/-- Multiplica dos SparseMatrix: C = A * B. --/
private def sparseMul (a b : SparseMatrix) : SparseMatrix :=
  if a.ncols != b.nrows then
    { rows := [], cols := [], values := [], nrows := a.nrows, ncols := b.ncols }
  else
    let aDense := toDense a
    let bDense := toDense b
    let n := a.nrows
    let m := b.ncols
    let l := a.ncols
    let resultRows : List (List Float) :=
      (List.range n).map fun i =>
        (List.range m).map fun j =>
          (List.range l).foldl (fun acc k =>
            acc + aDense[i]![k]! * bDense[k]![j]!
          ) 0.0
    SparseMatrix.fromDense resultRows

/-- Suma dos SparseMatrix: C = A + B. --/
private def sparseAdd (a b : SparseMatrix) : SparseMatrix :=
  let nrows := if a.nrows < b.nrows then a.nrows else b.nrows
  let ncols := if a.ncols < b.ncols then a.ncols else b.ncols
  let pairsA := List.zip a.rows (List.zip a.cols a.values)
  let pairsB := List.zip b.rows (List.zip b.cols b.values)
  let rows : List (List Float) :=
    (List.range nrows).map fun i =>
      (List.range ncols).map fun j =>
        let va := pairsA.foldl (fun acc ((r, (c, v)) : Nat × (Nat × Float)) =>
          if r == i && c == j then acc + v else acc
        ) 0.0
        let vb := pairsB.foldl (fun acc ((r, (c, v)) : Nat × (Nat × Float)) =>
          if r == i && c == j then acc + v else acc
        ) 0.0
        va + vb
  SparseMatrix.fromDense rows

private def denseRank (dense : List (List Float)) (nrows ncols : Nat) : Nat :=
  let rec eliminate (fuel : Nat) (m : List (List Float)) (row col rank : Nat) : Nat :=
    match fuel with
    | 0 => rank
    | fuel + 1 =>
      if row >= nrows || col >= ncols then rank else
      let colVals := m.map fun r => (r[col]? |>.getD 0.0).abs
      let maxVal := (List.range nrows).foldl (fun (mx : Float) (i : Nat) =>
        if i >= row && colVals[i]! > mx then colVals[i]! else mx
      ) 0.0
      if maxVal < 1e-8 then
        eliminate fuel m row (col + 1) rank
      else
        let pivotRow := (List.range nrows).foldl (fun (best : Nat) (i : Nat) =>
          if i >= row && colVals[i]! > colVals[best]! then i else best
        ) row
        let mSwapped :=
          if pivotRow == row then m
          else
            (List.range nrows).map fun i =>
              if i == row then m[pivotRow]!
              else if i == pivotRow then m[row]!
              else m[i]!
        let pivot := mSwapped[row]![col]!
        let mElim := (List.range nrows).map fun i =>
          if i == row then
            (List.range ncols).map fun j => mSwapped[i]![j]! / pivot
          else
            let factor := mSwapped[i]![col]!
            (List.range ncols).map fun j =>
              mSwapped[i]![j]! - factor * mSwapped[row]![j]!
        eliminate fuel mElim (row + 1) (col + 1) (rank + 1)
  eliminate (ncols + 1) dense 0 0 0

private def nullspaceRect (dense : List (List Float)) (nrows ncols : Nat) : List (List Float) :=
  if ncols == 0 then []
  else
    let rec rref (fuel : Nat) (m : List (List Float)) (row col : Nat) (pivots : List (Nat × Nat)) :
        List (List Float) × List (Nat × Nat) :=
      match fuel with
      | 0 => (m, pivots)
      | fuel + 1 =>
        if row >= nrows || col >= ncols then (m, pivots) else
        let colVals := m.map fun r => (r[col]? |>.getD 0.0).abs
        let maxVal := (List.range nrows).foldl (fun (mx : Float) (i : Nat) =>
          if i >= row && colVals[i]! > mx then colVals[i]! else mx
        ) 0.0
        if maxVal < 1e-8 then
          rref fuel m row (col + 1) pivots
        else
          let pivotRow := (List.range nrows).foldl (fun (best : Nat) (i : Nat) =>
            if i >= row && colVals[i]! > colVals[best]! then i else best
          ) row
          let mSwapped :=
            if pivotRow == row then m
            else
              (List.range nrows).map fun i =>
                if i == row then m[pivotRow]!
                else if i == pivotRow then m[row]!
                else m[i]!
          let pivot := mSwapped[row]![col]!
          let mElim := (List.range nrows).map fun i =>
            if i == row then
              (List.range ncols).map fun j => mSwapped[i]![j]! / pivot
            else
              let factor := mSwapped[i]![col]!
              (List.range ncols).map fun j =>
                mSwapped[i]![j]! - factor * mSwapped[row]![j]!
          rref fuel mElim (row + 1) (col + 1) (pivots ++ [(row, col)])
    let (reduced, pivots) := rref (ncols + 1) dense 0 0 []
    let pivotCols := pivots.map fun (_, c) => c
    let freeCols := (List.range ncols).filter fun j => !(pivotCols.contains j)
    freeCols.map fun freeCol =>
      (List.range ncols).map fun j =>
        match pivots.find? (fun (_, c) => c == j) with
        | some (r, _) => -reduced[r]![freeCol]!
        | none => if j == freeCol then 1.0 else 0.0

-- ===================================================================
-- Hodge Decomposition (para matrices pequeñas, ≤ 20x20)
-- ===================================================================

/--
Calcula el Laplaciano de Hodge L = d0*d0^T + d1^T*d1.
-/
private def laplacian (d0 d1 : SparseMatrix) : SparseMatrix :=
  let d0T := SparseMatrix.transpose d0
  let d1T := SparseMatrix.transpose d1
  let left := sparseMul d0 d0T
  let right := sparseMul d1T d1
  sparseAdd left right

/--
Encuentra el espacio nulo de una matriz cuadrada n×n via eliminacion
gaussiana con tracking de columnas pivote. Devuelve lista de vectores
base (cada uno es List Float de longitud n).
-/
private def nullspaceBasis (dense : List (List Float)) (n : Nat) : List (List Float) :=
  if n == 0 then []
  else
    let rec rref (fuel : Nat) (m : List (List Float)) (row col : Nat) (pivots : List (Nat × Nat)) :
        List (List Float) × List (Nat × Nat) :=
      match fuel with
      | 0 => (m, pivots)
      | fuel + 1 =>
      if row >= n || col >= n then (m, pivots) else
        let colVals := m.map fun r => (r[col]? |>.getD 0.0).abs
        let maxVal := (List.range n).foldl (fun (mx : Float) (i : Nat) =>
          if i >= row && colVals[i]! > mx then colVals[i]! else mx
        ) 0.0
        if maxVal < 1e-8 then
          rref fuel m row (col + 1) pivots
        else
          let pivotRow := (List.range n).foldl (fun (best : Nat) (i : Nat) =>
            if i >= row && colVals[i]! > colVals[best]! then i else best
          ) row
          let mSwapped :=
            if pivotRow == row then m
            else
              (List.range n).map fun i =>
                if i == row then m[pivotRow]!
                else if i == pivotRow then m[row]!
                else m[i]!
          let pivot := mSwapped[row]![col]!
          let mElim := (List.range n).map fun i =>
            if i == row then
              (List.range n).map fun j => mSwapped[i]![j]! / pivot
            else
              let factor := mSwapped[i]![col]!
              (List.range n).map fun j =>
                mSwapped[i]![j]! - factor * mSwapped[row]![j]!
          rref fuel mElim (row + 1) (col + 1) (pivots ++ [(row, col)])
    let (reduced, pivots) := rref (n + 1) dense 0 0 []
    let pivotCols := pivots.map fun (_, c) => c
    let freeCols := (List.range n).filter fun j => !(pivotCols.contains j)
    freeCols.map fun freeCol =>
      (List.range n).map fun j =>
        match pivots.find? (fun (_, c) => c == j) with
        | some (r, _) => -reduced[r]![freeCol]!
        | none => if j == freeCol then 1.0 else 0.0

/--
Ortonormaliza una lista de vectores via Gram-Schmidt.
-/
private def gramSchmidt (n : Nat) (vecs : List (List Float)) : List (List Float) :=
  let proj (u w : List Float) : Float :=
    (List.range n).foldl (fun acc i => acc + u[i]! * w[i]!) 0.0
  match vecs with
  | [] => []
  | v :: rest =>
    let normSq := proj v v
    if normSq < 1e-15 then gramSchmidt n rest
    else
      let invNorm := 1.0 / Float.sqrt normSq
      let vNorm := v.map fun x => x * invNorm
      let restProj := rest.map fun w =>
        let dot := proj vNorm w
        (List.range n).map fun i => w[i]! - dot * vNorm[i]!
      let restOrtho := gramSchmidt n restProj
      vNorm :: restOrtho
termination_by vecs.length

/--
Proyector armonico: P = sum_i |v_i><v_i| donde v_i son vectores
ortonormales del espacio nulo del Laplaciano L = d0*d0^T + d1^T*d1.
Para matrices <= 20x20. Devuelve none si el calculo falla.
-/
def harmonicProjector (d0 : SparseMatrix) (d1 : SparseMatrix) : Option SparseMatrix :=
  if d0.nrows != d1.ncols then none
  else
  let n := d0.nrows
  if n > 20 then none
  else
  let constraints := toDense (SparseMatrix.transpose d0) ++ toDense d1
  let basis := nullspaceRect constraints (d0.ncols + d1.nrows) n
  let onBasis := gramSchmidt n basis
  if onBasis.isEmpty then none
  else
    -- Construir proyector: P[i,j] = sum_k v_k[i] * v_k[j]
    let projDense : List (List Float) :=
      (List.range n).map fun i =>
        (List.range n).map fun j =>
          onBasis.foldl (fun acc v => acc + v[i]! * v[j]!) 0.0
    some (SparseMatrix.fromDense projDense)

/--
Numero de Betti b1 = dim(H^1) = dim(nullspace(L)).
-/
def bettiNumber (d0 : SparseMatrix) (d1 : SparseMatrix) : Nat :=
  if d0.nrows != d1.ncols then 0
  else
    let nEdges := d0.nrows
    let r0 := denseRank (toDense d0) d0.nrows d0.ncols
    let r1 := denseRank (toDense d1) d1.nrows d1.ncols
    nEdges - r0 - r1

-- ===================================================================
-- FirmaPrima: clasificacion de enteros por signatura prima
-- ===================================================================

/--
Clasificacion prima de un entero q:
  IMPAR_PURO: solo factores impares (sin potencias de 2)
  PAR_PURO:   solo potencias de 2
  MIXTO:      factores impares Y potencias de 2
  ADITIVO:    q ≤ 1 (degenerado)
-/
inductive FirmaPrima where
  | IMPAR_PURO | PAR_PURO | MIXTO | ADITIVO
  deriving Repr, DecidableEq

/--
Determina la firma prima TCAGM de un entero q.
Bit-exact con topology.cpp + hodge.py.
-/
def firmaPrima (q : Nat) : FirmaPrima :=
  if q <= 1 then
    FirmaPrima.ADITIVO
  else
    -- Contar factores de 2 y extraer parte impar
    let (alpha, oddPart) := (List.range 64).foldl
      (fun ((a, n) : Nat × Nat) (_ : Nat) =>
        if n % 2 == 0 then (a + 1, n / 2) else (a, n)
      ) (0, q)
    let tieneImpares := oddPart > 1
    if alpha == 0 && tieneImpares then FirmaPrima.IMPAR_PURO
    else if alpha > 0 && !tieneImpares then FirmaPrima.PAR_PURO
    else if alpha > 0 && tieneImpares then FirmaPrima.MIXTO
    else FirmaPrima.ADITIVO

/--
Tabla de firmas primas para numeros del 1 al 30 (validacion).
-/
def firmaPrimaTable : List (Nat × FirmaPrima) :=
  (List.range 30).map fun i =>
    let q := i + 1
    (q, firmaPrima q)

-- ===================================================================
-- Topological Kappa: acoplamiento topologia-optimizacion
-- ===================================================================

/--
Calcula kappa topologico para acoplamiento CDCL-TCAGM.

Parametros:
  b1: numero de Betti (dimension del espacio armonico)
  nVars: numero de variables
  nClauses: numero de clausulas/restricciones

Formula (bit-exact con coupling.py):
  densidad_base = b1 / nVars
  compacidad = (nClauses * 0.67) / nVars
  kappa = 0.5 * tanh(densidad_base * 3.0) + 0.3  (si b1 > 0)
  kappa = -0.2                                  (si b1 == 0)
  Ajuste por compacidad si > 2.5: kappa -= 0.1
-/
def topologicalKappa (b1 : Nat) (nVars : Nat) (nClauses : Nat) : Float :=
  let nv := if nVars == 0 then 1.0 else nVars.toFloat
  let b1f := b1.toFloat
  let nc := nClauses.toFloat
  let densidadBase := b1f / nv
  let compacidad := (nc * 0.67) / nv
  -- tanh via formula: (e^2x - 1) / (e^2x + 1)
  let tanh (x : Float) : Float :=
    let e2x := Float.exp (2.0 * x)
    (e2x - 1.0) / (e2x + 1.0)
  let kappa :=
    if b1 > 0 then
      0.5 * tanh (densidadBase * 3.0) + 0.3
    else
      -0.2
  let kappa := if compacidad > 2.5 then kappa - 0.1 else kappa
  -- Clamp a [-1, 1]
  if kappa > 1.0 then 1.0
  else if kappa < -1.0 then -1.0
  else kappa

end Quantum4Lean
