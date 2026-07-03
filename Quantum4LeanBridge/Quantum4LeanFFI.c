#include <stddef.h>
#include "Quantum4LeanFFI.h"
#include "QuantumKitCore.h"

// Funcion de prueba minima: retorna 42
uint32_t Quantum4LeanTestPing(uint32_t x) {
    return x + 42;
}

uint64_t Quantum4LeanInit(uint32_t numQubits, const double* estado, uint64_t semilla) {
    uint64_t token = 0;
    int err = qu4trix_iniciar((int)numQubits, (double*)estado, semilla, &token);
    return (err == 0) ? token : 0;
}
uint32_t Quantum4LeanFinalize(uint64_t token) {
    return (uint32_t)qu4trix_finalizar(token);
}
uint64_t Quantum4LeanMemoryEstimate(uint32_t numQubits) {
    return qu4trix_memoria_estimada((int)numQubits);
}
uint32_t Quantum4LeanApplyGate(uint64_t token, uint32_t tipo, uint32_t qA, uint32_t qB,
                                double parametro, double* estado) {
    return (uint32_t)qu4trix_aplicar_puerta(token, (int)tipo, (int)qA, (int)qB,
                                            parametro, NULL, estado, NULL);
}
uint32_t Quantum4LeanMeasure(uint64_t token, uint32_t qubitK, double* estado) {
    int bit = 0;
    int err = qu4trix_medir(token, (int)qubitK, estado, &bit);
    return (err == 0) ? (uint32_t)bit : 0xFFFFFFFFu;
}
uint32_t Quantum4LeanProbabilities(uint64_t token, const double* estado, double* probs) {
    return (uint32_t)qu4trix_probabilidades(token, estado, probs);
}
