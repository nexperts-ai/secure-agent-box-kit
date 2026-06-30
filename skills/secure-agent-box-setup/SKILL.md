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
Siehe `migrate.sh`. Ziel: reibungsloser Folgebetrieb auf der Box. Native Claude-Mechanik soweit möglich:
- **Skills**: nativ via Plugin -> auf der Box `claude plugin install https://github.com/nexperts-ai/secure-agent-box-kit` (Plugins bündeln skills/ und werden beim Start geladen).
- **Memory** (nicht nativ syncbar): `~/.claude/CLAUDE.md` + projekt-`CLAUDE.md`/`MEMORY.md` kopieren.
- **Login** (per-Maschine): einmal `claude` auf der Box (Browser-Login).
- **Secrets**: statt lokalem p2ai/Touch-ID -> approval-gated orb-keystore; der Box-Agent holt ein Secret mit `orb-secret <KEY> <grund>`, der Operator gibt in der Agent-Orbit-Bubble frei.

Prüfliste (Claude entscheidet je Setup, was wirklich gebraucht wird): Skills, CLAUDE.md/MEMORY.md, Vokabular, Secret-Zugriff (orb-keystore), Login, ggf. zusätzliche `skills/` + `.mcp.json` bei Custom-Setups.
