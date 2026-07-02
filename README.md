# Quantum4Lean

Computacion cuantica verificada en Lean 4. Motor puro-Lean bit-exacto con CoreQU4TRIX (C++/Metal). Stack NISQ completo: StateVector, Observables, VQE, QAOA. DSL declarativo, tactica `circuit_equiv` y fuzzer intra-Lean.

Estado: v0.4.0 -- 11 modulos activos, build autocontenido, 208 tests.

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
    +-------+-------+-------+-------+-------+-------+-------+
    |       |       |       |       |       |       |       |
   Core   Error  Engine  Fuzz  Unitary  Obs    VQE    QAOA
                                                    (Ising)
                            |
                    +-------+-------+
                    |               |
              Quantum4LeanDSL  Quantum4LeanTactic
              (circuit\! {})    (circuit_equiv)
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
| VQE | `vqe`, `isingAnsatz`, `gradient`, `parameterShiftGradient` |
| QAOA | `qaoaIsing`, `qaoaIsingCircuit`, `qaoaMixingLayer` |
| Verificacion | `compile`, `circuitsEquiv`, `circuit_equiv` (tactica) |
| DSL | `circuit\! { ... }`, `q[i]`, `H`, `X`, `CNOT`, ... (Shortcuts) |
| Fuzzer | `FuzzConfig`, `FuzzReport`, `runFullSuite`, `reportToString` |

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
|   +-- Quantum4LeanDSL.lean       -- circuito\!, q[i]
|   +-- Quantum4LeanTactic.lean    -- circuit_equiv
|   +-- Quantum4LeanRunner.lean    -- Ejecutable de tests
|   +-- (8 modulos conservados para futuro)
+-- Quantum4LeanBridge/            -- Puente C (opcional)
+-- .github/workflows/ci.yml       -- CI
+-- README.md
```

## Requisitos

- Lean 4 (v4.7.0)
- macOS / Linux / Windows
- Apple Silicon + macOS 13+ (solo para FFI/Metal opcional)
