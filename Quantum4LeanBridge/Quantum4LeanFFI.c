#include <stddef.h>
#include "Quantum4LeanFFI.h"
#include "QuantumKitCore.h"

uint64_t Quantum4LeanInit(int numQubits, const double* estado, uint64_t semilla) {
    uint64_t token = 0;
    int err = qu4trix_iniciar(numQubits, (double*)estado, semilla, &token);
    return (err == 0) ? token : 0;
}
int Quantum4LeanFinalize(uint64_t token) {
    return qu4trix_finalizar(token);
}
uint64_t Quantum4LeanMemoryEstimate(int numQubits) {
    return qu4trix_memoria_estimada(numQubits);
}
int Quantum4LeanApplyGate(uint64_t token, int tipo, int qA, int qB,
                           double parametro, double* estado) {
    return qu4trix_aplicar_puerta(token, tipo, qA, qB, parametro, NULL, estado, NULL);
}
int Quantum4LeanMeasure(uint64_t token, int qubitK, double* estado) {
    int bit = 0;
    int err = qu4trix_medir(token, qubitK, estado, &bit);
    return (err == 0) ? bit : -1;
}
int Quantum4LeanProbabilities(uint64_t token, const double* estado, double* probs) {
    return qu4trix_probabilidades(token, estado, probs);
}
