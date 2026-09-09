# officedogs.training

Landing Page für **Office Dogs** – Bürohunde-Beratung für Unternehmen
(Julia Doubrawa, Adventure Dogs).

Statische Single-Page-Site auf GitHub Pages, eigene Domain, eigenes Logo und
eigenes Farbschema. Inhaltlich und technisch getrennt von
[adventuredogs.training](https://adventuredogs.training/), inhaltlich aber
verlinkt (Nav-Punkt „OfficeDogs" dort, Footer-Links hierher zurück).

## Quelle der Seite

**Die Dateien in diesem Repo sind die Quelle.** Von Hand gepflegt werden
`index.html`, `impressum/index.html` und der One-Pager unter `tools/onepager/`.
Es gibt keine zweite Fassung woanders.

Das war bis zum 13.08.2026 andersherum: Single Source of Truth war das
claude.ai/design-Projekt „Adventure Dogs Training", Seite „Office Dogs Vollbild
Logo", und `tools/_rederive.sh` erzeugte `index.html` daraus. Am 12.08.2026
wurde der Seitentext in vier Commits direkt hier überarbeitet – neuer Hero, neue
Mehrwert-Kacheln, ein komplett neuer Abschnitt (der Fragenblock `.fit`), neue
Ablauf-Schritte, neuer Preiszusatz. Nichts davon stand im Design-Projekt, und
ein Lauf der alten Pipeline hätte es **fehlerfrei und wortlos** überschrieben
(nachgemessen: 139 Zeilen).

Am 09.09.2026 ist auch der Rest der Pipeline entfernt worden – der Import nach
`index.neu.html` und die rund zwanzig Korrekturen, die er auf einen Export
anwandte. Sie waren zuletzt ohnehin unerreichbar: der Ordner
`design-extract-v53` existiert nicht mehr, und alles, was sie taten, steht fest
in `index.html`. Wer nachsehen will, was sie getan haben:
`git log -- tools/_rederive.sh`.

claude.ai/design wird nur noch **gelegentlich für einzelne Stücke** benutzt. Was
daraus ins Repo übernommen wird, wird im Einzelfall ausdrücklich benannt und von
Hand übertragen – mit den Farben, Schriften und Klassen aus dem Bestand.

## Änderungen veröffentlichen

Einmalig je Arbeitskopie den Hook aktivieren – `.git/hooks` ist nicht
versioniert, `tools/hooks` schon:

```bash
git config core.hooksPath tools/hooks
```

Danach: Dateien bearbeiten, `git status` ansehen, gezielt `git add`, dann
`git commit`. Der Hook erledigt drei Dinge: er erzeugt `sitemap.xml` neu und
nimmt sie mit in den Commit, falls sie nicht aktuell war, lässt `check-site.py`
über die Seite laufen und rechnet das JSON-LD gegen das Markup nach. Bricht er
ab, sagt er warum; im Notfall `git commit --no-verify`. `git push` – GitHub
Pages veröffentlicht in ein bis drei Minuten.

Ohne Hook oder zur Kontrolle zwischendurch sind es dieselben drei Aufrufe von
Hand:

```bash
bash tools/generate-sitemap.sh && py tools/check-site.py && py tools/build-schema.py --check index.html
```

## Werkzeuge in `tools/`

| Datei | wofür |
|---|---|
| `hooks/pre-commit` | ruft die drei nächsten Zeilen vor jedem Commit auf |
| `generate-sitemap.sh` | schreibt `sitemap.xml` (zwei Seiten); `lastmod` aus git |
| `check-site.py` | prüft die Seite: Seiten gegen die Sitemap, SEO-Blöcke (title, description, canonical, og:\*, viewport), interne Verweise, Bildmaße und -gewicht, Seitengewicht. Fehler blockieren, Warnungen nicht |
| `build-schema.py` | JSON-LD. `--check` vergleicht den Block in der Seite mit dem, der sich aus ihrem Markup ergibt; ohne `--check` schreibt es ihn in eine Datei. Statischer Rumpf: `schema.json.html` |
| `optimize-images.ps1` | erzeugt die ausgelieferten Bildvarianten. **Woher die Quellen heute kommen, steht im Kopf der Datei** – der Design-Export ist weg, das Portrait liegt in der Schwesterseite, die Favicon-Vorlage gar nicht mehr |
| `subset-fonts.py` | verkleinert die selbst gehosteten Schriften |
| `build-onepager.ps1`, `onepager/` | das PDF-Blatt, siehe [DEPLOY.md](DEPLOY.md) |
| `assets-src/` | Original des Hero-Bildes, aus dem Hero und og:image entstehen |

## Deployment

GitHub Pages, Branch `main`, Root. `CNAME` hält die Custom Domain.
DNS zeigt auf die GitHub-Pages-IPs (identisch zu adventuredogs.training).

Pages lässt Jekyll über das Repo laufen, und alles, was Jekyll nicht
ausschließt, ist unter `officedogs.training/<pfad>` abrufbar. `_config.yml`
hält deshalb `tools/`, `README.md`, `CLAUDE.md` und `DEPLOY.md` heraus –
gemessen am 09.09.2026 lieferte `DEPLOY.html` die interne Deployment-Doku aus
und `tools/assets-src/hero-office-dogs.png` das 2,3-MB-Original des Heros.
Nach dem nächsten Push nachsehen (soll 404 sein):

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://officedogs.training/DEPLOY.html
```
