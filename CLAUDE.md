# Hinweise für die Arbeit an dieser Seite

Ergänzung zur [README.md](README.md), die Quelle, Werkzeuge und Veröffentlichung
beschreibt. Hier steht nur, was man beim Bearbeiten leicht falsch macht.

## Diese Seite hat einen Deckel – die Schwesterseite nicht

Der Inhalt steht in `.wrap` und ist auf `--maxw: 1240px` gedeckelt, zentriert per
`margin: 0 auto`, Seitenrand `--pad: clamp(22px, 4vw, 52px)`. Ein neuer Block
gehört in einen `.wrap`, sonst läuft er an den Nachbarabschnitten vorbei bis an
den Fensterrand.

**Auf [adventuredogs.training](https://adventuredogs.training/) gilt das
Gegenteil**: dort gibt es bewusst keinen Maximalbreiten-Container, die Sektionen
laufen in 7 % Seitenrand über die volle Breite. Wer zwischen den Repos wechselt,
darf die Gewohnheit nicht mitnehmen – in beide Richtungen fällt es erst jenseits
von 1500 px auf.

## Der Hero ist gemessen, nicht gestaltet

Bildausschnitt (`36% 44%`), Schleier und Textschatten stehen so, wie sie stehen,
weil der Kontrast dahinter nachgerechnet wurde – per Canvas, mit dem Foto im
echten `cover`-Ausschnitt: H1 3,81 (Großtext braucht 3,0), Fließtext 6,97
(braucht 4,5). Telefone haben eine eigene Schleier-Fassung
(`@media (max-width: 660px)`), weil der Text dort neun Zeilen umbricht und die
Kicker-Zeile sonst in der hellen Delle des Verlaufs steht: gemessen 3,7:1 vorher,
5,0:1 nachher.

Der **Textschatten ist Teil dieser Rechnung**, nicht Zierrat: Nav-Links und
Kicker liegen ohne ihn bei 3,4:1. Enger Kern statt breiter Weichzeichnung – ein
10-px-Blur verteilt die Deckkraft so weit, dass an der Buchstabenkante kaum etwas
ankommt.

**Wer Bildausschnitt, Schleier oder einen der Hero-Texte ändert, muss neu
messen** – die Zeilen wandern dabei über andere Stellen des Fotos. Die
Begründungen stehen als Kommentar direkt an den Regeln in `index.html`; das
Verfahren (drei Kopien rendern, Pixel aus `getClientRects()` lesen) beschreibt
[DEPLOY.md](DEPLOY.md) für den One-Pager, es gilt hier genauso.

## Der Preis steht an drei Stellen

| Wo | Was |
|---|---|
| `index.html` | `<div class="price">649 € <span class="price-mwst">zzgl. MwSt.</span></div>` |
| `tools/onepager/onepager.html` | dieselbe Angabe auf dem PDF-Blatt |
| JSON-LD in `index.html` | wird aus dem Markup **gelesen**, nicht abgeschrieben |

Das JSON-LD prüft der `pre-commit`-Hook (`build-schema.py --check`) – es kann
also nicht abdriften. **Der One-Pager kann.** Wer den Preis oder einen
Leistungspunkt ändert, muss das Blatt nachziehen; das merkt sonst niemand.

Offen und bewusst offen: die Seite weist Umsatzsteuer aus, das Impressum trägt
den Absatz zur Kleinunternehmerregelung nach § 19 UStG. Beides zugleich geht
nicht – der Stand steht in [DEPLOY.md](DEPLOY.md#umsatzsteuer).

## One-Pager: wird der Text länger, wächst das Blatt

Die Blatthöhe steht an zwei Stellen in `onepager.html` (`@page` und `html,body`)
und muss beide Male denselben Wert tragen, ein Vielfaches von 6 pt. Vergisst man
`@page`, bricht `build-onepager.ps1` mit „zweite Seite" ab. Vergisst man
`html,body`, merkt es **niemand**. Reserve sind derzeit 16,55 px – eine einzige
zusätzlich umbrechende Zeile kostet 17–26 px. Details in
[DEPLOY.md](DEPLOY.md).

## Schriften, Farben und Bausteine aus dem Bestand

Farben ausschließlich aus den `:root`-Variablen in `index.html` (`--slate`,
`--slate-mid`, `--sand`, `--sand-deep`, `--paper`, `--cream`, `--text`,
`--line`, dazu `--maxw`, `--pad`, `--r`) – keine neu erfundenen Werte.

Schriften sind selbst gehostet über `assets/fonts.css`: **DM Sans** in 300, 400,
500 und 600 – mehr Schnitte gibt es nicht, ein `font-weight: 700` rendert
gefälscht. **Playfair Display** liegt nur als 600 kursiv im Ordner und gehört
dem `blockquote` in der Zitat-Sektion. Ein zweiter kursiver Serifenblock nimmt
ihm die Wirkung und bräuchte eine weitere Schriftdatei.

Für wiederkehrende Teile die vorhandenen Klassen nutzen statt sie nachzubauen:
`.label` für die kleine Versalzeile über einer Überschrift, `.wrap` für den
Inhaltscontainer, `.btn` mit einer der drei Varianten `.b-slate`, `.b-paper`
oder `.b-ghost`, dazu `.card`/`.cards` und die `.pkg-*`-Familie im Preisblock.

## Bilder kommen nicht mehr von selbst

`tools/optimize-images.ps1` erzeugt die ausgelieferten Varianten, wird aber nur
noch von Hand aufgerufen. **Woher die Quellen kommen, steht im Kopf der Datei** –
Hero und og:image aus dem Repo, das Portrait aus der Schwesterseite, und die
Favicon-Vorlage gibt es gar nicht mehr (nur noch die Vektorfassung
`assets/logo-office-dogs.svg`, aus der man erst rastern müsste).

**Ein neues Logo muss durch scour.** Die ausgelieferte
`assets/logo-office-dogs.svg` ist optimiert, und zwar mit:

```bash
py -m scour.scour -i logo.svg -o assets/logo-office-dogs.svg --set-precision=5 --enable-id-stripping --enable-comment-stripping --shorten-ids --remove-metadata --strip-xml-prolog --no-line-breaks
```

Das brachte 30,2 → 20,1 KB roh und 9,4 → 6,3 KB übertragen. Der Gewinn kommt
aus relativen Pfadbefehlen und weggelassenen Trennzeichen, nicht aus gerundeten
Zahlen: `precision=5` ist für diese Quelle verlustfrei, weil dort höchstens
vierstellige Werte mit einer Nachkommastelle stehen. Nachgemessen an einem
Pixel-Diff bei 600×600: 20 abweichende Pixel von 360.000, alle auf Kanten,
also reines Antialiasing. Bis zum 09.09.2026 lief das automatisch im
Pflegelauf; seit dessen Wegfall macht es niemand mehr von selbst.

Beim Bildpanel im „Warum Office Dogs"-Block gilt: **`sizes` nennt die gemalte
Breite, nicht die Boxbreite.** Das Panel ist 568 px breit, aber hochkant und
füllt per `object-fit: cover` über die Höhe – gemalt werden rund 1104 px. Die
Begründung steht als Kommentar an der Regel; nicht auf die Boxbreite
zurückbauen.

## Nicht ungefragt committen oder pushen

GitHub Pages veröffentlicht jeden Push innerhalb von ein bis drei Minuten live.
Änderungen erst zeigen, dann auf Zuruf committen.

Den Rest erledigt der `pre-commit`-Hook (einmalig
`git config core.hooksPath tools/hooks`): er erzeugt `sitemap.xml` neu und nimmt
sie mit in den Commit, falls sie nicht aktuell war, lässt `check-site.py` laufen
(Seiten gegen die Sitemap, SEO-Blöcke, interne Verweise, Bildmaße,
Seitengewicht) und rechnet das JSON-LD gegen das Markup nach. Bricht er ab, ist
etwas wirklich kaputt; `--no-verify` ist für Notfälle, nicht für Bequemlichkeit.

Von Hand nur zwei Dinge:

- **Neue Seite?** Die URL in `tools/generate-sitemap.sh` eintragen – die Liste
  dort ist fest verdrahtet. Und der `<head>` braucht `title`, `description`,
  `canonical` auf die eigene URL, `og:title`, `og:image` und `viewport`;
  `check-site.py` besteht darauf und nennt beim Abbruch genau das Fehlende.
- **Neue Bilder?** `optimize-images.ps1` laufen lassen (siehe oben). Nichts
  breiter als 2400 px, nichts über 700 KB, was ein Besucher wirklich lädt.

Und: **was auf `main` liegt, ist im Zweifel öffentlich abrufbar.**
`_config.yml` schließt `tools/` sowie `README.md`, `CLAUDE.md` und `DEPLOY.md`
aus – das ist die einzige Bremse, und sie greift nur für die dort genannten
Pfade. Wer einen neuen Ordner mit Werkzeug oder Notizen anlegt, trägt ihn dort
ein; sonst steht er nach dem nächsten Push unter `officedogs.training/<pfad>`.
Gemessen am 09.09.2026, vor der Ausnahmeliste: `tools/build-schema.py` lieferte
200, `DEPLOY.html` ebenfalls.

## Es gibt keinen Design-Import mehr

claude.ai/design ist nicht mehr die Quelle dieser Seite; die Dateien im Repo sind
es. Das Tool wird nur noch gelegentlich für einzelne Stücke benutzt, und was
daraus übernommen wird, sagt Jürgen ausdrücklich – übertragen wird von Hand, mit
den Farben, Schriften und Klassen aus dem Bestand.

Die alte Pipeline (`tools/_rederive.sh` mit Import nach `index.neu.html` und rund
zwanzig sed-Korrekturen auf den Export) ist am 09.09.2026 entfernt worden. Keinen
Diff gegen einen Export bauen, keine Korrekturen „nachziehen" – alles, was diese
Skripte taten, steht fest in den Seiten. Wer nachsehen will:
`git log -- tools/_rederive.sh`.
