/-
Quantum4LeanQASM.lean
Generador OpenQASM 3.0: Circuit n -> .qasm

Cada circuito verificado en Lean se puede exportar a OpenQASM 3.0
para ejecucion en hardware real (IBM Quantum, AWS Braket).

Todas las 13 puertas del catalogo tienen equivalencia directa:
  H -> h, X -> x, Y -> y, Z -> z, S -> s, T -> t,
  CNOT -> cx, CZ -> cz, SWAP -> swap,
  RX(theta) -> rx(theta), RY(theta) -> ry(theta), RZ(theta) -> rz(theta),
  Unitary -> gate custom { matrix { ... } }

Compatibilidad: OpenQASM 3.0 (https://openqasm.com/).
-/

import Quantum4Lean.Quantum4LeanCore

namespace Quantum4Lean.QASM

open Quantum4Lean

/--
Genera la declaracion de una puerta unitaria personalizada en OpenQASM 3.0.
Formato: gate unitary_N(a) { matrix { ... } a; }
-/
private def unitaryGateDecl (name : String) (matrix : Array Float) : String :=
  if matrix.size == 8 then
    "gate " ++ name ++ "(a) {\n" ++
    "    matrix {\n" ++
    "      " ++ toString (matrix[0]!) ++ ", " ++ toString (matrix[1]!) ++ ", " ++
                toString (matrix[2]!) ++ ", " ++ toString (matrix[3]!) ++ "\n" ++
    "      " ++ toString (matrix[4]!) ++ ", " ++ toString (matrix[5]!) ++ ", " ++
                toString (matrix[6]!) ++ ", " ++ toString (matrix[7]!) ++ "\n" ++
    "    }\n" ++
    "    a;\n" ++
    "  }"
  else
    "// WARNING: Gate.Unitary con " ++ toString matrix.size ++ " floats, esperado 8;"

/--
Convierte una puerta a su representacion OpenQASM 3.0.
Devuelve (linea_qasm, maybe_declaracion_gate).
-/
def gateToQASM {n : Nat} (g : Gate n) (unitaryIdx : Nat) : String × Option String :=
  let qStr (q : Qubit n) : String := s!"q[{q.idx.val}]"
  match g with
  | .H q    => (s!"h {qStr q};", none)
  | .X q    => (s!"x {qStr q};", none)
  | .Y q    => (s!"y {qStr q};", none)
  | .Z q    => (s!"z {qStr q};", none)
  | .S q    => (s!"s {qStr q};", none)
  | .T q    => (s!"t {qStr q};", none)
  | .CNOT c t => (s!"cx {qStr c}, {qStr t};", none)
  | .CZ c t   => (s!"cz {qStr c}, {qStr t};", none)
  | .SWAP a b => (s!"swap {qStr a}, {qStr b};", none)
  | .RX q theta => (s!"rx({theta}) {qStr q};", none)
  | .RY q theta => (s!"ry({theta}) {qStr q};", none)
  | .RZ q theta => (s!"rz({theta}) {qStr q};", none)
  | .Unitary q matrix =>
    let name := s!"unitary_{unitaryIdx}"
    if matrix.size == 8 then
      (s!"{name} {qStr q};", some (unitaryGateDecl name matrix))
    else
      (s!"// WARNING: Gate.Unitary invalida en {qStr q}: {matrix.size} floats, esperado 8;", none)

/--
Convierte un circuito a una cadena OpenQASM 3.0.

El resultado incluye:
  - Cabecera OPENQASM 3.0;
  - Declaraciones `gate` para cada puerta Unitary personalizada
  - Declaracion de qubits: qubit[n] q;
  - Cada puerta traducida
-/
def circuitToQASM {n : Nat} (c : Circuit n) (name : String := "circuit") : String :=
  let header := "// OpenQASM 3.0 generado por Quantum4Lean v0.8.0\n// Circuito: " ++ name ++ "\n// " ++ toString c.gates.length ++ " puertas, " ++ toString n ++ " qubits\nOPENQASM 3.0;\ninclude \"stdgates.inc\";\n"
  -- Recolectar lineas y declaraciones, asignando indices a Unitaries
  let rec process (gs : List (Gate n)) (idx : Nat) (lines decls : List String) : Nat × List String × List String :=
    match gs with
    | [] => (idx, lines.reverse, decls.reverse)
    | g :: rest =>
      let (line, maybeDecl) := gateToQASM g idx
      let newLines := ("  " ++ line) :: lines
      match maybeDecl with
      | some decl => process rest (idx + 1) newLines (decl :: decls)
      | none => process rest idx newLines decls
  let (_, gateLines, gateDecls) := process c.gates 0 [] []
  let declSection := if gateDecls.isEmpty then "" else
    String.intercalate "\n" gateDecls ++ "\n"
  let qubitDecl := "qubit[" ++ toString n ++ "] q;\n"
  let body := String.intercalate "\n" gateLines
  header ++ declSection ++ qubitDecl ++ body ++ "\n"

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
