# officedogs.training

Landing Page für **Office Dogs** – Bürohunde-Beratung für Unternehmen
(Julia Doubrawa, Adventure Dogs).

Statische Single-Page-Site auf GitHub Pages, eigene Domain, eigenes Logo und
eigenes Farbschema. Inhaltlich und technisch getrennt von
[adventuredogs.training](https://adventuredogs.training/), inhaltlich aber
verlinkt (Nav-Punkt „OfficeDogs" dort, Footer-Links hierher zurück).

## Quelle der Seite

Die Seite wird **nicht hier von Hand editiert**. Single Source of Truth ist das
claude.ai/design-Projekt „Adventure Dogs Training", Seite **„Office Dogs
Vollbild Logo"** – dasselbe Projekt, aus dem auch das Hauptrepo gespeist wird.

## Import eines neuen Exports

```bash
# 1. "Adventure Dogs Training.zip" nach C:/DATA/Claude/design-extract-vN entpacken
# 2. SRC in tools/_rederive.sh auf design-extract-vN setzen
bash tools/_rederive.sh
# 3. Diff prüfen, committen, pushen
```

`_rederive.sh` erledigt:

- `Office Dogs Vollbild Logo.html` → `index.html`
- Querverweise (`Landing Page.html`, `Kontakt.html`, `Impressum.html` …) auf
  absolute `https://adventuredogs.training/…`-URLs umbiegen – relative Pfade
  laufen von dieser Domain aus ins Leere
- `tools/optimize-images.ps1` (Hero-PNG 1,9 MB → JPG ~140 KB, Portrait
  runterskalieren, og:image 1200×630 erzeugen)
- canonical / OpenGraph / Twitter-Card injizieren
- `tools/schema.json.html` (Schema.org ProfessionalService) einhängen
- `sitemap.xml` neu schreiben

## Deployment

GitHub Pages, Branch `main`, Root. `CNAME` hält die Custom Domain.
DNS zeigt auf die GitHub-Pages-IPs (identisch zu adventuredogs.training).
