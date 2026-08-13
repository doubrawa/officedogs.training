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

## 5. One-Pager als PDF

`assets/office-dogs-onepager.pdf` ist **ein** Blatt im Design der Site, gedacht
zum Versenden per Mail. Quelle ist `tools/onepager/onepager.html`, gebaut wird
mit:

```bash
powershell -ExecutionPolicy Bypass -File tools\build-onepager.ps1
```

Das Skript rendert mit headless Chrome, prüft danach die Seitenzahl und bricht
ab, wenn der Inhalt auf eine zweite Seite gelaufen ist. Mit `-Preview` legt es
zusätzlich ein PNG daneben (braucht Python mit `pypdfium2`).

**Das Blatt ist seit dem 11.08.2026 kein A4 mehr, sondern 210 mm × 1218 pt**
(= 429,6 mm). Die Breite bleibt A4, damit es beim Ausdrucken sauber
herunterskaliert; die Höhe ist am Inhalt gemessen. Der überarbeitete Text
braucht 1607 statt 1108 px – auf 297 mm hätte ihn nur ein deutlich engerer Satz
gebracht (kleinere Schriftgrade, kürzeres Hero, weniger Luft), und das war die
Sache nicht wert.

Der maßgebliche Wert steht in `onepager.html`, nicht hier: diese Datei hat die
Höhe schon einmal überlebt, ohne mitzuwandern (sie nannte 1212 pt, während die
Quelle längst auf 1194 stand). Im Zweifel gilt die `@page`-Regel.

Dass die Höhe in **Punkt** steht und nicht in Millimetern, ist kein Schönheits-
fehler: mit „359mm" schloss das PDF in manchen Betrachtern unten mit einem
weißen Strich ab. Chrome rastert die Papiergröße auf 0,24 pt; aus 359 mm wurde
eine Seite von 1018,08 pt, gemalt wurde aber nur bis zur vollen CSS-Pixelzeile,
und die 0,44 px Rest blieben unbemalt. Aus CSS ist dieser Streifen nicht
erreichbar – weder mit einem Überstand unter dem Fußband noch über den
Seitenhintergrund, beides ausprobiert. Die Höhe muss deshalb ein **Vielfaches
von 6 pt** sein (dann geht sie glatt in CSS-Pixel auf); `build-onepager.ps1`
prüft das und bricht sonst mit dem passenden Vorschlag ab.

Daraus folgt eine Pflicht bei jeder Textänderung: **wird der Text länger, muss
die Blatthöhe mitwachsen.** Sie steht an zwei Stellen in `onepager.html`, in der
`@page`-Regel und in `html,body` – beide müssen denselben Wert tragen. Wie man
den neuen Wert misst, steht im Kommentarkopf der Datei.

Vergisst man `@page`, meldet `build-onepager.ps1` die zweite Seite und bricht
ab. Vergisst man `html,body`, merkt es **niemand**: nachgemessen läuft der Build
mit 297 gegen 368 mm ohne Murren durch (das Blatt war zum Zeitpunkt des Tests
368 mm hoch). Das Papierformat hängt allein an
`@page`; `html,body` entscheidet nur darüber, ob das Fußband per `margin-top:auto`
an den Blattfuß gedrückt wird. Zu klein gesetzt fällt es einfach dorthin, wo der
Text endet – bei den derzeit rund 17 px Reserve unsichtbar, bei mehr Luft nicht.

Wichtig: das Blatt kommt **nicht** aus dem claude.ai/design-Projekt und wird von
`_rederive.sh` nicht angefasst — ein neuer Export lässt es unverändert. Farben,
Schriften und Bausteine sind aus `index.html` abgeschrieben. Wer die Palette
oder die Texte der Site ändert, muss hier nachziehen; das merkt sonst niemand.

