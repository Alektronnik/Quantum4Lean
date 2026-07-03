# Quantum4Lean

Computacion cuantica verificada en Lean 4. Motor puro-Lean bit-exacto con CoreQU4TRIX (C++/Metal). Stack NISQ completo: StateVector, Observables, VQE, QAOA. DSL declarativo, tactica `circuit_equiv` y fuzzer intra-Lean.

Estado: v0.6.1 -- 15 modulos activos (+7 conservados), 7 playgrounds, 224 tests (208 fuzz + 16 teoremas).

## Build

```bash
cd Quantum4Lean
lake build && ./build/bin/quantum4lean-test
```

Cero dependencias externas. Solo requiere Lean 4 (v4.7.0).

## Arquitectura

```
                    Quantum4Lean.lean (modulo principal)
                            |
    +-------+-------+-------+-------+-------+-------+-------+-------+-------+
    |       |       |       |       |       |       |       |       |       |
   Core   Error  Engine  Fuzz  Unitary  Obs    VQE    QAOA  Diophantine  Polynomial
                                                    (Ising)
    |       |       |       |
   DSL   Tactic   Simp  Transpile  Clifford

Quantum4LeanPlayground/          -- Demostraciones (7 modulos)
+-- QuantumPlaygroundDiophantine  -- Solver diofantino (4 casos)
+-- QuantumPlaygroundFuzz         -- Fuzzer diofantino
+-- QuantumPlaygroundBeal         -- Conjetura de Beal (3 escalas)
+-- QuantumPlaygroundFFI          -- FFI Metal 3 (30 qubits)
+-- QuantumPlaygroundTijdeman     -- Tijdeman QAOA
+-- QuantumPlaygroundRiemann      -- Riemann + Cuantica
+-- QuantumPlaygroundTRDU         -- TRDU-Q
```

## Uso rapido

```lean
import Quantum4Lean
open Quantum4Lean.DSL.Shortcuts

-- Circuito Bell con DSL declarativo
def bell : Circuit 2 := circuit\! {
  H q[0];
  CNOT q[0] q[1]
}

-- Ejecutar en el motor puro-Lean
#eval executeSim bell
-- Except.ok [1, 1]

-- Verificar equivalencia semantica
#eval circuitsEquiv bell bell
-- true

-- Usar la tactica (n <= 3, sin puertas H)
example : circuitsEquiv
  (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
  (Circuit.identity 2) := by
  circuit_equiv
```

## API

| Categoria | Simbolos |
|-----------|----------|
| Tipos | `Qubit`, `Gate`, `Circuit`, `StateVector`, `Complex`, `UnitaryMatrix` |
| Pauli | `Pauli`, `PauliString`, `Observable` |
| Ejecucion | `executeSim`, `executeSimProbs` |
| Expectacion | `expect`, `expectPauliString`, `expectZ`, `expectX`, `expectY` |
| VQE | `vqe`, `adamVQE`, `isingAnsatz`, `gradient`, `parameterShiftGradient` |
| QAOA | `qaoaIsing`, `qaoaIsingCircuit`, `qaoaMixingLayer` |
| Verificacion | `compile`, `circuitsEquiv`, `circuit_equiv` (tactica) |
| Clifford | `cliffordEquiv`, `CliffordAmplitude`, `CliffordMatrix` |
| Optimizacion | `simplifyCircuit`, `optimizeCircuit`, `verifyOptimization` |
| DSL | `circuit\! { ... }`, `q[i]`, `H`, `X`, `CNOT`, ... (Shortcuts) |
| Fuzzer | `FuzzConfig`, `FuzzReport`, `runFullSuite`, `reportToString` |
| Diofantico | `Diophantine`, `toIsing`, `diophantineSolve`, `checkSolution` |
| Polinomico | `Monomial`, `PolyEquation`, `polyToIsing`, `expandVarPower` |

## DSL

```lean
-- Con nombres completos (siempre disponible)
def bell : Circuit 2 := circuit\! {
  Gate.H q[0];
  Gate.CNOT q[0] q[1]
}

-- Con alias cortos (requiere `open Quantum4Lean.DSL.Shortcuts`)
def ghz3 : Circuit 3 := circuit\! {
  H q[0];
  CNOT q[0] q[1];
  CNOT q[1] q[2]
}
```

## Tactica circuit_equiv

```lean
-- Funciona con native_decide para circuitos sin H (Pauli, CNOT, CZ, SWAP)
example : circuitsEquiv
  (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
  (Circuit.identity 2) := by
  circuit_equiv

-- Para circuitos con H, usar #eval
#eval circuitsEquiv
  (circuit fun c => (c.add (Gate.H q[0])).add (Gate.H q[0]))
  (Circuit.identity 2)
```

## Verificacion Clifford (Z[i])

Demostracion formal de equivalencias para las 7 puertas Clifford (X, Y, Z, S, CNOT, CZ, SWAP) usando aritmetica entera en Z[i]. Sin Float, sin √2. 8 teoremas demostrados con `native_decide`.

```lean
-- Demostrado formalmente (0 sorry)
theorem rule_X_X_eq_I : cliffordEquiv c (Circuit.identity 2) := by
  native_decide

-- Verificacion runtime para cualquier circuito Clifford
#eval cliffordEquiv miCircuito otroCircuito
```

## Traductor Diofantino

Ecuaciones diofantinas lineales (ax + by = c) a Hamiltonianos de Ising.

```lean
import Quantum4Lean

let eq : Diophantine := {
  vars := [
    { coeff := 3, name := "x", bits := 4 },
    { coeff := 5, name := "y", bits := 4 }
  ],
  constant := 22
}

let H := toIsing eq 4
let result := diophantineSolve eq 4
#eval checkSolution eq [("x", 4), ("y", 2)]  -- true (3*4 + 5*2 = 22)
```

