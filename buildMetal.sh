#!/bin/bash
# buildMetal.sh
# Compila el motor C++ con Metal GPU (Apple Silicon) + puente C para FFI.
# El motor usa compilacion JIT de Metal shaders (embebidos en el codigo).
# NO requiere .metal externo. NO requiere metallib precompilado.
#
# Requiere: Xcode CLT, Metal framework (solo disponible en macOS).
# Salida: libQuantum4LeanMetal.a en la raiz del proyecto.
#
# Uso:
#   bash buildMetal.sh && LEAN_CC=clang lake build quantum4lean-ffi-metal
#   .lake/build/bin/quantum4lean-ffi-metal

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTUMKIT_DIR="$SCRIPT_DIR/../QuantumKit"
BRIDGE_DIR="$SCRIPT_DIR/Quantum4LeanBridge"
ENGINE_DIR="$QUANTUMKIT_DIR/Sources/QuantumKitCore"
OUTPUT="$SCRIPT_DIR/libQuantum4LeanMetal.a"
TMPDIR="${TMPDIR:-/tmp}"

echo "=== Compilando Quantum4Lean FFI Bridge (Metal GPU) ==="

echo "[1/3] Compilando motor C++ con Metal (Objective-C++)..."
clang++ -c -O3 -std=c++17 -x objective-c++ \
  -I"$ENGINE_DIR/include" \
  -D__OBJC__ \
  "$ENGINE_DIR/engine/QuantumKitCore.mm" \
  -o "$TMPDIR/ql4_engine_metal.o"

echo "[2/3] Compilando puente C..."
clang -c -O3 \
  -include stddef.h \
  -I"$BRIDGE_DIR" \
  -I"$ENGINE_DIR/include" \
  "$BRIDGE_DIR/Quantum4LeanFFI.c" \
  -o "$TMPDIR/ql4_bridge_metal.o"

echo "[3/3] Creando libreria estatica..."
ar rcs "$OUTPUT" "$TMPDIR/ql4_bridge_metal.o" "$TMPDIR/ql4_engine_metal.o"
rm -f "$TMPDIR/ql4_bridge_metal.o" "$TMPDIR/ql4_engine_metal.o"

echo "=== FFI Metal lib creada: $OUTPUT ==="
ls -lh "$OUTPUT"

echo ""
echo "Para compilar y ejecutar Quantum4Lean con FFI (Metal GPU):"
echo "  bash buildMetal.sh && LEAN_CC=clang lake build quantum4lean-ffi-metal"
echo "  .lake/build/bin/quantum4lean-ffi-metal"
echo ""
echo "NOTA: Requiere LEAN_CC=clang porque el linker ld64.lld de Lean"
echo "no soporta frameworks Apple (-framework Metal -framework Foundation)."
echo "Metal GPU se activa automaticamente al detectar Apple Silicon."
echo "CPU fallback integrado para Intel Mac y entornos sin GPU."
