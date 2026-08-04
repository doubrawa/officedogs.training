# Deployment officedogs.training

Einmalige Schritte, um dieses lokale Repo live zu bekommen.

## 1. GitHub-Repo anlegen und pushen

```bash
gh repo create officedogs.training --private --source . --remote origin
git push -u origin main
```

(Oder Repo im Browser anlegen und `git remote add origin …` von Hand.)

## 2. GitHub Pages aktivieren

Repo → **Settings → Pages**

- Source: `Deploy from a branch`
- Branch: `main`, Ordner `/ (root)`
- Custom domain: `officedogs.training` (die `CNAME`-Datei im Repo setzt das
  normalerweise schon automatisch)
- **Enforce HTTPS** anhaken, sobald das Zertifikat ausgestellt ist (dauert nach
  der DNS-Umstellung bis zu einer Stunde)

## 3. DNS beim Registrar

Identisch zu adventuredogs.training – GitHub Pages nutzt für alle Sites
dieselben Adressen:

| Typ   | Name | Wert                |
|-------|------|---------------------|
| A     | @    | 185.199.108.153     |
| A     | @    | 185.199.109.153     |
| A     | @    | 185.199.110.153     |
| A     | @    | 185.199.111.153     |
| AAAA  | @    | 2606:50c0:8000::153 |
| AAAA  | @    | 2606:50c0:8001::153 |
| AAAA  | @    | 2606:50c0:8002::153 |
| AAAA  | @    | 2606:50c0:8003::153 |
| CNAME | www  | doubrawa.github.io  |

Prüfen: `nslookup officedogs.training` muss die vier 185.199.\*-Adressen
liefern.

## 4. Verlinkung von adventuredogs.training

Der Nav-Punkt „OfficeDogs" gehört ins claude.ai/design-Projekt (die Nav steht
auf jeder Seite inline im Export, nicht in der Pipeline). Absolute URL
verwenden – `clean_page` im Hauptrepo schreibt nur `adventuredogs.training`-URLs
um und fasst `officedogs.training` nicht an:

```html
<!-- Desktop: in <ul class="nav-links">, vor dem CTA -->
<li><a href="https://officedogs.training/">OfficeDogs</a></li>

<!-- Mobil: in <div class="nav-mobile">, an gleicher Position -->
<a href="https://officedogs.training/">OfficeDogs</a>
```

## 5. Nach dem Livegang

- Google Search Console: neue Property `officedogs.training`, Sitemap
  `https://officedogs.training/sitemap.xml` einreichen
- Social-Preview testen (og:image liegt unter `/assets/og-office-dogs.jpg`)

## Offen / zu prüfen

- **Postfach `julia@officedogs.training` einrichten.** Die Seite und das
  Impressum nennen diese Adresse. Beim Registrar entweder ein Postfach anlegen
  oder eine Weiterleitung auf `julia@adventuredogs.training` einrichten – ohne
  das laufen alle Anfragen ins Leere.
- **E-Mail im Design korrigieren.** Der claude.ai/design-Export liefert noch
  `info@adventuredogs.training` (existiert nicht). `_rederive.sh` biegt das beim
  Import auf `julia@officedogs.training` um; sobald es im Design gefixt ist,
  läuft das sed einfach leer.
- **Umsatzsteuer klären.** Die Startseite weist „649 € **zzgl. MwSt.**" aus, das
  Impressum nennt die Kleinunternehmerregelung nach § 19 UStG (dann wird gerade
  *keine* Umsatzsteuer ausgewiesen). Beides zusammen passt nicht – entweder den
  Preis auf „649 €" ohne MwSt.-Zusatz ändern (im Design) oder, falls inzwischen
  regelbesteuert, den § 19-Absatz im Impressum durch die USt-IdNr. ersetzen.
- **Impressum ist handgepflegt**, nicht aus dem Design: `impressum/index.html`
  wird von `_rederive.sh` nicht angefasst. Änderungen dort direkt vornehmen.
- **Hauptseite:** Deren Impressum zitiert noch das TMG. Seit Mai 2024 gilt das
  DDG (§ 5 DDG statt § 5 TMG, §§ 7–10 DDG statt TMG). Auf dieser Seite ist es
  schon korrekt; das Hauptrepo müsste bei Gelegenheit nachziehen.
