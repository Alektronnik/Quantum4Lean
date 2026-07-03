/*
 * Quantum4LeanFFI.h
 * API C para Lean 4.31.0 (FloatArray, tipos crudos sin IO).
 * Las funciones retornan tipos escalares; Lean las envuelve en IO via unsafe.
 */

#ifndef QL4_FFI_V2_H
#define QL4_FFI_V2_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint64_t Quantum4LeanInit(uint32_t numQubits, const double* estado, uint64_t semilla);
uint32_t Quantum4LeanFinalize(uint64_t token);
uint64_t Quantum4LeanMemoryEstimate(uint32_t numQubits);
uint32_t Quantum4LeanApplyGate(uint64_t token, uint32_t tipo, uint32_t qA, uint32_t qB,
                                double parametro, double* estado);
uint32_t Quantum4LeanMeasure(uint64_t token, uint32_t qubitK, double* estado);
uint32_t Quantum4LeanProbabilities(uint64_t token, const double* estado, double* probs);

#ifdef __cplusplus
}
#endif

#endif
