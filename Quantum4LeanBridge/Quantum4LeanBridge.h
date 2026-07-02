/*
 *  Quantum4LeanBridge.h
 *  Quantum4Lean -- C Bridge to QuantumKitCore
 *
 *  API C pura disenada para consumo via Lean 4 @[extern].
 *  Sin dependencias de Objective-C ni Swift.
 *  Todas las funciones devuelven int (codigo de error, 0 = exito).
 *
 *  Convenciones:
 *    - prefijo: Quantum4Lean (sin abreviaturas, sin underscores)
 *    - snake_case, estilo C estandar
 *    - punteros out usan sufijo Out
 *    - size_t para longitudes (compatible con Lean USize)
 */

#ifndef Quantum4LeanBridge_H
#define Quantum4LeanBridge_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// --- Tipos opacos -------------------------------------------------

// Handle opaco a una instancia del motor cuantico.
// En Lean 4 se representa como USize (uint64_t).
typedef uint64_t Quantum4LeanToken;

// --- Codigos de error --------------------------------------------

#define Quantum4LeanOK                 0
#define Quantum4LeanErrNoInit        201
#define Quantum4LeanErrQubitRange    202
#define Quantum4LeanErrQubitsMax     203
#define Quantum4LeanErrNullPointer   205
#define Quantum4LeanErrTokenMismatch 207
#define Quantum4LeanErrMemoria       208
#define Quantum4LeanErrGPU           300

// --- Ciclo de vida -----------------------------------------------

// Inicializa un motor de N qubits (N en [1, 30]).
// estadoInicial: NULL para |0...0>, o array de 2*2^N doubles.
// semilla: semilla pseudoaleatoria para mediciones.
// tokenOut: recibe el token de instancia.
int Quantum4LeanInit(int numQubits, const double* estadoInicial,
                      uint64_t semilla, Quantum4LeanToken* tokenOut);

// Libera recursos del motor asociado al token.
int Quantum4LeanFinalize(Quantum4LeanToken token);

// Estima la memoria necesaria en bytes para N qubits.
uint64_t Quantum4LeanMemoryEstimate(int numQubits);

// --- Puertas -----------------------------------------------------

// Aplica una puerta del catalogo estandar.
// tipo: 0=H, 1=X, 2=Y, 3=Z, 4=S, 5=T,
//       6=CNOT, 7=CZ, 8=SWAP, 9=RX, 10=RY, 11=RZ
// qA, qB: qubits (qB ignorado para puertas de 1 qubit).
// parametro: theta para RX/RY/RZ (en radianes).
// estadoIO: state vector in/out (2*2^N doubles, real/imag interleaved).
int Quantum4LeanApplyGate(Quantum4LeanToken token, int tipo, int qA, int qB,
                           double parametro, double* estadoIO);

// Aplica una matriz unitaria 2x2 arbitraria al qubit q.
// matriz: 8 doubles [U00r, U00i, U01r, U01i, U10r, U10i, U11r, U11i].
int Quantum4LeanApplyUnitary(Quantum4LeanToken token, int q,
                              const double* matriz, double* estadoIO);

// --- Medicion ----------------------------------------------------

// Mide el qubit k, colapsa el estado y devuelve 0 o 1.
int Quantum4LeanMeasure(Quantum4LeanToken token, int qubitK,
                         double* estadoIO, int* bitOut);

// --- Probabilidades ----------------------------------------------

// Calcula P(|i>) para todos los 2^N estados base.
// probsOut: array de 2^N doubles.
int Quantum4LeanProbabilities(Quantum4LeanToken token, const double* estado,
                               double* probsOut);

// --- Telemetria --------------------------------------------------

// Obtiene numQubits, dimension (2^N) y ciclos de GPU/CPU.
int Quantum4LeanTelemetry(Quantum4LeanToken token, int* nOut, int* dimOut,
                           int* cyclesOut);

// --- Utilidades de memoria ---------------------------------------

// Aloja un state vector para N qubits (2*2^N doubles, init en |0...0>).
// El llamador es responsable de liberar con Quantum4LeanFreeState.
double* Quantum4LeanAllocState(int numQubits);

// Libera un state vector.
void Quantum4LeanFreeState(double* estado);

#ifdef __cplusplus
}
#endif

#endif /* Quantum4LeanBridge_H */
