# Quantum4Lean

Computacion cuantica verificada en Lean 4. Motor puro-Lean bit-exacto con CoreQU4TRIX (C++/Metal), fuzzer intra-Lean, y puente FFI opcional a Apple Silicon.

Estado: v0.3 -- build autocontenido, 5 modulos activos, fuzzer integrado.

## Build

```bash
cd Quantum4Lean
lake build
```

Cero dependencias externas. Solo requiere Lean 4 (v4.7.0). Sin mathlib4, sin binario C++.

## Arquitectura

```
                          Quantum4Lean.lean (modulo principal)
                                  |
          +-----------------------+-----------------------+
          |                       |                       |
   Quantum4LeanCore        Quantum4LeanError      Quantum4LeanEngine
   (Qubit, Gate,           (QuantumError          (StateVector,
    Circuit)                 inductivo)             simulador bit-exacto)
          |                       |                       |
          +-----------------------+-----------------------+
                                  |
                          Quantum4LeanFuzz
                          (Tests algebraicos + aleatorios)

Modulos opcionales (no importados por defecto):
   Quantum4LeanFFI         Bindings @[extern] al motor C
   Quantum4LeanSim         Runner FFI (token, state vector manual)
   Quantum4LeanMonad       Monada cuantica sobre FFI
   Quantum4LeanCompile     Circuit -> QuantumM
   Quantum4LeanObservable  PauliString, expect
   Quantum4LeanVQE         VQE con parameter-shift
   Quantum4LeanQAOA        QAOA con Ising
   Quantum4LeanUnitary     Matrices unitarias, circuitsEquiv
   Quantum4LeanDSL         Macro circuit\! { H q[0]; ... }
   Quantum4LeanVerify      Identidades algebraicas H*H=I
   Quantum4LeanExamples    Bell, GHZ, Grover, QFT
   Quantum4LeanTest        55 aserciones (Complex, UnitaryMatrix)
```

## Dos motores de ejecucion

### Motor 1: Quantum4LeanEngine (puro Lean, siempre disponible)

Simulador de state vector bit-exacto con el motor C++ CoreQU4TRIX. Algoritmos, matrices, LCG y umbrales identicos.

| Parametro | Valor |
|-----------|-------|
| Qubits maximos | 10 (2048 complejos) |
| Precision | IEEE 754 binary64 (Float) |
| LCG | seed*6364136223846793005 + 1442695040888963407 |
| Umbral colapso | 1e-15 |
| Puertas | H, X, Y, Z, S, T, CNOT, CZ, SWAP, RX, RY, RZ, Unitaria |

```lean
import Quantum4Lean

-- Circuito Bell con tipos dependientes
def bellCircuit : Circuit 2 :=
  let q0 : Qubit 2 := <<0, by decide>>
  let q1 : Qubit 2 := <<1, by decide>>
  { gates := [Gate.H q0, Gate.CNOT q0 q1] }

-- Ejecutar en el motor puro-Lean
#eval executeSim bellCircuit
-- Except.ok [1, 1]  (estado |11>)

-- Obtener probabilidades
#eval executeSimProbs bellCircuit
-- Except.ok #[0.5, 0.0, 0.0, 0.5]  (|00> y |11> con 50% cada uno)
```

### Motor 2: FFI a CoreQU4TRIX (opcional, requiere binario C++)

Para N > 10 qubits o ejecucion en GPU Metal 3. Hasta 30 qubits (~17 GB RAM Unificada).

```bash
lake build -K enableFFI=true
```

## Fuzzer intra-Lean

Suite de verificacion que valida el Engine contra propiedades algebraicas. 0% FFI, 0% dependencias externas.

```lean
import Quantum4Lean

-- Suite completa (identidades + Bell + GHZ + Pauli + aleatorios)
#eval runFullSuite { maxQubits := 5, numCircuits := 100 }

-- Reporte legible
#eval reportToString (runFullSuite { numCircuits := 50 })
```

### Categorias de test

| Categoria | Que verifica | Metodo |
|-----------|-------------|--------|
| Identidades | H*H=I, X*X=I, Y*Y=I, Z*Z=I | Amplitud en estado 0 = 1+0i |
| Identidades 2q | CNOT*CNOT=I, CZ*CZ=I, SWAP*SWAP=I | Amplitud en estado inicial |
| Periodicas | S^4=I, T^8=I | 4 y 8 aplicaciones consecutivas |
| Pauli | XZ vs ZX (diferencia de signo) | XZ|0>=|1>, ZX|0>=-|1> |
| Bell | (|00>+|11>)/sqrt(2) | 4 amplitudes exactas |
| GHZ | (|000>+|111>)/sqrt(2) | 2 amplitudes exactas |
| Aleatorios | N circuitos pseudoaleatorios | Normalizacion, determinismo, reversibilidad |