Alle **sechs** Leistungspunkte der Website stehen auf dem Blatt, als eine Reihe
Haken unter dem Preis. Das war zwischendurch anders: erst vier gekürzte (Platznot
des A4-Blattes), dann bis zum 13.08.2026 fünf — beim Zurückholen war die
„Telefonische Nachbesprechung" liegengeblieben, während Kommentarkopf und
CSS-Kommentar bereits von sechs sprachen. Der Wortlaut ist ausführlicher als auf
der Website („Analyse direkt in Ihrem Unternehmen" statt „Analyse vor Ort in
Ihrem Unternehmen"): das Blatt steht für sich, ohne die Ablauf-Schritte daneben.

Das vertikale Budget ist 1624 px (1218 pt), im Browser gemessen sind 1607,45 –
**16,55 px Reserve**. Jede Textänderung, die eine Zeile mehr umbricht, kostet
17–26 px und löst die zweite Seite aus; `build-onepager.ps1` bricht dann ab.
Die Antwort darauf ist die **Blatthöhe**, nicht der Rotstift – genau dafür ist
das Blatt vom Papierformat gelöst worden. Wie gemessen wird, steht im
Kommentarkopf von `onepager.html`.

Wer den Satz trotzdem enger stellen will, findet die größte einzelne Reserve im
Hero-Band: gesetzt sind 290 px, der Inhalt braucht davon 260 (nachgemessen am
13.08.2026), der Rest ist reine Bildhöhe. Das ist deutlich weniger Luft als
früher – mit 230 px Inhalt standen dort einmal 60 px frei; der neue Untertitel
braucht eine Zeile mehr.

Kontrast der weißen Hero-Texte: gemessen, nicht geschätzt. Wer Bildausschnitt,
Schleier, Bandhöhe **oder einen der Texte** ändert, muss neu prüfen — die
Zeilen wandern dabei über andere Stellen des Fotos. Verfahren: drei Kopien der
Seite rendern und die Pixel in den Zeilenkästen auslesen (die Kästen liefert
`getClientRects()` auf dem Textinhalt, nicht `getBoundingClientRect()` auf dem
Element — sonst misst man den leeren Raum rechts mit).

| Kopie | Zusatz-CSS | wofür |
|-------|-----------|-------|
| Hintergrund | `.hero-txt,.hero-top{visibility:hidden}` | Foto plus Schleier allein |
| Saum | `.hero-sub{color:transparent}` | Hintergrund plus Schattenhof |
| Glyphen | `.hero-sub{text-shadow:none}` | Maske, wo überhaupt Schrift steht |

Ohne die erste Kopie misst man die Glyphen mit. Ohne die anderen zwei
unterschätzt man den Textschatten: er hebt den Saum neben der Schrift um rund
ein Drittel der Leuchtdichte, und darauf ist die Unterzeile angewiesen.

Verglichen werden die **angegebenen** Farben, nicht die gerasterten
Glyphenpixel: eine 12,5-px-Light-Schrift besteht überwiegend aus Kantenpixeln,
deren Helligkeit zu messen bestraft dünne Schrift doppelt. Die Unterzeile ist
`oklch(100% 0 0 / .9)`, also 90 % deckendes Weiß — das gehört in die Rechnung
über den Hintergrund gemischt.

Stand der Messung: alle sieben Zeilen bestehen, schlechtester Pixel je Zeile
4,8–6,8:1 gegen die Schwelle 4,5:1; die H1 liegt bei 4,3:1 gegen ihre Schwelle
von 3:1 (34 px Halbfett gilt als große Schrift). Die Unterzeile ist der
kritische Fall und der Grund für ihre `max-width:470px` — bei 540 px lief sie
bis x=529 in den hellen Fensterbereich und 3,7 % ihres Glyphensaums lagen unter
4,5:1.

## 6. Nach dem Livegang

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
- **Handgepflegt sind `index.html`, `impressum/index.html` und der One-Pager.**
  Seit dem 13.08.2026 ist `index.html` die Quelle, nicht mehr das Erzeugnis:
  `_rederive.sh` kann sie nicht mehr überschreiben, ein neuer Design-Export
  landet in `index.neu.html` zum Vergleichen. Aus dem Design kommen nur noch
  Bilder und Logo-SVG. Hintergrund und Ablauf stehen in `README.md`.

### Umsatzsteuer

**Der One-Pager weist seit dem 11.08.2026 Umsatzsteuer aus, die Website seit
dem 12.08.2026** – das Impressum nicht. Stand jetzt:

| Ort | Preisangabe |
| --- | --- |
| `tools/onepager/onepager.html` (PDF) | 649 € **zzgl. MwSt.** |
| `index.html` (von Hand, **nicht** im Design) | 649 € **zzgl. MwSt.** |
| `impressum/index.html` | Absatz zur Kleinunternehmerregelung nach § 19 UStG |

Im One-Pager steht das „zzgl. MwSt." als `<span class="price-mwst">` direkt
neben der Zahl – auf der Grundlinie, nicht in einer zweiten Zeile: die machte
den Preisblock 16 px höher und das Blatt damit womöglich zweiseitig. Der
frühere Satz „Gemäß § 19 UStG wird keine Umsatzsteuer berechnet." in
`<p class="pkg-fuss">` ist entfallen. Der Absatz selbst bleibt stehen – dort
steht auch der Hinweis auf individuelle Angebote für größere Standorte, der
nichts mit der Umsatzsteuer zu tun hat.

**Damit widerspricht die Website jetzt ihrem eigenen Impressum** – auf
derselben Domain. Wer nach § 19 UStG Kleinunternehmerin ist, darf keine
Umsatzsteuer ausweisen; gilt sie, gehört der § 19-Absatz raus. Beides
gleichzeitig geht nicht. Offen sind:

1. **der § 19-Absatz im Impressum** (→ USt-IdNr.); `impressum/index.html` ist
   handgepflegt. Das ist die eigentliche Entscheidung – die anderen Punkte
   folgen ihr nur.
2. ~~die Preisangabe **im Design**.~~ Seit dem 13.08.2026 gegenstandslos:
   `index.html` ist die Quelle, ein Export überschreibt sie nicht mehr. Der
   Zusatz steht dort dauerhaft von Hand.
3. der `price-sub`-Block in `_rederive.sh` – er löscht ein „zzgl. MwSt." aus
   dem Design wieder heraus und ändert dabei die `margin` von `.price`. Er
   greift auf die handgesetzte Fassung nicht (die nutzt `.price-mwst` inline
   statt `.price-sub` als eigenen Block). Gefährlich ist er nicht mehr – er
   wirkt nur noch auf `index.neu.html` –, aber wer einen Import übernimmt, muss
   dort bewusst entscheiden statt den Block laufen zu lassen. Der Kommentar an
   der Stelle sagt das inzwischen.
4. in `tools/build-schema.py` das auskommentierte `valueAddedTaxIncluded`.
   Bleibt bewusst ungesetzt, solange sich Seite und Impressum widersprechen –
   „false" wäre eine maschinenlesbare Steueraussage ohne Deckung. Der Preis
   `649` selbst stimmt in beiden Fällen.

Warum der Hinweis auf einem B2B-Blatt überhaupt gehört: ein Preis ohne Zusatz
wird in einer Buchhaltung als Netto gelesen und um 19 % erhöht (772,31 €).
