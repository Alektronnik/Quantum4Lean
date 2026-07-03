#!/bin/bash
# build_ffi.sh
# Compila el motor C++ y el puente C para FFI con Quantum4Lean.
# Requiere: Xcode CLT, Metal framework.
# Salida: libQuantum4LeanFFI.a en la raiz del proyecto.

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

echo "[2/3] Compilando puente C (Quantum4LeanBridge)..."
clang -c -O3 \
  -I"$ENGINE_DIR/include" \
  "$BRIDGE_DIR/Quantum4LeanBridge.c" \
  -o /tmp/ql4_bridge.o

echo "[3/3] Creando libreria estatica..."
ar rcs "$OUTPUT" /tmp/ql4_bridge.o /tmp/ql4_engine.o
rm -f /tmp/ql4_bridge.o /tmp/ql4_engine.o

echo "=== FFI lib creada: $OUTPUT ==="
ls -lh "$OUTPUT"

echo ""
echo "Para compilar Quantum4Lean con FFI:"
echo "  lake build quantum4lean-ffi"
echo ""
echo "Para ejecutar el playground Beal FFI:"
echo "  .lake/build/bin/quantum4lean-ffi"
