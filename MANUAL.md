# Quantum4Lean -- Manual de Usuario

v0.6.1. Julio 2026.

## Indice

1. [Introduccion](#1-introduccion)
2. [Instalacion](#2-instalacion)
3. [Primeros Pasos](#3-primeros-pasos)
4. [Conceptos Fundamentales](#4-conceptos-fundamentales)
5. [Motores de Ejecucion](#5-motores-de-ejecucion)
6. [DSL Declarativo](#6-dsl-declarativo)
7. [Observables y Valores Esperados](#7-observables-y-valores-esperados)
8. [VQE: Optimizacion Variacional](#8-vqe-optimizacion-variacional)
9. [QAOA: Algoritmo de Optimizacion Aproximada](#9-qaoa-algoritmo-de-optimizacion-aproximada)
10. [Verificacion Semantica](#10-verificacion-semantica)
11. [Simplificador y Transpilador](#11-simplificador-y-transpilador)
12. [Fuzzer Intra-Lean](#12-fuzzer-intra-lean)
13. [Traductor Diofantino](#13-traductor-diofantino)
14. [Traductor Polinomico](#14-traductor-polinomico)
15. [ADAM Optimizer](#15-adam-optimizer)
16. [Playground](#16-playground)
17. [API de Referencia](#17-api-de-referencia)
18. [Arquitectura del Proyecto](#18-arquitectura-del-proyecto)

---

## 1. Introduccion

Quantum4Lean es una plataforma de computacion cuantica verificada en Lean 4. Proporciona:

- **Motor de simulacion puro-Lean** bit-exacto con CoreQU4TRIX (C++/Metal)
- **Stack NISQ completo**: StateVector, Observables, VQE, QAOA
- **Traductor diofantino**: ecuaciones lineales a Hamiltonianos Ising
- **Traductor polinomico**: monomios con exponentes <= 3 (Tijdeman, Pillai, Beal)
- **ADAM Optimizer**: VQE con momentum y learning rate adaptativo
- **Verificacion formal**: matrices unitarias, equivalencia semantica, tacticas
- **Simplificador simbolico**: reescritura de circuitos sobre el AST (N arbitrario)
- **Transpilador verificado**: optimizacion con preservacion de semantica
- **Fuzzer intra-Lean**: tests algebraicos + aleatorios
- **DSL declarativo**: `circuit! { H q[0]; CNOT q[0] q[1] }`
- **Cero dependencias externas**: `lake build` autocontenido

### Filosofia

Quantum4Lean sigue tres principios:

1. **Tipos dependientes para seguridad**. Un circuito que referencia `q[5]` en un sistema de 3 qubits es rechazado en compilacion. No en ejecucion. En compilacion.

2. **Pureza funcional**. Toda transformacion de estado es una funcion pura que devuelve un nuevo `StateVector`. Sin efectos secundarios, sin memoria mutable.

3. **Verificacion sobre confianza**. Cada circuito puede verificarse contra su matriz unitaria. Cada optimizacion preserva la semantica. El fuzzer valida miles de circuitos aleatorios.

---

## 2. Instalacion

### Requisitos

- Lean 4 v4.7.0
- macOS, Linux, o Windows

### Instalacion de Lean 4

```bash
curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain leanprover/lean4:4.7.0
export PATH="$HOME/.elan/bin:$PATH"
```

### Build de Quantum4Lean

```bash
git clone https://github.com/TU_USUARIO/Quantum4Lean.git
cd Quantum4Lean
lake build
```

Cero dependencias externas. Sin mathlib4, sin binarios C++.

### Verificar instalacion

```bash
./build/bin/quantum4lean-test
```

Salida esperada:

```
=== Unitary Matrix Tests ===
  OK: 8/8 identidades verificadas

=== Fuzz Tests ===
FUZZ: 0 fallos
  ...

TODOS LOS TESTS OK - Quantum4Lean v0.4.0
```

---

## 3. Primeros Pasos

### Importar Quantum4Lean

```lean
import Quantum4Lean
```

Esto proporciona acceso a todos los tipos y funciones publicas.

### Crear un circuito

```lean
-- Sin DSL (tipos explicitos)
def bellCircuit : Circuit 2 :=
  let q0 : Qubit 2 := ⟨⟨0, by decide⟩⟩
  let q1 : Qubit 2 := ⟨⟨1, by decide⟩⟩
  circuit fun c => (c.add (Gate.H q0)).add (Gate.CNOT q0 q1)

-- Con DSL
open Quantum4Lean.DSL.Shortcuts

def bell : Circuit 2 := circuit! {
  H q[0];
  CNOT q[0] q[1]
}
```

### Ejecutar un circuito

```lean
#eval executeSim bell
-- Except.ok [1, 1]
```

El resultado `[1, 1]` indica que ambos qubits colapsaron a `|1>`. El estado Bell produce `|00>` o `|11>` con igual probabilidad.

### Verificar equivalencia

```lean
#eval circuitsEquiv bellCircuit bell
-- true
```

Ambos circuitos (con tipos explicitos y con DSL) son semanticamente identicos.

---

## 4. Conceptos Fundamentales

### Qubit

```lean
structure Qubit (n : Nat) where
  idx : Fin n
```

Un `Qubit n` es un indice valido en un registro de `n` qubits. `Fin n` garantiza `0 <= idx < n`.

```lean
-- Crear un qubit
let q0 : Qubit 3 := ⟨⟨0, by decide⟩⟩  -- indice 0 en registro de 3
let q1 : Qubit 3 := ⟨⟨1, by decide⟩⟩  -- indice 1
let q2 : Qubit 3 := ⟨⟨2, by decide⟩⟩  -- indice 2

-- Con azucar sintactico
let q0 : Qubit 3 := q[0]
```

### Gate

```lean
inductive Gate (n : Nat) : Type where
  | H    (q : Qubit n)
  | X    (q : Qubit n)
  | Y    (q : Qubit n)
  | Z    (q : Qubit n)
  | S    (q : Qubit n)
  | T    (q : Qubit n)
  | CNOT (control target : Qubit n)
  | CZ   (control target : Qubit n)
  | SWAP (a b : Qubit n)
  | RX (q : Qubit n) (theta : Float)
  | RY (q : Qubit n) (theta : Float)
  | RZ (q : Qubit n) (theta : Float)
  | Unitary (q : Qubit n) (matrix : Array Float)
```

13 constructores cubriendo puertas Clifford, rotaciones parametricas, y unitarias arbitrarias.

### Circuit

```lean
structure Circuit (n : Nat) where
  gates : List (Gate n)
```

Un circuito es una secuencia ordenada de puertas. La composicion es secuencial: `c1.comp c2` aplica `c1` y luego `c2`.

```lean
-- Construir circuito con el builder
def myCircuit : Circuit 3 :=
  circuit fun c =>
    c.add (Gate.H (q[0]))
    |>.add (Gate.CNOT (q[0]) (q[1]))
    |>.add (Gate.X (q[2]))

-- Componentes
let c := Circuit.identity 3       -- circuito vacio
let c := c.add (Gate.H q[0])     -- anadir puerta
let c := c.comp otroCircuito      -- componer
let c := c.repeat 5               -- repetir 5 veces
c.gates                           -- lista de puertas
c.depth                           -- profundidad
```

---

## 5. Motores de Ejecucion

### Motor Puro-Lean (Engine)

Simulador de state vector bit-exacto con el motor C++ CoreQU4TRIX. Hasta 10 qubits.

```lean
-- Ejecutar y obtener bits de medicion
let resultado := executeSim miCircuito 123456789
-- Except.ok [1, 0, 1]  (bits medidos)

-- Ejecutar y obtener probabilidades
let probs := executeSimProbs miCircuito 123456789
-- Except.ok #[0.25, 0.0, 0.25, 0.0, ...]
```

### API de StateVector

```lean
-- Inicializar |0...0>
let sv <- StateVector.init 3

-- Aplicar circuito
let sv := StateVector.runCircuit sv miCircuito

-- Medir un qubit (colapsa el estado)
let (bit, sv) := StateVector.measure sv 0

-- Medir todos los qubits
let (bits, sv) := StateVector.measureAll sv

-- Probabilidades P(|i>) para cada estado base
let probs := StateVector.probabilities sv

-- Amplitud compleja del estado |i>
let (re, im) := StateVector.amplitude sv 5

-- Probabilidad del estado |i>
let p := StateVector.prob sv 0

-- Ejecutar circuito con medicion
let resultado := StateVector.run miCircuito 123456789 1
```

### Motor FFI (opcional)

Para N > 10 qubits o GPU Metal 3. Hasta 30 qubits en Apple Silicon.

```bash
# Requisito previo: compilar QuantumKitCore (proyecto hermano)
cd ../QuantumKit && swift build
cd ../Quantum4Lean && lake build -K enableFFI=true
```

El linker busca `libQuantumKitCore.a` en los paths de build de QuantumKit. Si el binario no se encuentra, el build FFI fallara con errores de simbolos indefinidos. El motor puro-Lean (Engine) funciona sin este paso.

---

## 6. DSL Declarativo

### Sintaxis basica

```lean
open Quantum4Lean.DSL.Shortcuts

-- q[i] crea un Qubit n (n inferido del contexto)
def bell : Circuit 2 := circuit! {
  H q[0];
  CNOT q[0] q[1]
}

-- Puertas disponibles: H, X, Y, Z, S, T, CNOT, CZ, SWAP, RX, RY, RZ
def complexCircuit : Circuit 3 := circuit! {
  H q[0];
  CNOT q[0] q[1];
  RX q[2] (1.57);
  SWAP q[0] q[2]
}
```

### Sin Shortcuts

Si no se usa `open Quantum4Lean.DSL.Shortcuts`, usar `Gate.` prefix:

```lean
def bell : Circuit 2 := circuit! {
  Gate.H q[0];
  Gate.CNOT q[0] q[1]
}
```

---

## 7. Observables y Valores Esperados

### Tipos

```lean
inductive Pauli : Type where
  | I | X | Y | Z

structure PauliString where
  coefficient : Float
  terms       : List PauliTerm

structure Observable where
  strings : List PauliString
```

### Hamiltonianos comunes

```lean
-- Ising 1D: H = -J Σ Z_i Z_{i+1} - h Σ X_i
let H := Observable.ising1D 4 1.0 0.5

-- Heisenberg 1D: H = J Σ (X_i X_{i+1} + Y_i Y_{i+1} + Z_i Z_{i+1})
let H := Observable.heisenberg1D 4 1.0

-- Observable personalizado
let H := Observable.pauli .Z 0 0.5         -- 0.5 * Z_0
let H := H.add (Observable.pauli .X 1 0.3)  -- + 0.3 * X_1
```

### Valores esperados

```lean
-- <H> sobre un StateVector
let sv : StateVector := ...
let energia := expect sv H

-- <Z_0>
let z0 := expectZ sv 0

-- <X_1>
let x1 := expectX sv 1

-- PauliString arbitraria
let val := expectString sv 1.0 [(.X, 0), (.Z, 1)]
```

---

## 8. VQE: Optimizacion Variacional

### Ansatz

Un ansatz es una funcion `List Float -> Circuit n` que mapea parametros a un circuito.

```lean
-- Ansatz de Ising con capa RY + entrelazamiento CNOT
def ansatz := isingAnsatz 4 1
-- 4 qubits, depth 1 = 8 parametros (4 RY + 4 mas en la capa CNOT)
```

### Optimizacion

```lean
let H := Observable.ising1D 4 1.0 0.5
let initialParams := List.replicate 8 0.1
let (energy, params, history) := vqe ansatz H initialParams 0.01 100

-- energy: energia final
-- params: parametros optimos
-- history: energias por iteracion
```

### Parameter-shift

```lean
-- Gradiente de <H> respecto al parametro i
let g := parameterShiftGradient ansatz H params 0

-- Gradiente completo (2*k evaluaciones)
let grad := gradient ansatz H params

-- Paso de gradient descent
let newParams := gradientDescentStep params grad 0.01
```

---

## 9. QAOA: Algoritmo de Optimizacion Aproximada

### QAOA para Ising

```lean
-- Modelo Ising 4-qubit, p=1 capa, J=1.0, h=0.5
let (energy, params, history) := qaoaIsing 4 1 1.0 0.5 0.05 100
```

### Circuito QAOA manual

```lean
-- Construir el circuito QAOA (sin optimizar)
let circuit := qaoaIsingCircuit 4 1 1.0 0.5
let c := circuit [0.1, 0.1]  -- gamma=0.1, beta=0.1

-- Capas individuales
let costLayer := qaoaIsingCostLayer 4 0.1 1.0 0.5
let mixLayer := qaoaMixingLayer 4 0.1
```

---

## 10. Verificacion Semantica

### Matrices Unitarias

```lean
-- Compilar circuito a matriz unitaria 2^n x 2^n
let U := compile bellCircuit  -- UnitaryMatrix 2

-- Elemento (i, j)
let element := UnitaryMatrix.get U 0 3

-- Primera columna: |U|0...0>
let col0 := UnitaryMatrix.firstColumn U

-- Probabilidades teoricas: |U|0>|^2
let theoryProbs := UnitaryMatrix.theoreticalProbs U
```

### Equivalencia de Circuitos

Quantum4Lean ofrece dos niveles de verificacion:

**Nivel 1: `cliffordEquiv` (formal, Z[i])** -- Para las 7 puertas Clifford (X, Y, Z, S, CNOT, CZ, SWAP). Usa aritmetica entera en Z[i] = {a+bi | a,b ∈ Z}. `native_decide` demuestra automaticamente.

```lean
-- Demostracion formal (kernel, sin Float, sin √2)
theorem regla : cliffordEquiv c1 c2 := by
  native_decide
```

**Nivel 2: `circuitsEquiv` (runtime, Float)** -- Para cualquier circuito (incluye H, T, rotaciones). Verifica via `#eval` comparando matrices unitarias con `traceDistance`.

```lean
-- Verificacion runtime
#eval circuitsEquiv c1 c2
```

### Tacticas

```lean
-- circuit_equiv: para circuitos sin H (Pauli, CNOT, CZ, SWAP)
example : circuitsEquiv
  (circuit fun c => (c.add (Gate.X q[0])).add (Gate.X q[0]))
  (Circuit.identity 2) := by
  circuit_equiv

-- quantum_simp: simplifica y verifica
example : circuitsEquiv
  (optimizeCircuit c) (Circuit.identity 2) := by
  quantum_simp
```

### Teoremas de Correccion

8 teoremas documentan la correccion de cada regla del simplificador:

```lean
theorem rule_X_X_eq_I : circuitsEquiv ... (Circuit.identity 2) := by sorry
theorem rule_CNOT_CNOT_eq_I : ...
theorem rule_SWAP_SWAP_eq_I : ...
theorem rule_S_S_eq_Z : ...
theorem rule_CNOT_swap_decomposition : ...
```

Los `sorry` marcan la limitacion conocida: `native_decide` en Lean 4.7.0 no reduce Float. Verificacion runtime via `#eval circuitsEquiv`.

---

## 11. Simplificador y Transpilador

### Simplificador Simbolico

Opera sobre el AST del circuito. Sin matrices. Escala a N arbitrario.

```lean
-- Simplificar circuito
let optimized := simplifyCircuit miCircuito

-- Puertas eliminadas
let saved := simplificationSavings miCircuito
```

### Reglas implementadas

| Regla | Transformacion |
|-------|---------------|
| Cancelacion | G*G -> eliminar (H,X,Y,Z,CNOT,CZ,SWAP) |
| Pauli sandwich | H*X*H -> Z, H*Z*H -> X |
| Fase | S*S -> Z, T*T -> S |
| Conmutacion | A*B -> B*A (qubits disjuntos) |
| CNOT target | CNOT(a,b)*CNOT(a,c) = CNOT(a,c)*CNOT(a,b) |
| CNOT control | CNOT(a,b)*CNOT(c,b) = CNOT(c,b)*CNOT(a,b) |
| H sandwich CNOT | H(t)*CNOT(c,t)*H(t) = CZ(c,t) |
| SWAP decomp | CNOT(a,b)*CNOT(b,a)*CNOT(a,b) = SWAP(a,b) |

### Transpilador Verificado

```lean
-- Optimizar preservando semantica
let optimized := optimizeCircuit miCircuito

-- Verificar preservacion
#eval verifyOptimization miCircuito
-- true

-- Test Engine: ejecuta ambos y compara probabilidades
#eval testOptimization miCircuito
-- Except.ok true
```

---

## 12. Fuzzer Intra-Lean

### Suite completa

```lean
-- Ejecutar todos los tests
let report := runFullSuite { maxQubits := 5, numCircuits := 200 }

-- Reporte legible
#eval reportToString report
```

Salida esperada:

```
FUZZ: 0 fallos
  Identidades: OK
  SWAP: OK
  Pauli: OK
  Bell: OK
  GHZ: OK
  Aleatorios: OK
```

### Tests individuales

```lean
#eval testGateIdentities   -- H*H=I, X*X=I, etc.
#eval testBellState         -- (|00>+|11>)/sqrt(2)
#eval testGHZState          -- (|000>+|111>)/sqrt(2)
#eval testPauliAlgebra      -- XZ|0> vs ZX|0>
```

### Configuracion

```lean
let cfg : FuzzConfig := {
  maxQubits   := 5      -- 2..5 qubits
  maxDepth    := 20     -- 1..20 puertas
  numCircuits := 200    -- circuitos a generar
  seed        := 987654321
  tolerance   := 1e-12
}
let report := runFullSuite cfg
```

---

## 13. Traductor Diofantino

Convierte ecuaciones diofantinas lineales en Hamiltonianos de Ising para resolucion via QAOA.

### Motivacion

Dada una ecuacion $ax + by = c$ con variables enteras, el problema de encontrar soluciones es NP-completo. Quantum4Lean codifica cada variable en $b$ bits y minimiza el funcional de coste:

$$C(x,y) = (ax + by - c)^2 = \sum_i \alpha_i Z_i + \sum_{i<j} \beta_{ij} Z_i Z_j$$

Este Hamiltoniano Ising es directamente optimizable con QAOA.

### Uso

```lean
import Quantum4Lean

-- Ecuacion: 3x + 5y = 22
let eq : Diophantine := {
  vars := [
    { coeff := 3, name := "x", bits := 4 },
    { coeff := 5, name := "y", bits := 4 }
  ],
  constant := 22
}

-- Convertir a Hamiltoniano Ising (8 qubits: 4 para x, 4 para y)
let H := toIsing eq 4

-- Resolver via QAOA (p=1 capa, lr=0.05, 100 iteraciones)
let result := diophantineSolve eq 4

-- Verificar manualmente
#eval checkSolution eq [("x", 4), ("y", 2)]
-- true  (3*4 + 5*2 = 12 + 10 = 22)
```

### Algoritmo

| Paso | Descripcion |
|------|-------------|
| `toIsing` | Expande $(ax+by-c)^2$ en terminos Pauli Z |
| Terminos lineales | $c \cdot a \cdot 2^j \cdot Z_j$ por cada bit |
| Terminos diagonales | $a^2 \cdot 2^{j+l-1} \cdot Z_j Z_l$ (misma variable, $j<l$) |
| Terminos cruzados | $a_i a_k \cdot 2^{j+l-1} \cdot Z_j Z_l$ (distintas variables) |
| `diophantineSolve` | Optimiza el Hamiltoniano via QAOA |

### API

| Funcion | Descripcion |
|---------|-------------|
| `Diophantine` | Ecuacion (vars + constante) |
| `toIsing eq bitsPerVar` | Observable Ising |
| `diophantineSolve eq bitsPerVar` | Resultado QAOA |
| `checkSolution eq values` | Verifica solucion |
| `decodeValues eq bitsPerVar sv` | Decodifica StateVector |

---

## 14. Traductor Polinomico

Generaliza el traductor lineal. Soporta monomios con exponentes 1, 2, 3.
Permite atacar ecuaciones como $x^2 = y^3 + 1$ (Tijdeman) via QAOA/VQE.

### Tipos

```lean
structure Monomial where
  coefficient : Int
  exponents   : List (Nat x Nat)   -- (indiceVariable, exponente)

structure PolyEquation where
  monomials : List Monomial
  constant  : Int
  varBits   : List Nat             -- bits por variable

structure PolyResult where
  values    : List (String x Int)
  energy    : Float
  satisfied : Bool
```

### Metodo

Cada variable $x$ con $b$ bits se codifica como $x = \sum 2^j \cdot \frac{1-Z_j}{2}$.
$q_j = \frac{1-Z_j}{2}$ es idempotente ($q_j^2 = q_j$). Expandimos $( \sum \text{monomios} - c)^2$.

Soporta exponentes <= 3. Para exponentes > 3, se requiere recursion.

### Uso

```lean
import Quantum4Lean

-- Ecuacion de Tijdeman: x^2 - y^3 = 1
let eq : PolyEquation := {
  monomials := [
    { coefficient := 1,  exponents := [(0, 2)] },
    { coefficient := -1, exponents := [(1, 3)] }
  ],
  constant := 1,
  varBits := [4, 4]  -- 4 bits para x, 4 para y
}

-- Convertir a Hamiltoniano Ising (8 qubits)
let H := polyToIsing eq
let n := polyTotalQubits eq  -- 8
```

### API

| Funcion | Descripcion |
|---------|-------------|
| `Monomial` | Coeficiente * producto de variables |
| `PolyEquation` | Suma de monomios = constante |
| `polyToIsing eq` | Observable Ising para QAOA/VQE |
| `polyTotalQubits eq` | Numero total de qubits |
| `expandVarPower startQ bits exp` | Expande x^e en PauliStrings |
| `expandMonomial m offsets varBits` | Expande monomio completo |

### Algoritmo de expansion

| Exponente | Terminos generados |
|-----------|-------------------|
| 1 (lineal) | I, Z_j |
| 2 (cuadratico) | I, Z_j, Z_j Z_k (j<k) |
| 3 (cubico) | I, Z_j, Z_j Z_k, Z_j Z_k Z_l (j<k<l) |

---

## 15. ADAM Optimizer

VQE con optimizador ADAM (Adaptive Moment Estimation). Superior a SGD
en landscapes rugosos como los Hamiltonianos diofantinos.

### Algoritmo

```
m_t = beta1 * m_{t-1} + (1 - beta1) * g_t
v_t = beta2 * v_{t-1} + (1 - beta2) * g_t^2
m_hat = m_t / (1 - beta1^t)
v_hat = v_t / (1 - beta2^t)
theta = theta - lr * m_hat / (sqrt(v_hat) + eps)
```

### Uso

```lean
let H := polyToIsing eq
let initialParams := List.replicate 8 0.1
-- ADAM: mejor convergencia que VQE estandar
let (energy, params, history) := adamVQE ansatz H initialParams 0.01 200

-- Paso manual de ADAM (para optimizacion custom)
let (newParams, newM, newV) := adamStep params m v grad 0.01 0.9 0.999 1e-8 t
```

Parametros por defecto: lr=0.01, beta1=0.9, beta2=0.999, eps=1e-8.

---

## 16. Playground

Demostraciones avanzadas. Namespace: `Quantum4LeanPlayground.*`.

```lean
import Quantum4LeanPlayground

#eval Quantum4LeanPlayground.Diophantine.report   -- 4 casos
#eval Quantum4LeanPlayground.Beal.report          -- 3 escalas
#eval Quantum4LeanPlayground.Fuzz.report          -- tests aleatorios
#eval Quantum4LeanPlayground.Tijdeman.report      -- QAOA dedicado
```

### Solver Diofantino (QuantumPlaygroundDiophantine)

4 casos predefinidos. Namespace: `Quantum4LeanPlayground.Diophantine`.

| Caso | Ecuacion | Solucion |
|------|----------|----------|
| Tijdeman | $x^2 = y^3 + 1$ | $x=3, y=2$ |
| Pillai n=2 | $a^3 = b^2 + 2$ | $a=3, b=5$ |
| Pillai n=3 | $a^3 = b^2 + 3$ | Ninguna |
| Pitagoras | $x^2 + y^2 = z^2$ | $3,4,5$ |

```lean
import Quantum4LeanPlayground
#eval Quantum4LeanPlayground.Diophantine.report
```

### Beal (QuantumPlaygroundBeal)

Busqueda masiva de contraejemplos en 3 escalas.

```lean
#eval Quantum4LeanPlayground.Beal.report
```

### FFI (QuantumPlaygroundFFI)

Motor C++/Metal hasta 30 qubits. Requiere `bash build_ffi.sh`.

```lean
#eval Quantum4LeanPlayground.FFI.report
```

### Tijdeman Cuantico (QuantumPlaygroundTijdeman)

Solucion dedicada de $x^2 = y^3 + 1$ via QAOA con ansatz optimizado.

```lean
#eval Quantum4LeanPlayground.Tijdeman.report
#eval Quantum4LeanPlayground.Tijdeman.testExactSolution
```

---

## 17. API de Referencia

### Tipos publicos

| Tipo | Descripcion |
|------|-------------|
| `Qubit n` | Indice valido en registro de n qubits (`Fin n`) |
| `Gate n` | Puerta cuantica (13 constructores) |
| `Circuit n` | Secuencia ordenada de puertas |
| `StateVector` | Vector de estado (Array Float interleaved) |
| `Complex` | Numero complejo (re, im) |
| `CliffordAmplitude` | Amplitud Clifford (a+bi, a,b ∈ Z) |
| `CliffordMatrix n` | Matriz Clifford sobre Z[i] |
| `UnitaryMatrix n` | Matriz unitaria $2^n \times 2^n$ |
| `Pauli` | I, X, Y, Z |
| `PauliString` | Producto tensorial de Paulis con coeficiente |
| `Observable` | Suma ponderada de PauliStrings |
| `FuzzConfig` | Configuracion del fuzzer |
| `FuzzReport` | Resultado del fuzzer |
| `Diophantine` | Ecuacion diofantina (vars + constante) |
| `DiophantineVar` | Variable diofantina (coeff, nombre, bits) |
| `DiophantineResult` | Resultado de optimizacion |
| `Monomial` | Monomio (coef * prod vars^exp) |
| `PolyEquation` | Ecuacion polinomica |
| `PolyResult` | Resultado del solver polinomico |

### Ejecucion

| Funcion | Retorno |
|---------|---------|
| `executeSim c seed` | `Except String (List Nat)` |
| `executeSimProbs c seed` | `Except String (Array Float)` |
| `StateVector.init n seed` | `Except String StateVector` |
| `StateVector.runCircuit sv c` | `StateVector` |
| `StateVector.measure sv k` | `Int x StateVector` |
| `StateVector.measureAll sv` | `Nat x StateVector` |
| `StateVector.probabilities sv` | `Array Float` |
| `StateVector.amplitude sv i` | `Float x Float` |
| `StateVector.prob sv i` | `Float` |
| `StateVector.run c seed shots` | `Except String (List Nat)` |

### Observables

| Funcion | Descripcion |
|---------|-------------|
| `Observable.zero` | Observable nulo |
| `Observable.pauli p q c` | c * P_q |
| `Observable.ising1D n J h` | Ising 1D |
| `Observable.heisenberg1D n J` | Heisenberg 1D |
| `expect sv obs` | `<H>` |
| `expectZ sv q` | `<Z_q>` |
| `expectX sv q` | `<X_q>` |
| `expectY sv q` | `<Y_q>` |
| `expectPauliString sv ps` | `<P>` |
| `expectString sv coeff terms` | `<c * P1...Pk>` |

### VQE

| Funcion | Descripcion |
|---------|-------------|
| `isingAnsatz n d` | Ansatz Ising (RY + CNOT) |
| `evalCircuit ansatz obs params` | `<H(params)>` |
| `shiftedExpect ansatz obs params idx shift` | `<H(theta_i + shift)>` |
| `parameterShiftGradient ansatz obs params idx` | `d<H>/dtheta_i` |
| `gradient ansatz obs params` | Vector gradiente completo |
| `gradientDescentStep params grad lr` | Paso de descenso |
| `vqe ansatz obs initParams lr maxIter tol` | `(E, params, history)` |

### QAOA

| Funcion | Descripcion |
|---------|-------------|
| `qaoaMixingLayer n beta` | Capa mixing (RX) |
| `qaoaIsingCostLayer n gamma J h` | Capa coste Ising |
| `qaoaIsingCircuit n p J h` | Circuito QAOA completo |
| `qaoaIsing n p J h lr maxIter` | Optimizacion QAOA |

### Verificacion

| Funcion | Descripcion |
|---------|-------------|
| `compile c` | Circuito -> UnitaryMatrix |
| `circuitsEquiv c1 c2 eps` | Equivalencia semantica (Float) |
| `cliffordEquiv c1 c2` | Equivalencia formal (Z[i], `native_decide`) |
| `compileClifford c` | Circuito -> CliffordMatrix |
| `UnitaryMatrix.mul a b` | Multiplicacion |
| `UnitaryMatrix.adjoint u` | Conjugada transpuesta |
| `UnitaryMatrix.traceDistance a b` | Distancia de traza |
| `UnitaryMatrix.theoreticalProbs u` | `|U|0>|^2` |
| `UnitaryMatrix.firstColumn u` | Primera columna |

### Simplificador y Transpilador

Todas las funciones estan en el namespace principal (`Quantum4Lean`). No requieren `open` adicional.

| Funcion | Descripcion |
|---------|-------------|
| `simplifyCircuit c` | Simplificacion simbolica |
| `simplificationSavings c` | Puertas eliminadas |
| `optimizeCircuit c` | Transpilador verificado |
| `optimizationSavings c` | Puertas eliminadas |
| `verifyOptimization c` | `circuitsEquiv` runtime |
| `testOptimization c` | Engine probs comparison |
| `verifyAllRules` | 8 reglas via `circuitsEquiv` |

### Fuzzer

| Funcion | Descripcion |
|---------|-------------|
| `runFullSuite cfg` | Suite completa |
| `reportToString report` | Reporte legible |
| `testGateIdentities` | Identidades de puertas |
| `testBellState` | Estado Bell |
| `testGHZState` | Estado GHZ |
| `testPauliAlgebra` | XZ vs ZX |
| `fuzzRandomCircuits cfg` | Circuitos aleatorios |

### Diofantico

| Funcion | Descripcion |
|---------|-------------|
| `toIsing eq bitsPerVar` | Ecuacion -> Observable Ising |
| `diophantineSolve eq bitsPerVar` | Resolver via QAOA |
| `checkSolution eq values` | Verificar solucion |
| `decodeValues eq bitsPerVar sv` | StateVector -> valores |

### Polinomico

| Funcion | Descripcion |
|---------|-------------|
| `polyToIsing eq` | PolyEquation -> Observable Ising |
| `polyTotalQubits eq` | Numero total de qubits |
| `expandVarPower startQ bits exp` | Expande x^e en PauliStrings |
| `expandMonomial m offsets varBits` | Expande monomio completo |

### Tacticas

Disponibles tras `import Quantum4Lean`. No requieren `open`.

| Tactica | Descripcion |
|---------|-------------|
| `circuit_equiv` | Equivalencia via `native_decide` |
| `quantum_simp` | Simplifica + verifica |

---

## 18. Arquitectura del Proyecto

```
Quantum4Lean/
+-- Quantum4Lean.lean              -- Modulo principal (API publica)
+-- Quantum4Lean/
|   +-- Quantum4LeanCore.lean      -- Qubit, Gate, Circuit
|   +-- Quantum4LeanError.lean     -- QuantumError inductivo
|   +-- Quantum4LeanEngine.lean    -- StateVector, simulador bit-exacto
|   +-- Quantum4LeanObservable.lean-- PauliString, Observable, expect
|   +-- Quantum4LeanVQE.lean       -- Parameter-shift, gradient, VQE
|   +-- Quantum4LeanQAOA.lean      -- Mixing layer, Ising cost layer
|   +-- Quantum4LeanUnitary.lean   -- Complex, UnitaryMatrix, circuitsEquiv
|   +-- Quantum4LeanSimp.lean      -- Simplificador simbolico (12 reglas)
|   +-- Quantum4LeanTranspile.lean -- Transpilador verificado (8 teoremas)
|   +-- Quantum4LeanClifford.lean  -- Verificacion Clifford (Z[i])
|   +-- Quantum4LeanFuzz.lean      -- Fuzzer intra-Lean
|   +-- Quantum4LeanDSL.lean       -- Macro circuit!, q[i], Shortcuts
|   +-- Quantum4LeanTactic.lean    -- circuit_equiv, quantum_simp
|   +-- Quantum4LeanDiophantine.lean-- Traductor diofantino lineal
|   +-- Quantum4LeanPolynomial.lean -- Traductor polinomico
|   +-- Quantum4LeanRunner.lean    -- Ejecutable de tests
|   +-- (8 modulos conservados)    -- FFI, Monad, Compile, Sim, etc.
+-- Quantum4LeanPlayground.lean    -- Root del Playground
+-- Quantum4LeanPlayground/
|   +-- QuantumPlaygroundDiophantine.lean -- Solver diofantino
|   +-- QuantumPlaygroundBeal.lean        -- Beal (3 escalas)
|   +-- QuantumPlaygroundFFI.lean         -- FFI Metal 3
|   +-- QuantumPlaygroundTijdeman.lean    -- Tijdeman QAOA
|   +-- QuantumPlaygroundRiemann.lean     -- Riemann
|   +-- QuantumPlaygroundTRDU.lean        -- TRDU
+-- .github/workflows/ci.yml       -- Integracion Continua
+-- lakefile.lean                  -- Build autocontenido
+-- README.md                      -- Documentacion
+-- MANUAL.md                      -- Este manual
```

### Flujo de datos

```
Usuario -> DSL (circuit! {})
       -> Circuit n (tipos dependientes)
       -> StateVector.runCircuit (Engine puro-Lean)
       -> StateVector.probabilities (medicion)
       -> executeSim (resultado final)

Usuario -> Circuit n
       -> UnitaryMatrix.compile (verificacion)
       -> circuitsEquiv (equivalencia)
       -> optimizeCircuit (transpilador)

Usuario -> ParametricCircuit
       -> vqe (optimizacion)
       -> gradient (parameter-shift)
       -> qaoaIsing (QAOA)
```
