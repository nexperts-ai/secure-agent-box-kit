# secure-agent-box-kit

Bringt dein lokales Claude-Code-Setup auf eine **NEXperts Secure Agent Box**, damit Claude dort so gut läuft wie lokal.

## Installieren (nativ, als Claude-Plugin)
Claude-Code-Plugins kommen aus einem Marketplace. Dieses Repo ist sein eigener Marketplace, also zwei Schritte auf der Box:
```
claude plugin marketplace add nexperts-ai/secure-agent-box-kit
claude plugin install secure-agent-box-kit@secure-agent-box-kit
```
Lädt die Skills automatisch beim Start. In einer laufenden Claude-Session gehen auch die Slash-Varianten `/plugin marketplace add nexperts-ai/secure-agent-box-kit` und `/plugin install secure-agent-box-kit@secure-agent-box-kit`.

## Was drin ist
- **Skill `secure-agent-box-setup`** — erstellt strukturiert:
  - die **Passwort-Upload-Datei** (Secrets als `.env`/JSON) für die orb-keystore Passwort-Page,
  - die **Vokabular-Datei** (Voice-Glossar pro Box) für die Vokabular-Page.
- **`migrate.sh`** — agent-operable, idempotente Migration: kopiert Skills/Agents/Memory/Settings/MCP (home-slug-gemappt, Box-Hooks bleiben), legt eine Box-Kontext-Memory-Notiz an und druckt einen maschinen-lesbaren Report (`PIECE<TAB>STATUS<TAB>DETAIL`). Login/Secrets/Vokabular sind der manuelle Handoff.

## Migration starten
Am einfachsten über das Dashboard: auf der Karte der Ziel-Box **Migrieren** klicken. Das Modal zeigt eine Live-Dry-Run-Vorschau und gibt einen fertigen **Agent-Prompt** zum Kopieren, der einen lokalen Claude die Migration fahren lässt (Dry-Run -> Opt-out -> scharf -> Verifikation). Direkt geht auch:
```
SSH_KEY=~/.ssh/hetzner_<box> bash ~/secure-agent-box-kit/migrate.sh <user>@<host> --dry-run
```

## Ziel
Reibungsloser Folgebetrieb auf der Agenten-Box statt lokal: Skills, Memory, Vokabular und Secret-Zugriff verfügbar — Secrets approval-gated über orb-keystore statt Touch-ID/p2ai.

## Sicherheit
Keine echten Geheimnisse in dieses Repo committen. Die Passwort-Upload-Datei bleibt lokal und wird nur im Dashboard hochgeladen (danach löschen).
