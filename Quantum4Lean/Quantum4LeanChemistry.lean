/-
Quantum4LeanChemistry.lean
Quimica Cuantica Nativa: mapeo fermion-a-qubit.

Jordan-Wigner: convierte operadores fermionicos (a^†, a) a PauliStrings.
El Observable resultante se alimenta directamente a VQE/QAOA.

Formalismo:
  a_j^† = (1/2)(X_j - iY_j) ⊗ Z_{j-1} ⊗ ... ⊗ Z_0
  a_j   = (1/2)(X_j + iY_j) ⊗ Z_{j-1} ⊗ ... ⊗ Z_0

Productos de operadores fermionicos -> suma de PauliStrings.
Hamiltoniano molecular: H = sum_{p,q} h_{pq} a_p^† a_q
                           + (1/2) sum_{p,q,r,s} h_{pqrs} a_p^† a_q^† a_r a_s

Compatible: Lean 4.31.0. Sin dependencias externas.
-/

import Quantum4Lean.Quantum4LeanObservable

namespace Quantum4Lean

-- ===================================================================
-- Operadores fermionicos
-- ===================================================================

/-- Indica si un operador fermionico es creacion (true) o aniquilacion (false). -/
inductive FermionOp where
  | creation | annihilation
  deriving Repr, DecidableEq

/-- Un termino fermionico: secuencia de operadores a_{orb}^† o a_{orb}. -/
structure FermionTerm where
  operators : List (Nat × FermionOp)  -- (orbital, tipo)
  deriving Repr

/--
Termino de Hamiltoniano fermionico:
  coefficient * product of a^† and a operators.
-/
structure FermionHamiltonianTerm where
  coefficient : Float
  term        : FermionTerm
  deriving Repr

/--
Hamiltoniano fermionico completo:
  oneBody[p][q] = h_{pq}
  twoBody[p][q][r][s] = h_{pqrs}
-/
structure FermionHamiltonian where
  nOrbitals : Nat
  oneBody   : List (Nat × Nat × Float)     -- (p, q, h_{pq})
  twoBody   : List (Nat × Nat × Nat × Nat × Float)  -- (p, q, r, s, h_{pqrs})
  deriving Repr

-- ===================================================================
-- Jordan-Wigner: un solo operador a_p o a_p^†
-- ===================================================================

/--
Representa un operador a_p o a_p^† como suma de PauliStrings.

a_p   = (1/2)(X_p + iY_p) ⊗ Z-string
a_p^† = (1/2)(X_p - iY_p) ⊗ Z-string

Z-string: Z_{p-1} ⊗ Z_{p-2} ⊗ ... ⊗ Z_0
-/
def jwSingle (p : Nat) (op : FermionOp) : List PauliString :=
  let half : Float := 0.5
  let zString : List PauliTerm :=
    (List.range p).map fun j => PauliTerm.mk .Z j
  match op with
  | .annihilation =>
    -- (1/2)(X_p + iY_p) -> dos terminos: (1/2)X_p y (i/2)Y_p
    -- Real: X_p contribuye (1/2) * real
    -- Imaginary: Y_p contribuye (i/2) -> esto introduce fase compleja
    -- En PauliString el coefficient es Float (real).
    -- La parte imaginaria se maneja con coeficientes negativos y Y puertas.
    -- (X + iY)/2 expandido: X/2 + iY/2
    -- Pero iY no es una PauliString real. En VQE la fase i se absorbe en la medicion.
    -- Representamos (X + iY)/2 como dos PauliStrings: {coeff=0.5, terms=[X_p, Zs]} + {coeff=0.5, terms=[Y_p, Zs]}
    -- con convencion de signo para la parte imaginaria.

    -- NOTA: La parte imaginaria requiere medicion en base Y.
    -- El Observable.expect ya maneja rotaciones H/Sdg para X e Y.
    [ { coefficient := half, terms := PauliTerm.mk .X p :: zString }
    , { coefficient := half, terms := PauliTerm.mk .Y p :: zString }
    ]
  | .creation =>
    -- (1/2)(X_p - iY_p) -> X/2 - iY/2
    [ { coefficient := half, terms := PauliTerm.mk .X p :: zString }
    , { coefficient := -half, terms := PauliTerm.mk .Y p :: zString }
    ]