## Bit-exactness con CoreQU4TRIX

El Engine replica los algoritmos del motor C++ linea por linea:

| Algoritmo | Fuente C++ | Implementacion Lean |
|-----------|-----------|-------------------|
| Unitario 1q | `aplicar_unitaria_cpu` (linea 365) | `applyUnitaryInPlace` |
| CNOT | `aplicar_cnot_cpu` (linea 400) | `applyCNOTInPlace` |
| CZ | `aplicar_cz_cpu` (linea 420) | `applyCZInPlace` |
| SWAP | `aplicar_swap_cpu` (linea 440) | `applySWAPInPlace` |
| Medicion | `medir_y_colapsar_cpu` (linea 465) | `measure` |
| LCG | `6364136223846793005` | `lcgNext` |
| Matrices | `GATE_X`, `GATE_H`, `obtener_matriz_puerta` | `GATE_X`, `GATE_H`, `gateRX` |

## API de StateVector

```lean
-- Inicializar |0...0> en N qubits
let sv <- StateVector.init 3

-- Aplicar circuito
let sv := StateVector.runCircuit sv miCircuito

-- Medir un qubit (colapsa el estado)
let (bit, sv) := StateVector.measure sv 0

-- Medir todos los qubits
let (bits, sv) := StateVector.measureAll sv

-- Probabilidades
let probs := StateVector.probabilities sv

-- Amplitud de un estado base
let (re, im) := StateVector.amplitude sv 5

-- Probabilidad de un estado base
let p := StateVector.prob sv 0

-- Ejecutar circuito completo con medicion
let resultado := StateVector.run miCircuito 123456789 1
```

## Estructura del proyecto

```
Quantum4Lean/
+-- lakefile.lean
+-- lean-toolchain
+-- Quantum4Lean.lean              -- Modulo principal
+-- Quantum4Lean/
|   +-- Quantum4LeanCore.lean      -- Qubit, Gate, Circuit
|   +-- Quantum4LeanError.lean     -- QuantumError inductivo
|   +-- Quantum4LeanEngine.lean    -- Motor puro-Lean bit-exacto
|   +-- Quantum4LeanFuzz.lean      -- Fuzzer intra-Lean
|   +-- Quantum4LeanFFI.lean       -- [opc] Bindings @[extern] C
|   +-- Quantum4LeanSim.lean       -- [opc] Runner FFI
|   +-- Quantum4LeanMonad.lean     -- [opc] Monada cuantica
|   +-- Quantum4LeanCompile.lean   -- [opc] Circuit -> QuantumM
|   +-- Quantum4LeanObservable.lean-- [opc] Observables
|   +-- Quantum4LeanVQE.lean       -- [opc] VQE
|   +-- Quantum4LeanQAOA.lean      -- [opc] QAOA
|   +-- Quantum4LeanUnitary.lean   -- [opc] Matrices unitarias
|   +-- Quantum4LeanDSL.lean       -- [opc] Macro circuit\!
|   +-- Quantum4LeanVerify.lean    -- [opc] Identidades algebraicas
|   +-- Quantum4LeanExamples.lean  -- [opc] Bell, GHZ, Grover, QFT
|   +-- Quantum4LeanTest.lean      -- [opc] 55 aserciones
+-- Quantum4LeanBridge/            -- Puente C (solo con enableFFI)
|   +-- Quantum4LeanBridge.h
|   +-- Quantum4LeanBridge.c
+-- concepto.md                    -- Analisis del ecosistema Lean 4
+-- README.md
```

## Requisitos

- Lean 4 (v4.7.0)
- macOS / Linux / Windows (motor puro-Lean)
- Apple Silicon + macOS 13+ (solo para FFI/Metal opcional)

## Sinergia con QuantumKit

| Dimension | QuantumKit (Swift) | Quantum4Lean (Lean 4) |
|-----------|-------------------|----------------------|
| Ejecucion | C++/Metal, hasta 30 qubits | Puro-Lean, hasta 10 qubits |
| Verificacion | Tests unitarios | Fuzzer + tipos dependientes |
| Backends | 8 (Metal, CPU, ruido, pulsos) | 1 (Engine) + 1 opcional (FFI) |
| Publico | Desarrolladores Apple | Matematicos / Investigadores |
| Memoria | ARC (ObjC) / UMA | Array Float inmutable |
| Build | SPM / Xcode | Lake (autocontenido) |
