#!/usr/bin/env bash
# Agent-operable Migration eines LOKALEN Claude-Code-Setups -> NEXperts Secure Agent Box.
#
# Gedacht, damit ein LOKALER Agent (Claude) es SELBST ausfuehren, die Vollstaendigkeit
# VERIFIZIEREN und bei Bedarf ergaenzen kann - nicht nur ein Mensch-Guide. Kopiert die
# datei-portierbaren Teile (Skills, Agents, Memory, Settings, MCP-Config), prueft die
# nicht-portierbaren (Login, Secrets, Vokabular) und druckt am Ende einen maschinen-lesbaren
# Vollstaendigkeits-Report (PIECE<TAB>STATUS<TAB>DETAIL). Idempotent (mehrfach ausfuehrbar).
#
# KEINE Geheimnisse: Secrets gehen NIE per scp, sondern ueber das Dashboard (orb-keystore),
# das leaked/kompromittierte Keys vorher rausfiltert (HIBP k-anonymity).
#
# Usage:
#   SSH_KEY=~/.ssh/hetzner_crown ./migrate.sh oliver@1.2.3.4 [--dry-run] [--with-sessions]
#     --dry-run        nichts schreiben, nur zeigen + lokalen Bestand reporten
#     --with-sessions  auch ~/.claude/projects (Conversation-History, ggf. sehr gross) kopieren
#
# Exit 0 wenn alle PFLICHT-Teile OK/geliefert (skills, agents, memory, settings, mcp),
# sonst 2. Guide-Teile (login/secrets/vocab) senken den Exit nicht, erscheinen aber im Report.
set -uo pipefail

SSH_T="${1:?Usage: SSH_KEY=<key> migrate.sh <user@host> [--dry-run] [--with-sessions]}"; shift || true
DRY=0; WITH_SESSIONS=0
for a in "$@"; do case "$a" in
  --dry-run) DRY=1;; --with-sessions) WITH_SESSIONS=1;;
  *) echo "unbekannte Option: $a" >&2; exit 1;; esac; done

KEY_OPT=""; [ -n "${SSH_KEY:-}" ] && KEY_OPT="-i ${SSH_KEY}"
SSHB() { ssh $KEY_OPT -o ConnectTimeout=12 -o BatchMode=yes "$SSH_T" "$@"; }
RSYNCB() { rsync -az ${KEY_OPT:+-e "ssh $KEY_OPT -o BatchMode=yes"} "$@"; }
LC="$HOME/.claude"

declare -a REPORT
add() { REPORT+=("$1"$'\t'"$2"$'\t'"$3"); }        # piece status detail
step() { printf '\n== %s ==\n' "$*"; }
info() { printf '   %s\n' "$*"; }
do_or_show() { if [ "$DRY" = 1 ]; then info "[dry-run] $*"; else eval "$@"; fi; }

printf '===== Claude-Box-Migration -> %s %s=====\n' "$SSH_T" "$([ "$DRY" = 1 ] && echo '(DRY-RUN) ')"

# ---- 0) Preflight ---------------------------------------------------------
step "0) Preflight"
if ! SSHB true 2>/dev/null; then echo "FEHLER: Box nicht erreichbar ($SSH_T; SSH_KEY=${SSH_KEY:-<none>})"; exit 1; fi
BOX_HOME=$(SSHB 'printf %s "$HOME"'); BOX_USER=$(SSHB 'whoami')
BOX_CLAUDE=$(SSHB 'command -v claude 2>/dev/null || echo MISSING')
BOX_SLUG=$(printf '%s' "$BOX_HOME" | sed 's#/#-#g')     # cwd-slug fuer den Memory-Pfad
info "user=$BOX_USER  home=$BOX_HOME  claude=$BOX_CLAUDE  memory-slug=$BOX_SLUG"
[ "$BOX_CLAUDE" = MISSING ] && add claude MISSING "claude nicht auf der Box (cloud-init/plugin pruefen)" || add claude OK "$BOX_CLAUDE"

# ---- 1) Skills ------------------------------------------------------------
step "1) Skills (~/.claude/skills)"
LN=$(ls "$LC/skills" 2>/dev/null | wc -l | tr -d ' ')
if [ "${LN:-0}" -gt 0 ]; then
  do_or_show "SSHB 'mkdir -p ~/.claude/skills'"
  do_or_show "RSYNCB '$LC/skills/' '$SSH_T:.claude/skills/'"
  if [ "$DRY" = 1 ]; then add skills DRY "$LN lokal"; else
    BN=$(SSHB 'ls ~/.claude/skills 2>/dev/null | wc -l' | tr -d ' ')
    info "lokal=$LN  box=$BN"
    [ "${BN:-0}" -ge "$LN" ] && add skills OK "$BN/$LN" || add skills PARTIAL "$BN/$LN"
  fi
