#!/bin/bash
# build_ffi.sh
# Compila el motor C++ y el puente C para FFI con Quantum4Lean.
# Requiere: Xcode CLT, Metal framework.
# Salida: libQuantum4LeanFFI.a en la raiz del proyecto.
#
# NOTA: El ejecutable final requiere LEAN_CC=clang para usar el linker
# del sistema (ld64.lld no soporta frameworks Apple). Sin embargo,
# Lean 4.7.0 incrusta el entry point de Lake en lugar del modulo Lean,
# impidiendo la ejecucion directa. Infraestructura lista para 4.8.0+.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTUMKIT_DIR="$SCRIPT_DIR/../QuantumKit"
BRIDGE_DIR="$SCRIPT_DIR/Quantum4LeanBridge"
ENGINE_DIR="$QUANTUMKIT_DIR/Sources/QuantumKitCore"
OUTPUT="$SCRIPT_DIR/libQuantum4LeanFFI.a"

echo "=== Compilando Quantum4Lean FFI Bridge ==="

echo "[1/3] Compilando motor C++ (QuantumKitCore)..."
clang++ -c -O3 -std=c++17 \
  -I"$ENGINE_DIR/include" \
  "$ENGINE_DIR/engine/QuantumKitCore.mm" \
  -o /tmp/ql4_engine.o

echo "[2/3] Compilando puente C (Quantum4LeanFFI)..."
clang -c -O3 -include stddef.h \
  -I"$BRIDGE_DIR" \
  -I"$ENGINE_DIR/include" \
  "$BRIDGE_DIR/Quantum4LeanFFI.c" \
  -o /tmp/ql4_bridge.o

echo "[3/3] Creando libreria estatica..."
ar rcs "$OUTPUT" /tmp/ql4_bridge.o /tmp/ql4_engine.o
rm -f /tmp/ql4_bridge.o /tmp/ql4_engine.o

echo "=== FFI lib creada: $OUTPUT ==="
ls -lh "$OUTPUT"

echo ""
echo "Para compilar Quantum4Lean con FFI (requiere LEAN_CC=clang):"
echo "  LEAN_CC=clang lake build quantum4lean-ffi"
echo ""
echo "NOTA: Lean 4.7.0 no puede ejecutar binarios FFI nativos."
echo "Infraestructura lista para Lean >= 4.8.0."
