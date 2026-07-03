#!/bin/bash
# setup.sh
# Configura el entorno para Quantum4Lean FFI.
# Requiere ../QuantumKit con el motor C++. Si no existe:
#   - Clonalo manualmente en ../QuantumKit
#   - O ajusta QUANTUMKIT_DIR abajo
#
# Uso:
#   bash setup.sh          -- CPU + Metal
#   bash setup.sh cpu      -- solo CPU
#   bash setup.sh metal    -- solo Metal

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUANTUMKIT_DIR="$SCRIPT_DIR/../QuantumKit"

echo "=== Quantum4Lean Setup ==="

# 1. Verificar QuantumKit
if [ ! -d "$QUANTUMKIT_DIR" ]; then
  echo "ERROR: QuantumKit no encontrado en $QUANTUMKIT_DIR"
  echo ""
  echo "Quantum4Lean FFI requiere el motor C++ de QuantumKit."
  echo "Clonalo junto a este repositorio:"
  echo "  cd $(dirname "$SCRIPT_DIR")"
  echo "  git clone <url-de-QuantumKit> QuantumKit"
  echo ""
  echo "O ajusta la variable QUANTUMKIT_DIR en este script."
  exit 1
fi
echo "[1/2] QuantumKit encontrado en $QUANTUMKIT_DIR"

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
  *)
    bash buildCPU.sh
    bash buildMetal.sh
    ;;
esac

echo ""
echo "=== Setup completo ==="
echo "Ahora ejecuta:"
echo "  LEAN_CC=clang lake build quantum4lean-ffi        # CPU"
echo "  LEAN_CC=clang lake build quantum4lean-ffi-metal  # Metal GPU"
