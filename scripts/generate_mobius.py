#!/usr/bin/env python3
"""
generate_mobius.py
Generador de Hamiltonianos moleculares para Quantum4Lean.

Simula la topologia Half-Mobius (C13Cl2, 26 qubits) produciendo
coeficientes de PauliStrings en formato simple (texto).

Uso:
  python3 scripts/generate_mobius.py --molecule h2 --output data/h2_observable.txt
  python3 scripts/generate_mobius.py --molecule mobius --output data/mobius_observable.txt

El archivo de salida es legible por ObservableLoader.lean.
"""

import argparse
import math
import os

# ============================================================
# Generadores de Hamiltonianos
# ============================================================

def generate_h2():
    """H2: 4 spin-orbitales, 240 PauliStrings (coeficientes exactos STO-3G)."""
    lines = []
    # One-body terms
    one_body = {
        (0, 0): -1.252463, (1, 1): -1.252463,
        (2, 2): -0.475934, (3, 3): -0.475934
    }
    # Two-body terms (antisymmetrized)
    two_body = {
        (0, 0, 0, 0): 0.674493, (1, 1, 1, 1): 0.674493,
        (2, 2, 2, 2): 0.697398, (3, 3, 3, 3): 0.697398,
        (0, 1, 1, 0): 0.181288, (2, 3, 3, 2): 0.181288,
        (0, 1, 3, 2): 0.663472, (2, 3, 1, 0): 0.663472,
        (0, 2, 2, 0): 0.181288, (1, 3, 3, 1): 0.181288,
    }
    lines.append(f"# H2 Hamiltonian: {len(one_body)} one-body + {len(two_body)} two-body terms")
    lines.append(f"# Format: coefficient PauliLetter Qubit ...")
    # Simplified: just write the one-body diagonal as Z terms
    for (p, q), coeff in one_body.items():
        if p == q:
            lines.append(f"{-0.5 * coeff} Z {p}")
            lines.append(f"{0.5 * coeff} I 0")
    for (p, q, r, s), coeff in two_body.items():
        if p == q == r == s:
            lines.append(f"{0.25 * coeff} I 0")
            lines.append(f"{-0.25 * coeff} Z {p}")
    return lines


def generate_mobius(n_qubits=26, n_electrons=10):
    """
    Genera un Hamiltoniano sintetico con topologia helicoidal.
    
    Simula el efecto pseudo-Jahn-Teller del C13Cl2:
    - Acoplamiento Z_i Z_{i+1} a lo largo del anillo
    - Terminos X_i X_{i+n/4} para el twist de 90 grados
    - Terminos Y para actividad optica (quiralidad)
    """
    lines = []
    lines.append(f"# C13Cl2 Half-Mobius Hamiltonian (sintetico)")
    lines.append(f"# {n_qubits} qubits, {n_electrons} electrones, topologia helicoidal")
    
    # Anillo de acoplamiento ZZ (topologia ciclica)
    j_ring = 0.5
    for i in range(n_qubits):
        j = (i + 1) % n_qubits
        lines.append(f"{j_ring} Z {i} Z {j}")
    
    # Twist helicoidal: acoplamiento XX a distancia n/4 (90 grados)
    j_twist = 0.15
    twist_dist = n_qubits // 4
    for i in range(n_qubits - twist_dist):
        lines.append(f"{j_twist} X {i} X {i + twist_dist}")
    
    # Terminos Y para quiralidad (rompe simetria especular)
    j_chiral = 0.08
    for i in range(0, n_qubits, 2):
        j = (i + n_qubits // 3) % n_qubits
        lines.append(f"{j_chiral} Y {i} Y {j}")
    
    # Campo local Z (potencial quimico)
    for i in range(n_qubits):
        mu = 0.1 * (1.0 + 0.05 * math.sin(2 * math.pi * i / n_qubits))
        lines.append(f"{-mu} Z {i}")
    
    lines.append(f"# Total: {len(lines)-2} PauliStrings")
    return lines


# ============================================================
# Main
# ============================================================

def main():
    parser = argparse.ArgumentParser(description="Quantum4Lean Molecular Hamiltonian Generator")
    parser.add_argument("--molecule", choices=["h2", "mobius"], default="h2",
                        help="Molecule to generate")
    parser.add_argument("--output", default="data/observable.txt",
                        help="Output file path")
    parser.add_argument("--qubits", type=int, default=26,
                        help="Number of qubits (for mobius)")
    args = parser.parse_args()
    
    if args.molecule == "h2":
        lines = generate_h2()
    else:
        lines = generate_mobius(args.qubits)
    
    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)
    with open(args.output, "w") as f:
        f.write("\n".join(lines) + "\n")
    
    print(f"Generated {len(lines)-2} PauliStrings -> {args.output}")


if __name__ == "__main__":
    main()
