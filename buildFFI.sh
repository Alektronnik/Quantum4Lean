#!/bin/bash
# buildFFI.sh
# Compila el motor C++ y el puente C para FFI con Quantum4Lean.
# Requiere: Xcode CLT, Metal framework.
# Salida: libQuantum4LeanFFI.a en la raiz del proyecto.
#
# Uso:
#   bash buildFFI.sh && LEAN_CC=clang lake build quantum4lean-ffi-metal
#   .lake/build/bin/quantum4lean-ffi-metal

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTUMKIT_DIR="$SCRIPT_DIR/../QuantumKit"
BRIDGE_DIR="$SCRIPT_DIR/Quantum4LeanBridge"
ENGINE_DIR="$QUANTUMKIT_DIR/Sources/QuantumKitCore"
OUTPUT="$SCRIPT_DIR/libQuantum4LeanFFI.a"
TMPDIR="${TMPDIR:-/tmp}"

echo "=== Compilando Quantum4Lean FFI Bridge ==="

echo "[1/3] Compilando motor C++ (QuantumKitCore)..."
clang++ -c -O3 -std=c++17 \
  -I"$ENGINE_DIR/include" \
  "$ENGINE_DIR/engine/QuantumKitCore.mm" \
  -o "$TMPDIR/ql4_engine.o"

echo "[2/3] Compilando puente C (Quantum4LeanFFI)..."
clang -c -O3 -include stddef.h \
  -I"$BRIDGE_DIR" \
  -I"$ENGINE_DIR/include" \
  "$BRIDGE_DIR/Quantum4LeanFFI.c" \
  -o "$TMPDIR/ql4_bridge.o"

echo "[3/3] Creando libreria estatica..."
ar rcs "$OUTPUT" "$TMPDIR/ql4_bridge.o" "$TMPDIR/ql4_engine.o"
rm -f "$TMPDIR/ql4_bridge.o" "$TMPDIR/ql4_engine.o"

echo "=== FFI lib creada: $OUTPUT ==="
ls -lh "$OUTPUT"

echo ""
echo "Para compilar Quantum4Lean con FFI:"
echo "  bash buildFFI.sh && LEAN_CC=clang lake build quantum4lean-ffi-metal"
echo ""
echo "Infraestructura lista. Testeado con Lean 4.31.0."
