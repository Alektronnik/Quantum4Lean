/*
 * Quantum4LeanFFI_v2.h
 * API C simplificada para Lean 4.7.0 (FloatArray en lugar de Ptr).
 * Todas las funciones reciben/retornan tipos escalares o FloatArray.
 */

#ifndef QL4_FFI_V2_H
#define QL4_FFI_V2_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Init: retorna token (0 = error). estado es FloatArray (double*).
uint64_t Quantum4LeanInit(int numQubits, const double* estado, uint64_t semilla);

// Finalize
int Quantum4LeanFinalize(uint64_t token);

// Memoria estimada (bytes)
uint64_t Quantum4LeanMemoryEstimate(int numQubits);

// Aplica puerta in-place
int Quantum4LeanApplyGate(uint64_t token, int tipo, int qA, int qB,
                           double parametro, double* estado);

// Mide qubit k. Retorna bit (0/1) o -1 si error.
int Quantum4LeanMeasure(uint64_t token, int qubitK, double* estado);

// Probabilidades (probs pre-alocado size 2^N)
int Quantum4LeanProbabilities(uint64_t token, const double* estado, double* probs);

#ifdef __cplusplus
}
#endif

#endif
