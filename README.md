# officedogs.training

Landing Page für **Office Dogs** – Bürohunde-Beratung für Unternehmen
(Julia Doubrawa, Adventure Dogs).

Statische Single-Page-Site auf GitHub Pages, eigene Domain, eigenes Logo und
eigenes Farbschema. Inhaltlich und technisch getrennt von
[adventuredogs.training](https://adventuredogs.training/), inhaltlich aber
verlinkt (Nav-Punkt „OfficeDogs" dort, Footer-Links hierher zurück).

## Quelle der Seite

**`index.html` ist die Quelle und wird hier von Hand gepflegt.**

Das war bis zum 13.08.2026 andersherum: Single Source of Truth war das
claude.ai/design-Projekt „Adventure Dogs Training", Seite „Office Dogs Vollbild
Logo", und `_rederive.sh` erzeugte `index.html` daraus. Am 12.08.2026 wurde der
Seitentext in vier Commits direkt hier überarbeitet – neuer Hero, neue
Mehrwert-Kacheln, ein komplett neuer Abschnitt (der Fragenblock `.fit`), neue
Ablauf-Schritte, neuer Preiszusatz. Nichts davon steht im Design-Projekt.

Ein Lauf der alten Pipeline hätte das **fehlerfrei und wortlos** überschrieben
(nachgemessen: 139 Zeilen). Deshalb kann `_rederive.sh` `index.html` heute nicht
mehr schreiben – siehe unten.

Von Hand gepflegt sind damit: `index.html`, `impressum/index.html` und der
One-Pager unter `tools/onepager/`. Aus dem Design kommen nur noch **Bilder und
Logo-SVG**.

## Pflegelauf und Import

```bash
bash tools/_rederive.sh            # Pflege: Bilder, Logo-SVG, sitemap.xml
bash tools/_rederive.sh --import   # neuen Design-Export zum Vergleichen bauen
```

Der **Pflegelauf** fasst `index.html` nicht an. Er erneuert die Bilder aus dem
Export (`tools/optimize-images.ps1`: Hero-PNG 1,9 MB → JPG ~140 KB, Portrait
runterskalieren, og:image 1200×630), optimiert das Logo-SVG mit scour und
schreibt `sitemap.xml`. Ohne vorhandenen Export läuft er trotzdem – dann nur die
Sitemap.

Der **Import** baut den Export nach `index.neu.html` (gitignoriert) und meldet,
wie viele Zeilen nur in der einen bzw. nur in der anderen Datei stehen.
`index.html` wird dabei nicht angefasst – nicht per Prüfung, sondern weil es den
Schreibpfad nicht mehr gibt. Übernommen wird von Hand:

```bash
# 1. "Adventure Dogs Training.zip" nach C:/DATA/Claude/design-extract-vN entpacken
# 2. SRC in tools/_rederive.sh auf design-extract-vN setzen
bash tools/_rederive.sh --import
diff index.html index.neu.html      # 3. übernehmen, was gewollt ist
rm index.neu.html                   # 4. aufräumen, committen, pushen
```

Die Korrekturen, die der Import auf den Export anwendet, bleiben dokumentiert –
sie beschreiben, was das Design-Tool systematisch anders ausgibt, als die Site
es braucht: Querverweise auf absolute `adventuredogs.training`-URLs (Ausnahme:
Impressum/Datenschutz zeigen nach innen auf `/impressum/`), `#kontakt`-Anker auf
die echte Kontaktseite, Titel und Description auf Suchergebnis-Länge,
`info@adventuredogs.training` → `julia@officedogs.training`, Bildpanel statt
Portrait-Kreis, `<main>`-Landmark, canonical/OpenGraph/Twitter-Card sowie das
Schema.org-`ProfessionalService` (Rumpf in `tools/schema.json.html`, Angebot und
Preis liest `tools/build-schema.py` aus der Seite).

## Deployment

GitHub Pages, Branch `main`, Root. `CNAME` hält die Custom Domain.
DNS zeigt auf die GitHub-Pages-IPs (identisch zu adventuredogs.training).
