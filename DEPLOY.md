# Deployment officedogs.training

> **Status: live seit 04.08.2026.** Repo `doubrawa/officedogs.training` (public),
> GitHub Pages von `main`/root, Custom Domain über die `CNAME`-Datei, Zertifikat
> ausgestellt, Enforce HTTPS aktiv, DNS bei IONOS auf die GitHub-Adressen.
> Die Schritte unten sind ab hier Dokumentation bzw. Referenz für den Wiederaufbau.

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

- ~~Postfach `julia@officedogs.training` einrichten.~~ Erledigt am 04.08.2026.
- ~~E-Mail und Preisangabe im Design korrigieren.~~ Erledigt mit Export v53:
  das Design liefert jetzt selbst `julia@officedogs.training` und den Preis ohne
  MwSt.-Zusatz. Die beiden Korrekturregeln in `_rederive.sh` laufen dadurch
  leer. Sie bleiben trotzdem drin – falls ein späterer Export sie wieder
  einschleppt, fangen sie es ab.
- ~~**Google Search Console**: Property anlegen und Sitemap einreichen.~~
  Erledigt am 05.08.2026. Die Sitemap muss danach **nicht** erneut eingereicht
  werden – Google holt sie von selbst wieder ab. Nur wenn sich ihre URL ändert,
  ist ein neues Einreichen nötig. Um eine geänderte Seite schneller in den
  Index zu bekommen, ist *URL-Prüfung → Indexierung beantragen* der richtige
  Weg, nicht die Sitemap: die meldet, welche Seiten es gibt, nicht dass sich
  eine geändert hat.
- **Impressum ist handgepflegt**, nicht aus dem Design: `impressum/index.html`
  wird von `_rederive.sh` nicht angefasst. Änderungen dort direkt vornehmen.

### Ab 2027 beachten

Julia ist derzeit Kleinunternehmerin nach § 19 UStG – deshalb steht auf der
Seite „649 €" ohne Umsatzsteuer-Zusatz und im Impressum der § 19-Absatz. Ab
2027 wird die Umsatzsteuer relevant. Dann sind **drei** Stellen anzufassen:
Preisangabe (Design), § 19-Absatz im Impressum (→ USt-IdNr.) und der
`price-sub`-Block in `_rederive.sh`.