## Traductor Polinomico

Generaliza el traductor lineal a monomios con exponentes <= 3.
Soporta ecuaciones como x^2 = y^3 + 1 (Tijdeman).

```lean
import Quantum4Lean

-- Ecuacion: x^2 - y^3 = 1
let eq : PolyEquation := {
  monomials := [
    { coefficient := 1,  exponents := [(0, 2)] },
    { coefficient := -1, exponents := [(1, 3)] }
  ],
  constant := 1,
  varBits := [4, 4]
}

let H := polyToIsing eq    -- Observable Ising
let n := polyTotalQubits eq -- 8 qubits
```

## Playground

Demostraciones avanzadas que extienden la libreria. Import independiente.

### Solver Diofantino (QuantumPlaygroundDiophantine)

4 casos con busqueda exhaustiva via polyToIsing:

```lean
import Quantum4LeanPlayground
#eval Quantum4LeanPlayground.Diophantine.report
```

Casos: Tijdeman, Pillai n=2, Pillai n=3, Pitagoras.

### Conjetura de Beal (QuantumPlaygroundBeal)

Busqueda masiva de contraejemplos en 3 escalas (9, 12, 19 qubits):

```lean
#eval Quantum4LeanPlayground.Beal.report
```

### FFI Apple Silicon (QuantumPlaygroundFFI)

Motor C++/Metal hasta 30 qubits. Requiere `bash build_ffi.sh`.

```lean
#eval Quantum4LeanPlayground.FFI.report
```

### Fuzzer Diofantino (QuantumPlaygroundFuzz)

Genera ecuaciones aleatorias con soluciones conocidas y verifica:

```lean
#eval Quantum4LeanPlayground.Fuzz.report
```

### ADAM Optimizer

VQE con optimizador ADAM (momentum + learning rate adaptativo).

```lean
let (energy, params, history) := adamVQE ansatz H initialParams 0.01 200
```

### Tijdeman Cuantico

```lean
#eval Quantum4LeanPlayground.Tijdeman.report
-- x^2 = y^3 + 1 via QAOA. Validado contra demostracion formal.
```

## Fuzzer

```lean
#eval runFullSuite { maxQubits := 5, numCircuits := 200 }
#eval reportToString (runFullSuite { numCircuits := 100 })
```

## Bit-exactness con CoreQU4TRIX

| Algoritmo | Fuente C++ | Implementacion Lean |
|-----------|-----------|-------------------|
| Unitario 1q | `aplicar_unitaria_cpu` | `applyUnitaryInPlace` |
| CNOT | `aplicar_cnot_cpu` | `applyCNOTInPlace` |
| CZ | `aplicar_cz_cpu` | `applyCZInPlace` |
| SWAP | `aplicar_swap_cpu` | `applySWAPInPlace` |
| Medicion | `medir_y_colapsar_cpu` | `measure` |
| LCG | `6364136223846793005` | `lcgNext` |

## Estructura

```
Quantum4Lean/
+-- lakefile.lean
+-- Quantum4Lean.lean              -- Modulo principal
+-- Quantum4Lean/
|   +-- Quantum4LeanCore.lean      -- Qubit, Gate, Circuit
|   +-- Quantum4LeanError.lean     -- QuantumError
|   +-- Quantum4LeanEngine.lean    -- StateVector, simulador
|   +-- Quantum4LeanFuzz.lean      -- Fuzzer intra-Lean
|   +-- Quantum4LeanUnitary.lean   -- Complex, UnitaryMatrix
|   +-- Quantum4LeanObservable.lean-- PauliString, expect
|   +-- Quantum4LeanVQE.lean       -- Parameter-shift, VQE
|   +-- Quantum4LeanQAOA.lean      -- Mixing layer, Ising
|   +-- Quantum4LeanDSL.lean       -- circuito!, q[i]
|   +-- Quantum4LeanTactic.lean    -- circuit_equiv, quantum_simp
|   +-- Quantum4LeanSimp.lean      -- Simplificador (12 reglas)
|   +-- Quantum4LeanTranspile.lean -- Transpilador (8 teoremas)
|   +-- Quantum4LeanClifford.lean  -- Verificacion Clifford (Z[i])
|   +-- Quantum4LeanDiophantine.lean-- Traductor diofantino lineal
|   +-- Quantum4LeanPolynomial.lean -- Traductor polinomico
|   +-- Quantum4LeanFFI.lean        -- Bindings @[extern]
|   +-- Quantum4LeanRunner.lean    -- Ejecutable de tests
|   +-- (6 modulos conservados)    -- Compile, Examples, Monad, Sim, Test, Verify
+-- Quantum4LeanPlayground.lean    -- Root del Playground
+-- Quantum4LeanPlayground/
|   +-- QuantumPlaygroundDiophantine.lean
|   +-- QuantumPlaygroundFuzz.lean
|   +-- QuantumPlaygroundBeal.lean
|   +-- QuantumPlaygroundFFI.lean
|   +-- QuantumPlaygroundTijdeman.lean
|   +-- QuantumPlaygroundRiemann.lean
|   +-- QuantumPlaygroundTRDU.lean
+-- Quantum4LeanBridge/            -- Puente C (FFI)
|   +-- Quantum4LeanFFI.h / .c
+-- build_ffi.sh                   -- Compila lib FFI
+-- .github/workflows/ci.yml       -- CI
+-- README.md
+-- MANUAL.md
```

## Requisitos

- Lean 4 (v4.7.0)
- macOS / Linux / Windows
- Apple Silicon + macOS 13+ (solo para FFI/Metal opcional)
