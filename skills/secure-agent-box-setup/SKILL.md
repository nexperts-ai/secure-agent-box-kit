---
name: secure-agent-box-setup
description: Erzeugt strukturiert die zwei Dateien, die eine NEXperts Secure Agent Box braucht, und führt durch die Migration eines lokalen Claude-Setups auf die Box. (1) Passwort-Upload-Datei (.env/JSON mit KEY=VALUE Secrets) für die orb-keystore Passwort-Page; (2) Vokabular-Datei (Begriffe pro Box) für das Voice-Cleanup-Glossar. Nutze bei: "Passwort-Datei für die Box", "Secrets für orb-keystore vorbereiten", "Vokabular/Glossar für die Box erstellen", "Box-Setup-Dateien", "lokales Setup auf die Agent-Box migrieren". Triggers: secure agent box, orb-keystore, Passwort-Upload, Vokabular pro Box, Box-Migration, Claude auf der Box.
---

# Secure Agent Box Setup

Erstellt die Setup-Dateien strukturiert. WICHTIG: Lade NIE echte Geheimnisse in ein Repo — die Passwort-Datei bleibt lokal und wird nur im Dashboard hochgeladen, danach löschen.

## 1. Passwort-Upload-Datei (Secrets -> orb-keystore)
Format: flaches `KEY=VALUE` (.env) ODER JSON `{"KEY":"VALUE"}`. Im Dashboard pro Box unter **Passwörter -> Datei einlesen** hochladen; dort per Opt-out wählen, welche Keys wirklich auf die Box gehen. Verschlüsselt Mac-seitig mit dem Box-Master, nur secrets.enc landet auf der Box.

Vorgehen:
1. Frage den Nutzer, welche Dienste die Box-Agenten brauchen (z.B. OpenAI, Supabase, Lemlist).
2. Schreibe `box-secrets.env` mit `DIENST_KEY=<wert>`-Zeilen (Werte vom Nutzer, nie raten/erfinden).
3. Nach dem Upload: `rm box-secrets.env`.

## 2. Vokabular-Datei (Voice-Glossar pro Box)
Format: ein Begriff pro Zeile (oder kommagetrennt). Im Dashboard pro Box unter **Vokabular** einfügen.

Vorgehen:
1. Sammle Eigennamen / Fachbegriffe / Produktnamen / Abkürzungen, die in Diktaten an diese Box vorkommen.
2. Schreibe `box-vocab.txt`, ein Begriff pro Zeile.

## 3. Migration lokal -> Box (Claude-Parität)
**Einstieg (empfohlen):** im Dashboard auf der Karte der Ziel-Box **Migrieren** klicken. Das Modal zeigt eine Live-Dry-Run-Vorschau (was ginge auf die Box) und liefert einen fertigen, auf die Box zugeschnittenen **Agent-Prompt** zum Kopieren. Diesen Prompt in eine lokale Claude-Session einfügen; der Agent fährt dann selbst: Dry-Run -> Opt-out -> scharf -> Verifikation.

Darunter liegt `migrate.sh` (agent-operabel, idempotent). Aufruf:
```
SSH_KEY=~/.ssh/hetzner_<box> bash ~/secure-agent-box-kit/migrate.sh <user>@<host> [--dry-run] [--with-sessions]
```
Es kopiert die datei-portierbaren Teile und druckt am Ende einen maschinen-lesbaren Report `PIECE<TAB>STATUS<TAB>DETAIL` (Status: OK / PARTIAL / MISSING / SKIP / DRY / TODO). Pflicht-Teile (skills, agents, memory, settings, mcp) gaten den Exit; TODO-Teile (login, secrets, vocab) sind der manuelle Handoff.

- **Skills/Agents/Settings/MCP**: kopiert `migrate.sh` (rsync); Settings-Merge lässt Box-Hooks unangetastet. Zusätzlich nativ als Plugin verfügbar: `claude plugin marketplace add nexperts-ai/secure-agent-box-kit` + `claude plugin install secure-agent-box-kit@secure-agent-box-kit`.
- **Memory**: `migrate.sh` kopiert den Knowledge-Graph home-slug-gemappt und legt eine Box-Kontext-Notiz (`reference_secure_agent_box_context.md`) + MEMORY.md-Pointer an, damit der Box-Claude weiß, dass er auf einer Secure Agent Box läuft (Report-Piece `memctx`).
- **Login** (per-Maschine): einmal `claude` auf der Box (Browser-Login) ODER `claude setup-token`.
- **Secrets**: statt lokalem p2ai/Touch-ID -> approval-gated orb-keystore; der Box-Agent holt ein Secret mit `orb-secret <KEY> <grund>`, der Operator gibt in der Agent-Orbit-Bubble frei. KeePass über die Passwörter-Seite der Box hochladen (Leaked per HIBP gefiltert).

Prüfliste (Claude entscheidet je Setup, was wirklich gebraucht wird): Skills, Agents, MEMORY.md + Box-Kontext-Notiz, Settings, MCP, Vokabular, Secret-Zugriff (orb-keystore), Login.
