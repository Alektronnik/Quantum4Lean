#!/bin/bash
# setup.sh
# Configura el entorno para Quantum4Lean FFI.
# Clona QuantumKit si no existe y compila las librerias.
#
# Uso:
#   bash setup.sh          -- todo (clone + CPU + Metal)
#   bash setup.sh cpu      -- solo CPU
#   bash setup.sh metal    -- solo Metal

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTUMKIT_DIR="$SCRIPT_DIR/../QuantumKit"

echo "=== Quantum4Lean Setup ==="

# 1. Clonar QuantumKit si no existe
if [ ! -d "$QUANTUMKIT_DIR" ]; then
  echo "[1/2] Clonando QuantumKit..."
  cd "$SCRIPT_DIR/.."
  git clone https://github.com/usuario/QuantumKit.git 2>/dev/null || {
    echo "ERROR: No se pudo clonar QuantumKit."
    echo "Asegurate de que el repositorio existe en ../QuantumKit"
    echo "o clonalo manualmente."
    exit 1
  }
else
  echo "[1/2] QuantumKit ya existe en $QUANTUMKIT_DIR"
fi

# 2. Compilar librerias
echo "[2/2] Compilando librerias..."
cd "$SCRIPT_DIR"

MODE="${1:-all}"
case "$MODE" in
  cpu)
    bash buildCPU.sh
    ;;
  metal)
    bash buildMetal.sh
    ;;
  all)
    bash buildCPU.sh
    bash buildFFI.sh
    bash buildMetal.sh
    ;;
  *)
    echo "Uso: bash setup.sh [cpu|metal|all]"
    exit 1
    ;;
esac

echo ""
echo "=== Setup completo ==="
echo "Ahora ejecuta:"
echo "  LEAN_CC=clang lake build quantum4lean-ffi        # CPU"
echo "  LEAN_CC=clang lake build quantum4lean-ffi-metal  # Metal GPU"