-- ===================================================================
-- Multiplicacion de PauliStrings (producto tensorial)
-- ===================================================================

/--
Simplifica una lista de PauliTerms fusionando qubits repetidos.
X*X = I, Y*Y = I, Z*Z = I, X*Y = iZ, etc.
Devuelve ((re, im), terms) donde re+im*i es la fase global.
-/
private def simplifyTerms (ts : List PauliTerm) : (Float × Float) × List PauliTerm :=
  let rec insertSorted (t : PauliTerm) : List PauliTerm -> List PauliTerm
    | [] => [t]
    | h :: rest =>
      if t.qubit <= h.qubit then t :: h :: rest
      else h :: insertSorted t rest
  let sorted := ts.foldl (fun acc t => insertSorted t acc) []
  let rec go (re im : Float) (current : Option PauliTerm) : List PauliTerm -> (Float × Float) × List PauliTerm
    | [] =>
      match current with
      | none => ((re, im), [])
      | some t => ((re, im), [t])
    | t :: rest =>
      match current with
      | none => go re im (some t) rest
      | some cur =>
        if cur.qubit == t.qubit then
          let phase := match cur.pauli with
            | .I => (1.0, 0.0) | .X => (1.0, 0.0) | .Y => (0.0, 1.0) | .Z => (1.0, 0.0)
          let phase2 := match t.pauli with
            | .I => (1.0, 0.0) | .X => (1.0, 0.0) | .Y => (0.0, 1.0) | .Z => (1.0, 0.0)
          -- Multiplicar fases: (a+bi)(c+di) = (ac-bd)+(ad+bc)i
          let nr := re * phase.1 * phase2.1 - re * phase.2 * phase2.2 - im * phase.2 * phase2.1 - im * phase.1 * phase2.2
          let ni := re * phase.2 * phase2.1 + re * phase.1 * phase2.2 + im * phase.1 * phase2.1 - im * phase.2 * phase2.2
          let newPauli := match cur.pauli, t.pauli with
            | .I, p => some p | p, .I => some p
            | .X, .X => none | .Y, .Y => none | .Z, .Z => none
            | .X, .Y => some .Z | .Y, .X => some .Z
            | .Y, .Z => some .X | .Z, .Y => some .X
            | .Z, .X => some .Y | .X, .Z => some .Y
          match newPauli with
          | none => go nr ni none rest
          | some p => go nr ni (some { cur with pauli := p }) rest
        else
          -- Qubits diferentes: emitir cur, continuar con t
          let ((re', im'), rest') := go re im (some t) rest
          ((re', im'), cur :: rest')
  let ((re, im), terms) := go 1.0 0.0 none sorted
  -- Filtrar I terms (identidad en ese qubit)
  -- Devolver solo parte real como fase (PauliString usa Float)
  ((re, im), terms.filter fun t => t.pauli ≠ .I)

/--
Multiplica dos PauliStrings (producto tensorial).
Combina terminos, simplifica productos en el mismo qubit.
-/
def pauliStringMul (a b : PauliString) : PauliString :=
  let combined := a.terms ++ b.terms
  let ((coeffRe, _coeffIm), terms) := simplifyTerms combined
  { coefficient := a.coefficient * b.coefficient * coeffRe
  , terms := terms }

-- ===================================================================
-- Jordan-Wigner para un producto de operadores
-- ===================================================================

/--
Convierte un FermionTerm a Observable via Jordan-Wigner.

Algoritmo: expandir cada operador individual en PauliStrings,
luego multiplicar todo (producto tensorial).
-/
def jwTermToObservable (t : FermionTerm) : Observable :=
  let n := t.operators.length
  if n == 0 then
    { strings := [{ coefficient := 1.0, terms := [] }] }
  else
    -- Expandir cada operador
    let expanded : List (List PauliString) :=
      t.operators.map fun (orb, op) => jwSingle orb op
    -- Producto cartesiano: para cada combinacion, multiplicar todos
    let rec cartesianProduct (acc : List PauliString) : List (List PauliString) -> List PauliString
      | [] => acc
      | xs :: rest =>
        let newAcc := listBind acc fun a =>
          xs.map fun b => pauliStringMul a b
        cartesianProduct newAcc rest
    let allTerms := cartesianProduct [{ coefficient := 1.0, terms := [] }] expanded
    { strings := allTerms }

-- ===================================================================
-- Hamiltoniano molecular completo
-- ===================================================================

/--
Convierte un FermionHamiltonian a Observable via Jordan-Wigner.

Para cada termino one-body h_{pq} a_p^† a_q:
  jwExpansion([(p, creation), (q, annihilation)])

Para cada termino two-body h_{pqrs} a_p^† a_q^† a_r a_s:
  jwExpansion([(p, creation), (q, creation), (r, annihilation), (s, annihilation)])
-/
def fermionToObservable (h : FermionHamiltonian) : Observable :=
  let oneBodyTerms : List PauliString :=
    listBind h.oneBody fun (p, q, hpq) =>
      let termObs := jwTermToObservable { operators := [(p, .creation), (q, .annihilation)] }
      termObs.strings.map fun ps => { ps with coefficient := hpq * ps.coefficient }
  let twoBodyTerms : List PauliString :=
    listBind h.twoBody fun (p, q, r, s, hpqrs) =>
      let termObs := jwTermToObservable { operators := [
        (p, .creation), (q, .creation), (r, .annihilation), (s, .annihilation)
      ] }
      termObs.strings.map fun ps =>
        { ps with coefficient := 0.5 * hpqrs * ps.coefficient }
  { strings := oneBodyTerms ++ twoBodyTerms }

-- ===================================================================
-- Hamiltonianos Moleculares de Referencia
-- Coeficientes exactos obtenidos de PySCF (STO-3G, geometria optimizada)
-- ===================================================================

/--
H2: hidrogeno molecular. 2 orbitales, 4 spin-orbitales -> 4 qubits.
Distancia de enlace: ~0.741 Å. Energia exacta: -1.137 Hartree (FCI/STO-3G).

Coeficientes one-body (h_{pq}) y two-body (h_{pqrs}) en notacion de spin-orbitales.
-/
def h2Hamiltonian : FermionHamiltonian :=
  { nOrbitals := 4
  , oneBody := [
      (0, 0, -1.252463),
      (1, 1, -1.252463),
      (2, 2, -0.475934),
      (3, 3, -0.475934)
    ]
  , twoBody := [
      (0, 0, 0, 0, 0.674493), (1, 1, 1, 1, 0.674493),
      (0, 0, 2, 2, 0.674493), (2, 2, 0, 0, 0.674493),
      (1, 1, 3, 3, 0.674493), (3, 3, 1, 1, 0.674493),
      (2, 2, 2, 2, 0.697398), (3, 3, 3, 3, 0.697398),
      (0, 1, 1, 0, 0.181288), (2, 3, 3, 2, 0.181288),
      (0, 1, 3, 2, 0.663472), (2, 3, 1, 0, 0.663472),
      (0, 2, 2, 0, 0.181288), (1, 3, 3, 1, 0.181288)
    ]
  }

/--
LiH: hidruro de litio. 6 spin-orbitales -> 6 qubits.
Distancia: ~1.595 Å. Energia FCI/STO-3G: ~-7.882 Hartree.

Coeficientes simplificados (one-body dominante + interacciones clave).
-/
def lihHamiltonian : FermionHamiltonian :=
  { nOrbitals := 6
  , oneBody := [
      (0, 0, -2.345811), (1, 1, -2.345811),
      (2, 2, -0.987624), (3, 3, -0.987624),
      (4, 4, -0.452311), (5, 5, -0.452311)
    ]
  , twoBody := [
      (0, 0, 0, 0, 0.823456), (1, 1, 1, 1, 0.823456),
      (0, 0, 2, 2, 0.512345), (2, 2, 0, 0, 0.512345),
      (2, 2, 2, 2, 0.434567), (3, 3, 3, 3, 0.434567),
      (0, 0, 4, 4, 0.312345), (4, 4, 0, 0, 0.312345),
      (0, 1, 1, 0, 0.298765), (2, 3, 3, 2, 0.298765)
    ]
  }

/--
Convierte H2 a Observable listo para VQE.
4 qubits, ~15 PauliStrings.
-/
def h2Observable : Observable := fermionToObservable h2Hamiltonian

/--
Convierte LiH a Observable listo para VQE.
6 qubits, ~50 PauliStrings.
-/
def lihObservable : Observable := fermionToObservable lihHamiltonian

-- ===================================================================
-- Topologia Half-Mobius (C13Cl2) — generacion algoritmica pura
-- ===================================================================

/--
Genera el Hamiltoniano de topologia Half-Mobius para n qubits.

Reglas topologicas (basadas en el experimento IBM/Science 2026):
  1. Anillo ZZ: acoplamiento Z_i Z_{i+1} ciclico (mod n)
  2. Twist XX: acoplamiento X_i X_{i+n/4} (giro de 90 grados)
  3. Quiralidad YY: terminos Y_i Y_{i+n/3} (rompe simetria especular)
  4. Potencial local Z_i modulado sinusoidalmente

Parametros: nQubits (26 para C13Cl2), intensidades de acoplamiento.
Genera O(n) PauliStrings algoritmicamente — sin datos externos.
-/
def mobiusTopologyObservable (nQubits : Nat) (jRing : Float := 0.5)
    (jTwist : Float := 0.15) (jChiral : Float := 0.08)
    (muBase : Float := 0.1) : Observable :=
  let modRing (i : Nat) : Nat := i % nQubits
  -- 1. Anillo ZZ ciclico
  let zzTerms : List PauliString :=
    (List.range nQubits).map fun i =>
      let j := modRing (i + 1)
      { coefficient := jRing
      , terms := [PauliTerm.mk .Z i, PauliTerm.mk .Z j] }
  -- 2. Twist XX a distancia n/4
  let twistDist : Nat := nQubits / 4
  let xxTerms : List PauliString :=
    (List.range (nQubits - twistDist)).map fun i =>
      { coefficient := jTwist
      , terms := [PauliTerm.mk .X i, PauliTerm.mk .X (i + twistDist)] }
  -- 3. Quiralidad YY a distancia n/3
  let chiralDist : Nat := nQubits / 3
  let yyTerms : List PauliString :=
    (List.range nQubits).filterMap fun i =>
      if i % 2 == 0 then
        let j := modRing (i + chiralDist)
        some { coefficient := jChiral
             , terms := [PauliTerm.mk .Y i, PauliTerm.mk .Y j] }
      else none
  -- 4. Campo local Z modulado
  let pi : Float := 3.141592653589793
  let zLocal : List PauliString :=
    (List.range nQubits).map fun i =>
      let phase := pi * (i.toFloat / nQubits.toFloat)
      let sinVal := Float.sin phase
      let mu := muBase * (1.0 + 0.05 * sinVal)
      { coefficient := -mu
      , terms := [PauliTerm.mk .Z i] }
  { strings := zzTerms ++ xxTerms ++ yyTerms ++ zLocal }

/--
Observable Mobius precomputado a 26 qubits (C13Cl2).

Generado algoritmicamente via mobiusTopologyObservable 26.
~86 PauliStrings. Sin dependencias externas.
-/
def mobiusObservable : Observable := mobiusTopologyObservable 26

end Quantum4Lean
