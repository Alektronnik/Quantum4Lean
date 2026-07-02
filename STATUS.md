# Quantum4Lean -- Estado del Proyecto

Fecha: 2026-07-02
Version: v0.4.0
Build: `lake build` autocontenido, 0 errores
Tests: `./build/bin/quantum4lean-test` -- 8/8 unitarios + 0 fallos fuzzer
CI: `.github/workflows/ci.yml` -- build + test en cada push

## Arquitectura actual

```
                    Quantum4Lean.lean (modulo principal)
                            |
    +-------+-------+-------+-------+-------+-------+-------+
    |       |       |       |       |       |       |       |
   Core   Error  Engine  Fuzz  Unitary  Obs    VQE    QAOA
                                                    (Ising)
                            |
                    Quantum4LeanRunner
                    (ejecutable de validacion)
```

## Modulos activos (10/18 compilan y pasan tests)

| # | Modulo | Estado | Funcion |
|---|--------|--------|---------|
| 1 | Quantum4LeanCore | ACTIVO | Qubit (Fin n), Gate (13 constructores), Circuit, builder |
| 2 | Quantum4LeanError | ACTIVO | QuantumError inductivo |
| 3 | Quantum4LeanEngine | ACTIVO | StateVector, LCG, 13 puertas, medicion, colapso |
| 4 | Quantum4LeanFuzz | ACTIVO | 8 identidades + Bell + GHZ + Pauli + 200 aleatorios |
| 5 | Quantum4LeanUnitary | ACTIVO | Complex, UnitaryMatrix, compile, circuitsEquiv |
| 6 | Quantum4LeanObservable | ACTIVO | Pauli/I/X/Y/Z, PauliString, Observable, expect, Ising, Heisenberg |
| 7 | Quantum4LeanVQE | ACTIVO | Parameter-shift, gradient, gradientDescent, vqe |
| 8 | Quantum4LeanQAOA | ACTIVO | Mixing layer, Ising cost layer, qaoaIsing |
| 9 | Quantum4LeanRunner | ACTIVO | main: IO UInt32, test suite |
| 10 | Quantum4Lean.lean | ACTIVO | Modulo principal |

## Stack NISQ completado (puro Lean, sin FFI)

Los tres modulos fueron reescritos como funciones puras sobre StateVector:

| Modulo | Antes (FFI) | Ahora (puro) |
|--------|------------|--------------|
| Observable | `QuantumM.expect obs` | `expect sv obs` |
| VQE | `runQuantum (vqe ...)` | `vqe ansatz obs params` |
| QAOA | `runQuantum (qaoaIsing ...)` | `qaoaIsing n p J h` |

Cambios clave:
- `qubit : Int` -> `qubit : Nat` (sin signo, indices naturales)
- `ParametricCircuit k` (monadico) -> `List Float -> Circuit n` (puro)
- `QuantumM.expect` -> `expect : StateVector -> Observable -> Float`
- Sin IO, sin token, sin alloc/free, sin FFI
- `isingAnsatz` usa foldl anidados (sin `let mut`)
- `vqeLoop` recursivo (sin `let mut`)
- `listModify` manual (no existe en 4.7.0)

## Modulos inactivos (8/18)

| # | Modulo | Estado | Bloqueante |
|---|--------|--------|------------|
| 11 | Quantum4LeanFFI | INACTIVO | No enlaza sin libQuantumKitCore.a |
| 12 | Quantum4LeanSim | INACTIVO | Depende de FFI |
| 13 | Quantum4LeanMonad | INACTIVO | Depende de FFI |
| 14 | Quantum4LeanCompile | INACTIVO | Depende de Monad |
| 15 | Quantum4LeanDSL | INACTIVO | Errores de sintaxis `syntax` en 4.7.0 |
| 16 | Quantum4LeanVerify | INACTIVO | Errores de sintaxis en 4.7.0 |
| 17 | Quantum4LeanExamples | INACTIVO | Depende de FFI/Sim |
| 18 | Quantum4LeanTest | INACTIVO | Depende de Unitary (ya activo), requiere revision |

## Infraestructura

| Componente | Estado |
|-----------|--------|
| lakefile.lean | Build autocontenido + `lean_exe «quantum4lean-test»` |
| lean-toolchain | `leanprover/lean4:4.7.0` |
| .github/workflows/ci.yml | CI: Ubuntu, elan + lake build + test |
| README.md | Documentado (v0.3, arquitectura, API, bit-exactness) |
| Quantum4LeanBridge/ | Puente C (no compila sin QuantumKitCore binary) |

## Verificacion: triangulo cerrado

Los 3 caminos de verificacion producen resultados identicos:

| Camino | Metodo | Bell | GHZ | H*H=I |
|--------|--------|------|-----|-------|
| Engine | StateVector.probabilities | [0.5, 0, 0, 0.5] | [0.5, 0, 0, 0, 0, 0, 0, 0.5] | [1, 0, 0, 0] |
| Unitary | theoreticalProbs (compile) | [0.5, 0, 0, 0.5] | [0.5, 0, 0, 0, 0, 0, 0, 0.5] | [1, 0, 0, 0] |
| Fuzz | testBellState/testGHZState | amplitudes exactas | amplitudes exactas | testGateIdentities |

## Bugs encontrados y corregidos en v0.3

| Bug | Archivo | Causa | Fix |
|-----|---------|-------|-----|
| CNOT half-swap | Engine | foldl solo copiaba iSwap->i, sin copiar i->iSwap. Procesar el par dos veces duplicaba ceros | Swap bidireccional con guard `i < iSwap` |
| Pauli expectativas | Fuzz | Test esperaba XZ|0>=|1>, pero el circuito [X,Z] aplica X primero: X|0>=|1>, Z|1>=-|1> | Expectativas corregidas a XZ|0>=-|1>, ZX|0>=|1> |
| `let mut` no soportado | Engine, Fuzz, Unitary | Lean 4.7.0 no tiene `let mut` | `foldl` sobre listas en todos los algoritmos |
| `Float.pi` no existe | Unitary | Lean 4.7.0 no define `Float.pi` | Constante literal `3.141592653589793` |
| `~~~mask` sin Complement | Unitary | `Nat` no tiene `Complement` en 4.7.0 | `(d-1) ^^^ mask` para complemento en n bits |
| `c` como nombre de funcion | Unitary | `c(` se confunde con sintaxis en 4.7.0 | Renombrado a `mkC` |
| `FloatArray 8` no existe | Core | `FloatArray` no parametrizado en 4.7.0 | `Array Float` |
| `Deriving Repr` en Complex | Unitary | Float no es estructuralmente recursivo | `toString` manual, sin derivar |
| `Deriving DecidableEq` en Complex | Unitary | Float no es decidable | Sin derivar |
| `nativeDecide` (camelCase) | Unitary | La tactica es `native_decide` | Corregido, pero no reduce Float -> convertido a tests `def` |

## Pendientes priorizados

### Bloque 1: Publicacion y adopcion (siguiente paso)

| Prioridad | Tarea | Esfuerzo | Impacto |
|-----------|-------|----------|---------|
| ALTA | Publicar en Reservoir (`lake upload`) | Bajo | Primer paquete cuantico en el ecosistema Lean 4 |
| MEDIA | Escribir post en Lean Community Blog | Medio | Visibilidad, atraer contribuidores |
| MEDIA | Demo: VQE Ising 4-qubit 100% Lean | Bajo | Prueba de concepto NISQ completa |

### Bloque 2: Expandir build activo

| Prioridad | Tarea | Esfuerzo | Impacto |
|-----------|-------|----------|---------|
| MEDIA | Rescatar Quantum4LeanDSL (macro circuit!) | Medio | Sintaxis declarativa |
| MEDIA | Rescatar Quantum4LeanVerify (identidades con pruebas) | Bajo | Formal verification adicional |
| BAJA | Rescatar Quantum4LeanTest (55 aserciones) | Bajo | Cobertura de regression |

### Bloque 3: Puente FFI (requiere QuantumKitCore binary)

| Prioridad | Tarea | Esfuerzo | Impacto |
|-----------|-------|----------|---------|
| MEDIA | Exponer `Quantum4LeanReset` en bridge C | Bajo | Elimina 50ms de JIT |
| MEDIA | Cross-engine fuzzer (Engine vs FFI) | Medio | Validacion bit-exacta |
| BAJA | Compilar y enlazar Quantum4LeanBridge.c | Alto | Requiere binario |

### Bloque 4: Mejoras

| Prioridad | Tarea | Esfuerzo | Impacto |
|-----------|-------|----------|---------|
| BAJA | ADAM optimizer para VQE | Medio | Convergencia mas rapida |
| BAJA | Soporte para `n > 10` en Engine puro | Alto | Sin limite de qubits |
| BAJA | Sustituir `List Nat` por `Array Nat` en fuzzer | Medio | Rendimiento |

## Metricas

| Metrica | Valor |
|---------|-------|
| Lineas Lean activas | ~1900 (Core 130 + Engine 290 + Fuzz 310 + Unitary 310 + Obs 180 + VQE 140 + QAOA 180 + Error 85 + Runner 30 + Main 35) |
| Modulos que compilan | 10 de 18 |
| Tests que pasan | 8 unitarios + 200 aleatorios = 208 |
| Tiempo de build | ~20s (limpio), ~2s (incremental) |
| Tiempo de test | ~3s (200 circuitos aleatorios) |
| Dependencias externas | 0 |
| Qubits max (Engine) | 10 |
| Qubits max (FFI, futuro) | 30 |
