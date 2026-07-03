/-
Quantum4LeanQASM.lean
Generador OpenQASM 3.0: Circuit n -> .qasm

Cada circuito verificado en Lean se puede exportar a OpenQASM 3.0
para ejecucion en hardware real (IBM Quantum, AWS Braket).

Todas las 13 puertas del catalogo tienen equivalencia directa:
  H -> h, X -> x, Y -> y, Z -> z, S -> s, T -> t,
  CNOT -> cx, CZ -> cz, SWAP -> swap,
  RX(theta) -> rx(theta), RY(theta) -> ry(theta), RZ(theta) -> rz(theta),
  Unitary -> // no soportado en QASM base

Compatibilidad: OpenQASM 3.0 (https://openqasm.com/).
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean.QASM

open Quantum4Lean

/--
Convierte una puerta a su representacion OpenQASM 3.0.
Devuelve none para puertas no soportadas (Unitary).
-/
def gateToQASM {n : Nat} (g : Gate n) : Option String :=
  let qStr (q : Qubit n) : String := s!"q[{q.idx.val}]"
  match g with
  | .H q    => some s!"h {qStr q};"
  | .X q    => some s!"x {qStr q};"
  | .Y q    => some s!"y {qStr q};"
  | .Z q    => some s!"z {qStr q};"
  | .S q    => some s!"s {qStr q};"
  | .T q    => some s!"t {qStr q};"
  | .CNOT c t => some s!"cx {qStr c}, {qStr t};"
  | .CZ c t   => some s!"cz {qStr c}, {qStr t};"
  | .SWAP a b => some s!"swap {qStr a}, {qStr b};"
  | .RX q theta => some s!"rx({theta}) {qStr q};"
  | .RY q theta => some s!"ry({theta}) {qStr q};"
  | .RZ q theta => some s!"rz({theta}) {qStr q};"
  | .Unitary _ _ => none

/--
Convierte un circuito a una cadena OpenQASM 3.0.

El resultado incluye:
  - Cabecera OPENQASM 3.0;
  - Declaracion de qubits: qubit[n] q;
  - Cada puerta traducida
  - Puertas Unitary generan comentario // WARNING

Si todas las puertas son soportadas, el circuito es ejecutable
directamente en hardware cuantico real.
-/
def circuitToQASM {n : Nat} (c : Circuit n) (name : String := "circuit") : String :=
  let header := s!"// OpenQASM 3.0 generado por Quantum4Lean v0.7.0\n// Circuito: {name}\n// {c.gates.length} puertas, {n} qubits\nOPENQASM 3.0;\ninclude \"stdgates.inc\";\nqubit[{n}] q;\n"
  let gateLines := c.gates.map fun g =>
    match gateToQASM g with
    | some line => s!"  {line}"
    | none => s!"  // WARNING: Gate.Unitary no soportada en QASM 3.0 base"
  let body := String.intercalate "\n" gateLines
  header ++ body ++ "\n"

/--
Exporta un circuito a archivo .qasm.
-/
def exportCircuit {n : Nat} (c : Circuit n) (filepath : String) (name : String := "circuit") : IO Unit := do
  let qasm := circuitToQASM c name
  IO.FS.writeFile filepath qasm

/--
Version corta para #eval: imprime el QASM a stdout.
-/
def printCircuit {n : Nat} (c : Circuit n) (name : String := "circuit") : IO Unit :=
  IO.println (circuitToQASM c name)

end Quantum4Lean.QASM
