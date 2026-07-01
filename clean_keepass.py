#!/usr/bin/env python3
# Cleant eine KeePass-.kdbx und schreibt das Ergebnis in eine SEPARATE neue .kdbx:
# entfernt jeden Eintrag, dessen Passwort in bekannten Datenlecks auftaucht (HIBP Pwned Passwords,
# k-anonymity - es verlaesst NUR der 5-stellige SHA-1-Prefix den Rechner, nie der Wert). Das Original
# bleibt unberuehrt. Fail-open: bei HIBP-Netzfehler wird NICHT gefiltert (Wert gilt als ungeprueft),
# damit ein Ausfall nicht die halbe DB "sauber" leert.
#
# Master NIE ueber argv (ps-sichtbar) - via Env ODER stdin ODER interaktivem Prompt:
#   IN_MASTER  = Master der Quell-.kdbx        (sonst stdin Zeile 1, sonst getpass)
#   OUT_MASTER = Master der neuen sauberen .kdbx (sonst stdin Zeile 2, leer = wie IN_MASTER)
#
# Usage:
#   IN_MASTER=... OUT_MASTER=... ./clean_keepass.py in.kdbx clean.kdbx
#   printf '%s\n%s\n' "$IN" "$OUT" | ./clean_keepass.py in.kdbx clean.kdbx
#
# Exit 0 = saubere Datei geschrieben; 2 = Fehler (Master/Export/Import).
import sys, os, subprocess, tempfile, hashlib, urllib.request, getpass
import xml.etree.ElementTree as ET

def cli():
    for c in (os.environ.get("P2AI_KEEPASSXC_CLI"), os.path.expanduser("~/bin/keepassxc-cli"),
              "/Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli"):
        if c and os.path.exists(c):
            return c
    return "keepassxc-cli"

def hibp_leaked(values, timeout=8):
    by = {}
    for v in set(values):
        if not v:
            continue
        h = hashlib.sha1(v.encode()).hexdigest().upper()
        by.setdefault(h[:5], []).append((h[5:], v))
    leaked = set()
    for pfx, items in by.items():
        try:
            req = urllib.request.Request("https://api.pwnedpasswords.com/range/" + pfx,
                                         headers={"Add-Padding": "true", "User-Agent": "nexperts-box-migrate"})
            body = urllib.request.urlopen(req, timeout=timeout).read().decode()
            hits = {ln.split(":")[0] for ln in body.splitlines() if ln}
            for suf, v in items:
                if suf in hits:
                    leaked.add(v)
        except Exception:
            pass   # fail-open
    return leaked

def _s(entry, key):
    for s in entry.findall("String"):
        k = s.find("Key")
        if k is not None and (k.text or "") == key:
            v = s.find("Value")
            return (v.text or "") if v is not None else ""
    return ""

def main():
    if len(sys.argv) < 3:
        print("Usage: IN_MASTER=.. OUT_MASTER=.. clean_keepass.py <in.kdbx> <clean.kdbx>", file=sys.stderr)
        sys.exit(1)
    ink, outk = sys.argv[1], sys.argv[2]
    if not os.path.exists(ink):
        print("Quelle nicht gefunden: %s" % ink, file=sys.stderr); sys.exit(2)

    stdin_lines = [] if sys.stdin.isatty() else sys.stdin.read().splitlines()
    in_master = os.environ.get("IN_MASTER") or (stdin_lines[0] if len(stdin_lines) > 0 else "") \
        or (getpass.getpass("Master der Quell-.kdbx: ") if sys.stdin.isatty() else "")
    out_master = os.environ.get("OUT_MASTER") or (stdin_lines[1] if len(stdin_lines) > 1 else "") or in_master
    if not in_master:
        print("Kein Master fuer die Quelle.", file=sys.stderr); sys.exit(2)

    C = cli()
    p = subprocess.run([C, "export", "-f", "xml", "-q", ink],
                       input=(in_master + "\n").encode(), capture_output=True, timeout=90)
    if p.returncode != 0:
        print("Export fehlgeschlagen (Master falsch?)", file=sys.stderr); sys.exit(2)
    root = ET.fromstring(p.stdout.decode("utf-8", "replace"))

    entries = [e for g in root.iter("Group") for e in g.findall("Entry")]
    leaked = hibp_leaked([_s(e, "Password") for e in entries if _s(e, "Password")])

    removed = []
    for g in root.iter("Group"):
        for e in list(g.findall("Entry")):
            pw = _s(e, "Password")
            if pw and pw in leaked:
                removed.append(_s(e, "Title") or "?")
                g.remove(e)
    kept = len([e for g in root.iter("Group") for e in g.findall("Entry")])

    tmpx = tempfile.NamedTemporaryFile(suffix=".xml", delete=False)
    try:
        tmpx.write(b"<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n")
        tmpx.write(ET.tostring(root, encoding="utf-8"))
        tmpx.close()
        if os.path.exists(outk):
            os.remove(outk)                     # import legt neu an; altes Ziel weg
        ip = subprocess.run([C, "import", "-p", tmpx.name, outk],   # -p: Master der neuen DB via stdin
                            input=(out_master + "\n" + out_master + "\n").encode(),
                            capture_output=True, timeout=90)
        if ip.returncode != 0:
            print("Import in neue .kdbx fehlgeschlagen: %s" % ip.stderr.decode("utf-8", "replace")[-200:], file=sys.stderr)
            sys.exit(2)
    finally:
        try:
            with open(tmpx.name, "wb") as f:    # XML hatte Klartext -> ueberschreiben + loeschen
                f.write(b"\x00" * 4096)
            os.remove(tmpx.name)
        except Exception:
            pass

    # Report: NUR Namen/Zahlen, nie Werte.
    print("sauber geschrieben: %s" % outk)
    print("uebernommen: %d Eintraege" % kept)
    print("gefiltert (geleakt): %d%s" % (len(removed), (" -> " + ", ".join(removed[:20])) if removed else ""))

if __name__ == "__main__":
    main()
