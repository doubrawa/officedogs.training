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

- **Eigenes Impressum:** Der Footer verlinkt aktuell auf
  `adventuredogs.training/impressum/`. Die Betreiberin ist im Footer genannt und
  das Impressum ist mit einem Klick erreichbar; ein eigenes `/impressum/` auf
  dieser Domain wäre trotzdem die sicherere Variante.
- **E-Mail-Adresse:** Die Seite verwendet `info@adventuredogs.training`, der
  Hauptbetrieb `julia@adventuredogs.training`. Sicherstellen, dass `info@`
  wirklich zugestellt wird.
