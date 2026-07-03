/-
ObservableLoader.lean
Carga dinamica de Observables masivos desde archivo JSON.

Para Hamiltonianos de mas de 1000 PauliStrings (ej. C13Cl2 a 26 qubits),
el compilador de Lean no puede manejar la definicion literal.
Este modulo lee un archivo JSON generado externamente y construye
el Observable en tiempo de ejecucion.

Formato JSON esperado:
  {
    "nQubits": 26,
    "strings": [
      {"coefficient": 0.123, "terms": [{"pauli": "Z", "qubit": 0}, ...]},
      ...
    ]
  }

Las claves "pauli" aceptan: "I", "X", "Y", "Z".
-/

import Quantum4Lean.Quantum4LeanObservable

namespace Quantum4LeanPlayground.Mobius

open Quantum4Lean

/--
Parsea un caracter a Pauli.
-/
def parsePauli (c : Char) : Option Pauli :=
  match c with
  | 'I' => some .I
  | 'X' => some .X
  | 'Y' => some .Y
  | 'Z' => some .Z
  | _ => none

/--
Parsea un JSON simple (sin dependencias externas) a Observable.

Formato: una linea por PauliString:
  coeff P0 Q0 P1 Q1 ...
Ejemplo: "0.5 X 0 Z 1" -> 0.5 * X_0 * Z_1
-/
def parseObservableSimple (lines : List String) : Observable :=
  let strings := lines.filterMap fun line =>
    let trimmed := line.trim
    if trimmed.isEmpty || trimmed.startsWith "#" then none
    else
      let parts := trimmed.splitOn " "
      match parts with
      | coeffStr :: rest =>
        match rest with
        | [] => some { coefficient := coeffStr.toFloat?, terms := [] }
        | _ =>
          let terms := (List.range (rest.length / 2)).filterMap fun i =>
            let pIdx := 2 * i
            let qIdx := 2 * i + 1
            if qIdx < rest.length then
              match parsePauli (rest[pIdx]!.get? 0 |>.getD 'I') with
              | some p =>
                let q := rest[qIdx]!.toNat?
                some (PauliTerm.mk p q)
              | none => none
            else none
          some { coefficient := coeffStr.toFloat?, terms := terms }
      | _ => none
  { strings := strings }

/--
Carga un Observable desde archivo de texto (formato simple).
-/
def loadObservable (filepath : String) : IO Observable := do
  let content <- IO.FS.readFile filepath
  let lines := (content.splitOn "\n").toList
  let obs := parseObservableSimple lines
  IO.println s!"ObservableLoader: {obs.strings.length} PauliStrings cargados desde {filepath}"
  return obs

end Quantum4LeanPlayground.Mobius