else add skills SKIP "keine lokalen Skills"; fi

# ---- 2) Agents ------------------------------------------------------------
step "2) Agents (~/.claude/agents)"
if [ -d "$LC/agents" ] && [ -n "$(ls -A "$LC/agents" 2>/dev/null)" ]; then
  LA=$(ls "$LC/agents" 2>/dev/null | wc -l | tr -d ' ')
  do_or_show "SSHB 'mkdir -p ~/.claude/agents'"
  do_or_show "RSYNCB '$LC/agents/' '$SSH_T:.claude/agents/'"
  if [ "$DRY" = 1 ]; then add agents DRY "$LA lokal"; else
    BA=$(SSHB 'ls ~/.claude/agents 2>/dev/null | wc -l' | tr -d ' '); info "lokal=$LA box=$BA"
    [ "${BA:-0}" -ge "$LA" ] && add agents OK "$BA/$LA" || add agents PARTIAL "$BA/$LA"
  fi
else add agents SKIP "keine lokalen Agents"; fi

# ---- 3) Memory (per Projekt-Slug, wird auf den Box-Slug gemappt) ----------
step "3) Memory (Knowledge-Graph)"
# Der HAUPT-Graph liegt unter dem Home-Slug (== was fuer die Home-cwd auto-laedt), nicht irgendeiner
# Projekt-Slug. Zuerst den nehmen, sonst die erste memory/ mit MEMORY.md als Fallback.
LOCAL_SLUG=$(printf '%s' "$HOME" | sed 's#/#-#g')
MEMSRC=""
[ -f "$LC/projects/$LOCAL_SLUG/memory/MEMORY.md" ] && MEMSRC="$LC/projects/$LOCAL_SLUG/memory"
[ -z "$MEMSRC" ] && for d in "$LC"/projects/*/memory; do [ -d "$d" ] && [ -f "$d/MEMORY.md" ] && MEMSRC="$d" && break; done
if [ -n "$MEMSRC" ]; then
  MEMDST=".claude/projects/$BOX_SLUG/memory"
  MN=$(find "$MEMSRC" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')
  info "quelle=$MEMSRC ($MN .md)  ->  box:~/$MEMDST"
  do_or_show "SSHB 'mkdir -p ~/$MEMDST'"
  do_or_show "RSYNCB '$MEMSRC/' '$SSH_T:$MEMDST/'"
  if [ "$DRY" = 1 ]; then add memory DRY "$MN Dateien"; else
    BM=$(SSHB "ls ~/$MEMDST/*.md 2>/dev/null | wc -l" | tr -d ' ')
    [ "${BM:-0}" -ge "$MN" ] && add memory OK "$BM/$MN -> $BOX_SLUG" || add memory PARTIAL "$BM/$MN"
  fi
else add memory SKIP "kein lokaler memory/MEMORY.md gefunden"; fi

# ---- 4) Settings (MERGE, ueberschreibt NICHT die Box-Hooks/Bypass) --------
step "4) Settings (merge, Box-Hooks bleiben)"
if [ -f "$LC/settings.json" ]; then
  L64=$(base64 < "$LC/settings.json" | tr -d '\n')
  if [ "$DRY" = 1 ]; then info "[dry-run] settings mergen"; add settings DRY "lokal vorhanden"; else
    OUT=$(SSHB "L64='$L64' python3 - <<'PY'
import json,os,base64
p=os.path.expanduser('~/.claude/settings.json')
box=json.load(open(p)) if os.path.exists(p) else {}
loc=json.loads(base64.b64decode(os.environ['L64']))
box_hooks=box.get('hooks')
box.update({k:v for k,v in loc.items() if k!='hooks'})   # lokale Prefs, aber hooks NICHT ueberschreiben
if box_hooks: box['hooks']=box_hooks                     # Box-Hooks (Rueckfrage) behalten
os.makedirs(os.path.dirname(p),exist_ok=True); json.dump(box,open(p,'w'),indent=2)
print('OK keys=%d hooks_preserved=%s'%(len(box), bool(box_hooks)))
PY" 2>&1)
    info "$OUT"; case "$OUT" in OK*) add settings OK "${OUT#OK }";; *) add settings PARTIAL "$OUT";; esac
  fi
else add settings SKIP "keine lokale settings.json"; fi

# ---- 5) MCP-Config (Server-Definitionen; Auth ggf. per-Maschine neu) ------
step "5) MCP (~/.claude/mcp.json / .mcp.json)"
MCPSRC=""; for f in "$LC/mcp.json" "$LC/.mcp.json"; do [ -f "$f" ] && MCPSRC="$f" && break; done
if [ -n "$MCPSRC" ]; then
  do_or_show "RSYNCB '$MCPSRC' '$SSH_T:.claude/$(basename "$MCPSRC")'"
  if [ "$DRY" = 1 ]; then add mcp DRY "$(basename "$MCPSRC")"; else
    SRV=$(SSHB "python3 -c \"import json,os;p=os.path.expanduser('~/.claude/$(basename "$MCPSRC")');print(len((json.load(open(p)).get('mcpServers') or {})) if os.path.exists(p) else 0)\"" 2>/dev/null)
    add mcp OK "$SRV Server (Auth ggf. auf der Box neu noetig)"
  fi
else add mcp SKIP "keine MCP-Config"; fi

# ---- 6) Sessions (optional, gross) ----------------------------------------
step "6) Sessions/History (~/.claude/projects) ${WITH_SESSIONS:+[--with-sessions]}"
if [ "$WITH_SESSIONS" = 1 ] && [ -d "$LC/projects" ]; then
  SZ=$(du -sh "$LC/projects" 2>/dev/null | cut -f1)
  info "kopiere $SZ (kann dauern)"
  do_or_show "RSYNCB '$LC/projects/' '$SSH_T:.claude/projects/'"
  add sessions "$([ "$DRY" = 1 ] && echo DRY || echo OK)" "$SZ"
else add sessions SKIP "ohne --with-sessions uebersprungen"; fi

# ---- 7) Login (per-Maschine, nicht portierbar) - nur PRUEFEN --------------
step "7) Login (per-Maschine)"
if [ "$BOX_CLAUDE" != MISSING ]; then
  LI=$(SSHB "bash -lc 'claude auth status 2>/dev/null || claude whoami 2>/dev/null'" 2>/dev/null | grep -iE 'loggedIn|email|true' | head -1)
  if [ -n "$LI" ]; then add login OK "Box ist eingeloggt"; info "eingeloggt"
  else add login TODO "auf der Box: 'claude' (Browser) ODER 'claude setup-token'"; info "NICHT eingeloggt -> manueller Schritt"; fi
else add login TODO "claude fehlt -> erst installieren"; fi

# ---- 8) Secrets (NIE per scp -> Dashboard/orb-keystore, leaked gefiltert) -
step "8) Secrets (orb-keystore, leaked-gefiltert)"
ORB=$(SSHB 'systemctl is-active orb-keystore 2>/dev/null || echo inactive')
HERE_DIR=$(cd "$(dirname "$0")" && pwd)
if [ "$ORB" = active ]; then
  add secrets TODO "orb-keystore aktiv -> KeePass im Dashboard hochladen (leaked wird beim Import gefiltert). Vorher optional saeubern: clean_keepass.py in.kdbx clean.kdbx"
  info "orb-keystore aktiv. Saubere Passwort-DB erzeugen (leaked raus, separate Datei):"
  info "  IN_MASTER=... OUT_MASTER=... python3 '$HERE_DIR/clean_keepass.py' <deine.kdbx> box-clean.kdbx"
  info "  dann box-clean.kdbx im Dashboard (Passwoerter -> KeePass) fuer diese Box hochladen."
else add secrets TODO "orb-keystore inaktiv -> install.sh/cloud-init pruefen, dann Dashboard-Upload"; info "orb-keystore inaktiv"; fi

# ---- 9) Vokabular (Voice-Glossar, Dashboard-seitig) - HINWEIS -------------
step "9) Vokabular (Voice-Glossar)"
add vocab TODO "im Dashboard (Vokabular-Page) pro Box pflegen (box-vocab.txt einfuegen)"

# ---- Report ---------------------------------------------------------------
step "REPORT"
printf 'PIECE\tSTATUS\tDETAIL\n'
FAIL=0
for r in "${REPORT[@]}"; do
  printf '%s\n' "$r"
  st=$(printf '%s' "$r" | cut -f2)
  case "$st" in PARTIAL|MISSING) FAIL=1;; esac
done
echo
if [ "$DRY" = 1 ]; then echo "DRY-RUN fertig (nichts geschrieben)."; exit 0; fi
if [ "$FAIL" = 1 ]; then echo "UNVOLLSTAENDIG: mind. ein PFLICHT-Teil PARTIAL/MISSING (siehe Report)."; exit 2; fi
echo "OK: alle datei-portierbaren Teile geliefert. Offene TODO-Teile (login/secrets/vocab) im Report."
exit 0
