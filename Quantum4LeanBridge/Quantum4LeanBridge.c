/*
 *  Quantum4LeanBridge.c
 *  Quantum4Lean -- Puente C puro hacia QuantumKitCore
 *
 *  Implementacion minimal: delega directamente al motor.
 *  Compilado como libreria estatica enlazada al ejecutable Lean.
 */

#include "Quantum4LeanBridge.h"
#include "QuantumKitCore.h"  // API C estable del motor

#include <stdlib.h>   // malloc, free
#include <string.h>   // memset

// --- Ciclo de vida -----------------------------------------------

int Quantum4LeanInit(int numQubits, const double* estadoInicial,
                      uint64_t semilla, Quantum4LeanToken* tokenOut) {
    return qu4trix_iniciar(numQubits,
                           (double*)estadoInicial,
                           semilla, tokenOut);
}

int Quantum4LeanFinalize(Quantum4LeanToken token) {
    return qu4trix_finalizar(token);
}

uint64_t Quantum4LeanMemoryEstimate(int numQubits) {
    return qu4trix_memoria_estimada(numQubits);
}

// --- Puertas -----------------------------------------------------

int Quantum4LeanApplyGate(Quantum4LeanToken token, int tipo, int qA, int qB,
                           double parametro, double* estadoIO) {
    return qu4trix_aplicar_puerta(token, tipo, qA, qB,
                                  parametro, NULL, estadoIO, NULL);
}

int Quantum4LeanApplyUnitary(Quantum4LeanToken token, int q,
                              const double* matriz, double* estadoIO) {
    return qu4trix_aplicar_puerta(token, 12, q, 0, 0.0,
                                  (double*)matriz, estadoIO, NULL);
}

// --- Medicion ----------------------------------------------------

int Quantum4LeanMeasure(Quantum4LeanToken token, int qubitK,
                         double* estadoIO, int* bitOut) {
    return qu4trix_medir(token, qubitK, estadoIO, bitOut);
}

// --- Probabilidades ----------------------------------------------

int Quantum4LeanProbabilities(Quantum4LeanToken token, const double* estado,
                               double* probsOut) {
    return qu4trix_probabilidades(token, estado, probsOut);
}

// --- Telemetria --------------------------------------------------

int Quantum4LeanTelemetry(Quantum4LeanToken token, int* nOut, int* dimOut,
                           int* cyclesOut) {
    return qu4trix_telemetria(token, nOut, dimOut, cyclesOut);
}

// --- Utilidades de memoria ---------------------------------------

double* Quantum4LeanAllocState(int numQubits) {
    if (numQubits < 1 || numQubits > 30) return NULL;
    int dim = 1 << numQubits;
    int elements = 2 * dim;
    double* state = (double*)malloc(elements * sizeof(double));
    if (state) {
        memset(state, 0, elements * sizeof(double));
        state[0] = 1.0;  // |0...0>
    }
    return state;
}

void Quantum4LeanFreeState(double* estado) {
    free(estado);
}
