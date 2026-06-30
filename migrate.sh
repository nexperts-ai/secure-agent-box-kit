#!/usr/bin/env bash
# Migriert ein lokales Claude-Code-Setup auf eine NEXperts Secure Agent Box (Claude-Paritaet).
# Nutzt soweit moeglich Claude-NATIVE Mechanik (Plugins); Rest custom. KEINE Secrets im Repo.
# Usage: migrate.sh <box-ssh-host>
set -euo pipefail
BOX="${1:?Usage: migrate.sh <box-ssh-host>}"

echo "== Secure Agent Box Migration -> $BOX =="
echo
echo "1) SKILLS (nativ via Plugin) -> auf der Box ausfuehren:"
echo "     claude plugin install https://github.com/nexperts-ai/secure-agent-box-kit"
echo "   Plugins buendeln skills/ und werden beim Start geladen = nativer Verteilweg."
echo
echo "2) MEMORY (nicht nativ syncbar) -> kopieren:"
echo "     scp ~/.claude/CLAUDE.md '$BOX:~/.claude/CLAUDE.md' 2>/dev/null || echo '   (kein ~/.claude/CLAUDE.md)'"
echo "   Projekt-CLAUDE.md/MEMORY.md liegen ohnehin im jeweiligen Repo (git)."
echo
echo "3) LOGIN (per-Maschine, nicht portierbar) -> auf der Box EINMAL:"
echo "     claude        # Browser-Login (oder 'claude setup-token' fuer non-interaktiv)"
echo
echo "4) SECRETS -> im Dashboard (Passwoerter-Page) fuer diese Box hochladen."
echo "   Box-Agent holt sie approval-gated:  orb-secret <KEY> <grund>"
echo "   (Operator gibt in der Agent-Orbit-Bubble frei; ersetzt lokales p2ai/Touch-ID.)"
echo
echo "5) VOKABULAR -> im Dashboard (Vokabular-Page) pro Box pflegen (box-vocab.txt einfuegen)."
echo
echo "Pruefliste (Claude entscheidet je Setup): Skills, CLAUDE.md/MEMORY.md, Vokabular,"
echo "Secret-Zugriff (orb-keystore), Login. Custom-Setups: zusaetzliche skills/ + .mcp.json mitnehmen."
