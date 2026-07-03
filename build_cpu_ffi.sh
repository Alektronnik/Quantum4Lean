#!/bin/bash
# build_cpu_ffi.sh
# Compila el motor C++ en modo CPU-only (sin Metal, sin Foundation).
# La libreria resultante enlaza con ld64.lld (linker bundled de Lean).
#
# Requiere: Xcode CLT (clang++), NO requiere Metal framework.
# Salida: libQuantum4LeanCPU.a en la raiz del proyecto.
#
# Uso:
#   bash build_cpu_ffi.sh && lake build quantum4lean-ffi
#   .lake/build/bin/quantum4lean-ffi

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTUMKIT_DIR="$SCRIPT_DIR/../QuantumKit"
BRIDGE_DIR="$SCRIPT_DIR/Quantum4LeanBridge"
ENGINE_DIR="$QUANTUMKIT_DIR/Sources/QuantumKitCore"
OUTPUT="$SCRIPT_DIR/libQuantum4LeanCPU.a"

echo "=== Compilando Quantum4Lean FFI Bridge (CPU-only) ==="

echo "[1/3] Compilando motor C++ (CPU, sin ObjC/Metal)..."
clang++ -c -O3 -std=c++17 -x c++ \
  -I"$ENGINE_DIR/include" \
  "$ENGINE_DIR/engine/QuantumKitCore.mm" \
  -o /tmp/ql4_engine_cpu.o

echo "[2/3] Compilando puente C..."
clang -c -O3 \
  -include stddef.h \
  -I"$BRIDGE_DIR" \
  -I"$ENGINE_DIR/include" \
  "$BRIDGE_DIR/Quantum4LeanFFI.c" \
  -o /tmp/ql4_bridge_cpu.o

echo "[3/3] Creando libreria estatica..."
ar rcs "$OUTPUT" /tmp/ql4_bridge_cpu.o /tmp/ql4_engine_cpu.o
rm -f /tmp/ql4_bridge_cpu.o /tmp/ql4_engine_cpu.o

echo "=== FFI CPU lib creada: $OUTPUT ==="
ls -lh "$OUTPUT"

echo ""
echo "Para compilar y ejecutar Quantum4Lean con FFI (CPU):"
echo "  lake build quantum4lean-ffi && .lake/build/bin/quantum4lean-ffi"
echo ""
echo "NOTA: Motor CPU-only, hasta 30 qubits. Sin dependencias de Metal."
