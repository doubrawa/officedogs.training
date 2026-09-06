#!/bin/bash
# Pflege- und Import-Script für officedogs.training.
#
# ROLLENWECHSEL AM 13.08.2026 — bitte zuerst lesen.
#
# Bis dahin galt: die Seite wird im claude.ai/design-Projekt "Adventure Dogs
# Training" gepflegt (Seite: "Office Dogs Vollbild Logo"), dieses Script zieht
# sie heraus und macht daraus index.html. Der Export war die Quelle, index.html
# das Erzeugnis.
#
# Das stimmt nicht mehr. QUELLE IST JETZT index.html.
#
# Der Seitentext wurde am 12.08.2026 in vier Commits direkt hier überarbeitet —
# neuer Hero, neue Mehrwert-Kacheln, ein komplett neuer Abschnitt (der
# Fragenblock .fit), neue Ablauf-Schritte, neuer Preiszusatz. Nichts davon
# steht im Design-Projekt; der letzte Export (v53) ist vom 04.08.2026.
#
# Nachgemessen am 13.08.2026: ein Lauf der alten Fassung lief FEHLERFREI durch
# und warf dabei 139 Zeilen Live-Inhalt weg. Kein must_sed schlug an, denn die
# Sonden zielen alle auf die STRUKTUR des Exports (Klassennamen, CSS-Regeln,
# Ankertexte) — und die war ja noch da. Nur der Text darin war ein anderer.
# Genau die Sorte stiller Schaden, gegen die must_sed weiter unten erfunden
# wurde, bloß eine Ebene höher: nicht ein sed lief ins Leere, sondern das `cp`
# darüber traf.
#
# Deshalb ist die Sperre keine Prüfung, sondern baulich: der Import schreibt
# nach index.neu.html und rührt index.html NICHT AN. Wer einen neuen Export
# übernehmen will, vergleicht die beiden von Hand und holt sich heraus, was er
# braucht. Eine Prüfung könnte man übergehen; einen Schreibpfad, den es nicht
# gibt, nicht.
#
# ---------------------------------------------------------------------------
# Aufruf
#
#   bash tools/_rederive.sh
#       Pflegelauf. Fasst index.html nicht an. Erneuert Bilder und Logo-SVG
#       aus dem Export und schreibt sitemap.xml. Ohne Export läuft er trotzdem
#       (dann eben nur die sitemap).
#
#   bash tools/_rederive.sh --import
#       Baut den Export nach index.neu.html und meldet, wie weit er von
#       index.html entfernt ist. Danach von Hand übernehmen, was gebraucht
#       wird, und index.neu.html löschen.
#
# Workflow für einen neuen Design-Export:
#   1. "Adventure Dogs Training.zip" nach C:/DATA/Claude/design-extract-vN
#      entpacken (der gleiche Export, den auch das Hauptrepo benutzt)
#   2. SRC unten auf design-extract-vN setzen
#   3. bash tools/_rederive.sh --import
#   4. diff index.html index.neu.html — übernehmen, was gewollt ist
#   5. rm index.neu.html, dann committen
#
# Bewusst schlank gehalten: keine Artikel-/Hub-/Bilder-Sitemap-Maschinerie
# wie im Hauptrepo — hier gibt es genau eine Seite.
set -e
SRC="C:/DATA/Claude/design-extract-v53"
PAGE="Office Dogs Vollbild Logo.html"
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="https://officedogs.training"
MAIN="https://adventuredogs.training"

MODE=pflege
case "$1" in
  --import) MODE=import ;;
  "")       ;;
  *)        echo "Unbekannte Option: $1"; echo "Erlaubt: --import"; exit 1 ;;
esac

# Der Export wird nur für Bilder, Logo und den Import gebraucht. Fehlt er, ist
# der Pflegelauf trotzdem sinnvoll (sitemap), der Import dagegen unmöglich.
HAVE_SRC=0
[ -f "$SRC/$PAGE" ] && HAVE_SRC=1
if [ "$MODE" = import ] && [ "$HAVE_SRC" = 0 ]; then
  echo "FEHLER: $SRC/$PAGE nicht gefunden — ohne Export kein Import."
  exit 1
fi

# ===========================================================================
# TEIL 1 — läuft immer. Nichts hier fasst index.html an.
# ===========================================================================

if [ "$HAVE_SRC" = 1 ]; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(cygpath -w "$DST/tools/optimize-images.ps1")" \
    -Src   "$(cygpath -w "$SRC/assets")" \
    -Local "$(cygpath -w "$DST/tools/assets-src")" \
    -Dst   "$(cygpath -w "$DST/assets")"

  # --- Logo ----------------------------------------------------------------
  # scour verkleinert das SVG um rund ein Drittel (30,2 -> 20,1 KB roh,
  # 9,4 -> 6,3 KB uebertragen). Der Gewinn kommt aus relativen Pfadbefehlen und
  # weggelassenen Trennzeichen, nicht aus gerundeten Zahlen: precision=5 ist fuer
  # diese Quelle verlustfrei, weil dort hoechstens vierstellige Werte mit einer
  # Nachkommastelle stehen. Ein Pixel-Diff bei 600x600 zeigte 20 abweichende
  # Pixel von 360.000, alle auf Kanten — reines Antialiasing.
  cp "$SRC/assets/logo-office-dogs.svg" "$DST/assets/logo-office-dogs.svg"
  if py -c "import scour" >/dev/null 2>&1; then
    py -m scour.scour -i "$DST/assets/logo-office-dogs.svg" \
       -o "$DST/assets/logo-office-dogs.min.svg" \
       --set-precision=5 --enable-id-stripping --enable-comment-stripping \
       --shorten-ids --remove-metadata --strip-xml-prolog --no-line-breaks \
       >/dev/null 2>&1
    mv "$DST/assets/logo-office-dogs.min.svg" "$DST/assets/logo-office-dogs.svg"
    echo "  Logo-SVG optimiert ($(stat -c%s "$DST/assets/logo-office-dogs.svg") Bytes)"
  else
    echo "  WARNUNG: scour fehlt (py -m pip install scour) — Logo bleibt unoptimiert"
  fi
else
  echo "  Export nicht vorhanden ($SRC) — Bilder und Logo bleiben, wie sie sind."
fi

# --- sitemap.xml -----------------------------------------------------------
# lastmod je Seite: hat DIESER Lauf die Datei verändert, ist heute das Datum
# der Änderung — sonst zählt der letzte Commit der Datei.
#
# Warum nicht einfach immer das Commit-Datum: die Sitemap entsteht MITTEN im
# Lauf, also bevor die soeben erzeugten Änderungen committet sind. `git log`
# liefert dann den Stand von vorher, und die Sitemap meldet für eine gerade
# geänderte Seite hartnäckig das Datum der vorherigen Runde. Das fällt nicht
# auf, solange Umbau und Commit auf denselben Tag fallen — läuft der Import
# aber an einem anderen Tag als der letzte Commit, steht dort ein Datum zu
# früh. Google gewichtet lastmod ohnehin nur, wenn es nachweislich stimmt.
#
# `diff HEAD` deckt Arbeitsverzeichnis UND Index ab, egal ob schon `git add`
# gelaufen ist. Im frisch initialisierten Repo (noch kein HEAD) scheitert es
# mit Exit 128 — dann greift ebenfalls das heutige Datum, was dort richtig
# ist. Beides steht in einer `if`-Bedingung, `set -e` greift also nicht.
#
# Seit dem Rollenwechsel stimmt das sogar besser als vorher: index.html wird
# jetzt von Hand gepflegt, `git diff HEAD` sieht also genau die Bearbeitung,
# um die es geht, statt der vom Script selbst erzeugten.
lastmod_of() {
  local f="$1"
  if ! git -C "$DST" diff --quiet HEAD -- "$f" 2>/dev/null; then
    date -u +%Y-%m-%d
    return
  fi
  # `|| true`: unversionierte Datei → git log Exit 128 statt leerer Ausgabe.
  local d=$(git -C "$DST" log -1 --format=%cd --date=short -- "$f" 2>/dev/null || true)
  [ -z "$d" ] && d=$(date -u +%Y-%m-%d)
  echo "$d"
}
cat > "$DST/sitemap.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>${BASE}/</loc>
    <lastmod>$(lastmod_of index.html)</lastmod>
    <changefreq>monthly</changefreq>
    <priority>1.0</priority>
  </url>
  <url>
    <loc>${BASE}/impressum/</loc>
    <lastmod>$(lastmod_of impressum/index.html)</lastmod>
    <changefreq>yearly</changefreq>
    <priority>0.3</priority>
  </url>
</urlset>
XML
echo "  sitemap.xml erzeugt (2 URLs)"

# --- Schema.org in index.html gegenpruefen ---------------------------------
# build-schema.py liest Preis, Paketname und Leistungsposten AUS der Seite,
# damit die strukturierten Daten nicht von der sichtbaren Seite abdriften
# koennen. Diese Zusage galt, solange das Script index.html selbst schrieb.
# Seit dem Rollenwechsel laeuft der Generator nur noch in TEIL 2, also gegen
# index.neu.html — fuer die handgepflegte index.html gab es sie nicht mehr:
# wer den Preis im Markup aendert, aendert das JSON-LD 100 Zeilen darunter
# nicht mit, und nichts schlaegt an. Genau der Fall, den der Docstring dort
# fuer unmoeglich erklaert.
#
# Deshalb hier die Gegenprobe. Sie SCHREIBT NICHT — index.html bleibt Quelle
# und Handarbeit —, sie rechnet den Block neu und vergleicht ihn mit dem, der
# drinsteht. Weicht er ab, bricht der Lauf ab (set -e), statt die Abweichung
# stehen zu lassen.
if [ -f "$DST/index.html" ]; then
  if py -c "" >/dev/null 2>&1; then
    py "$DST/tools/build-schema.py" --check "$DST/index.html"
  else
    echo "  WARNUNG: py fehlt — JSON-LD in index.html ungeprueft"
  fi
fi

if [ "$MODE" = pflege ]; then
  echo
  echo "Pflegelauf fertig. index.html wurde nicht angefasst — sie ist die Quelle."
  echo "Neuen Design-Export übernehmen: bash tools/_rederive.sh --import"
  exit 0
fi

# ===========================================================================
# TEIL 2 — nur mit --import. Schreibt ausschliesslich nach index.neu.html.
#
# Alles ab hier ist der alte Import-Pfad, unveraendert bis auf das Ziel. Die
# Korrekturen bleiben dokumentiert, weil sie beim naechsten Export wieder
# gebraucht werden: sie beschreiben, was das Design-Tool systematisch anders
# ausgibt, als die Site es braucht.
# ===========================================================================

F="$DST/index.neu.html"
cp "$SRC/$PAGE" "$F"
echo "index.neu.html aus '$PAGE' erzeugt"

# Ersetzt ein Muster in index.neu.html und bricht ab, wenn es gar nicht vorkommt.
# Grund: ein sed, das nach einer Design-Aenderung stillschweigend ins Leere
# laeuft, faellt beim Diff nicht auf. Genau das ist im Hauptrepo schon
# passiert (umbenanntes Datums-Label) und hat wochenlang falsche Ausgabe
# produziert. Lieber laut scheitern als leise nichts tun.
must_sed() {
  local expr="$1" probe="$2"
  grep -q -- "$probe" "$F" || {
    echo "FEHLER: Muster nicht mehr im Export gefunden: $probe"
    echo "        Vermutlich hat sich das Design geaendert — sed pruefen:"
    echo "        $expr"
    exit 1
  }
  sed -i "$expr" "$F"
}

# --- Querverweise auf die Hauptsite ---------------------------------------
# Das Design-Tool exportiert Geschwisterseiten als flache Dateinamen. Weil
# officedogs.training eine EIGENE Domain ist, müssen daraus absolute URLs
# auf adventuredogs.training werden — relative Pfade würden hier ins Leere
# laufen.
#
# AUSNAHME Impressum/Datenschutz: officedogs.training hat ein EIGENES
# Impressum (impressum/index.html, von Hand gepflegt, NICHT aus dem Design).
# Ein Impressum muss auf der Domain selbst liegen, auf der der Dienst
# angeboten wird — deshalb zeigen diese beiden Links nach innen.
# Reihenfolge beachten: das #datenschutz-Muster vor dem nackten
# Impressum-Muster, sonst greift das kürzere zuerst.
sed -i "s|\"Impressum\.html#datenschutz\"|\"/impressum/#datenschutz\"|g" "$F"
sed -i "s|\"Impressum\.html\"|\"/impressum/\"|g" "$F"
sed -i "s|\"Landing Page\.html\"|\"${MAIN}/\"|g" "$F"
sed -i "s|\"Angebotsseite\.html\"|\"${MAIN}/angebot/\"|g" "$F"
sed -i "s|\"Kontakt\.html\"|\"${MAIN}/kontakt/\"|g" "$F"
sed -i "s|\"Alltagstipps\.html\"|\"${MAIN}/alltagstipps/\"|g" "$F"
sed -i "s|\"Über mich\.html\"|\"${MAIN}/ueber-mich/\"|g" "$F"

# --- Handlungsaufforderungen ------------------------------------------------
# Das Design haengt "Gespraech vereinbaren" (Nav, Mobilmenue, Hero) und
# "Anfrage senden" (Preisblock) an den seiteninternen Anker #kontakt. Auf einer
# Seite mit eigenem Formular waere das richtig — hier nicht: die #kontakt-
# Sektion enthaelt kein Formular, sondern selbst nur einen Knopf, der nach
# ${MAIN}/kontakt/ fuehrt. Ein Klick scrollte also bloss an eine Stelle, an der
# man ein zweites Mal klicken musste. Jetzt gehen alle vier direkt dorthin,
# genau wie "Kontakt aufnehmen" im Abschluss-Block.
#
# Nur die href, nicht die id: die Sektion bleibt als Abschluss der Seite
# stehen, sie wird nur nicht mehr angesprungen. Wer scrollt, sieht sie
# weiterhin. Die anderen Anker (#mehrwert, #ansatz, #ablauf, #paket, #top)
# springen unveraendert innerhalb der Seite — die zeigen auf echten Inhalt.
must_sed "s|href=\"#kontakt\"|href=\"${MAIN}/kontakt/\"|g" 'href="#kontakt"'

# --- Title und Description --------------------------------------------------
# Beides kommt aus dem Design und ist zu lang für die Suchergebnisse: der Titel
# hatte 72 Zeichen (Google zeigt rund 60, "| Julia Doubrawa" fiel also weg),
# die Description 161 (Anzeige endet bei etwa 155). Jetzt 48 bzw. 150.
#
# Im Titel steht bewusst die Leistung statt des Namens — nach "Bürohunde-
# Beratung" wird gesucht, nach "Julia Doubrawa" nicht. Der Name steht weiterhin
# sichtbar auf der Seite, im Schema und im Impressum. In der Description ist
# "in Bayern" ergänzt, weil die Beratung vor Ort stattfindet und regionale
# Suchanfragen sonst ins Leere laufen.
#
# Muster bewusst nur mit ASCII (^<title>.*</title>$): sed matcht in Git Bash
# Umlaute im SUCHmuster unzuverlässig — im Ersetzungstext sind sie unkritisch.
#
# Muss VOR inject_seo laufen: og:title und og:description werden von dort aus
# dem fertigen <title>/<meta> abgeleitet.
must_sed "s|^<title>.*</title>$|<title>Office Dogs – Bürohunde-Beratung für Unternehmen</title>|" \
         "^<title>"
must_sed "s|^<meta name=\"description\" content=\".*\">$|<meta name=\"description\" content=\"Bürohunde-Beratung für Unternehmen in Bayern: Analyse vor Ort, individueller Office Dogs Guide und Praxis-Coaching – damit Hunde im Büro funktionieren.\">|" \
         "^<meta name=\"description\""

# --- Produktname -----------------------------------------------------------
# Das Design schreibt "Office Dog Guide", richtig heisst das Produkt aber
# "Office Dogs Guide" (wie die Marke). Global, damit Ueberschrift, Leistungs-
# liste und jede kuenftige Erwaehnung gleich heissen — eine Seite, auf der
# derselbe Name zweimal anders geschrieben steht, liest sich wie ein Tippfehler.
# Idempotent: "Office Dogs Guide" enthaelt "Office Dog Guide" nicht.
# Das JSON-LD-Angebot liest den Namen ohnehin aus der Seite und folgt von selbst.
#
# Bewusst KEIN must_sed, aus demselben Grund wie bei der E-Mail-Adresse unten:
# die Sonde waere hier der Tippfehler selbst. Wird er im Design korrigiert —
# der erwuenschte Ausgang —, braeche must_sed den Import mit "Muster nicht mehr
# gefunden" ab, obwohl gar nichts kaputt ist. Korrekturen, deren Verschwinden
# der Erfolgsfall ist, laufen leer statt laut zu scheitern.
sed -i "s|Office Dog Guide|Office Dogs Guide|g" "$F"

# --- E-Mail-Adresse --------------------------------------------------------
# Das Design liefert info@adventuredogs.training — die Adresse existiert nicht.
# Auf dieser Domain gilt julia@officedogs.training. Sobald das im
# claude.ai/design-Projekt korrigiert ist, läuft dieses sed einfach leer.
sed -i "s|info@adventuredogs\.training|julia@officedogs.training|g" "$F"

# --- Preisangabe -----------------------------------------------------------
# ACHTUNG, seit dem 12.08.2026 ueberholt: index.html weist inzwischen
# "zzgl. MwSt." aus (als <span class="price-mwst"> inline neben der Zahl).
# Dieser Block loescht den Zusatz aus dem EXPORT wieder heraus — er stammt aus
# der Zeit der Kleinunternehmerregelung. Wer einen Import uebernimmt, muss hier
# also bewusst entscheiden, statt den Block einfach laufen zu lassen.
# Die offene Widerspruchslage Seite/Impressum steht in DEPLOY.md.
#
# Der Zusatz trug 28 px Abstand zum Button bei; beim Entfernen wandert der
# Ausgleich in die margin von .price, sonst klebt der Button am Preis.
# Beides passiert nur, wenn der Zusatz überhaupt noch da ist — sobald es im
# Design korrigiert ist, greift der Block gar nicht mehr.
#
# Beide Schritte ueber must_sed, und die Sonde des if ist dieselbe wie das
# Loeschmuster: vorher fragte sie nur nach 'class="price-sub">zzgl. MwSt.'
# ohne das schliessende </div> auf derselben Zeile, und der Ausgleich hing an
# einem ungeprueften sed. Aendert das Design die margin der .price-Regel, wurde
# der Zusatz geloescht, der Ausgleich blieb aus — und die echo-Zeile meldete
# trotzdem Vollzug. Uebrig blieb ein Knopf, der am Preis klebt, ohne Hinweis.
if grep -q '<div class="price-sub">zzgl\. MwSt\.</div>' "$F"; then
  must_sed '/<div class="price-sub">zzgl\. MwSt\.<\/div>/d' \
           '<div class="price-sub">zzgl\. MwSt\.</div>'
  must_sed 's|\(\.price{[^}]*\)margin:12px 0 7px}|\1margin:12px 0 34px}|' \
           '\.price{[^}]*margin:12px 0 7px}'
  echo "  Preis: 'zzgl. MwSt.' entfernt (Kleinunternehmerregelung) — pruefen, siehe DEPLOY.md"
fi

# --- Bilder ----------------------------------------------------------------
# Der Export referenziert den Hero als PNG; optimize-images.ps1 legt ein JPG ab.
must_sed "s|assets/hero-office-dogs\.png|assets/hero-office-dogs.jpg|g" \
         "assets/hero-office-dogs.png"

# Hero-Ausschnitt. Das Design ankert 62%/bottom — das passte zu einem frueheren
# Motiv. Das jetzige Bild zeigt eine Frau am Schreibtisch (links oben) und den
# Hund davor auf dem Boden (Mitte unten).
#
# Mit "cover" beschneidet immer nur EINE Achse: breite Viewports vertikal,
# schmale horizontal. Die beiden Werte stoeren sich also nie gegenseitig.
#   44% vertikal  — greift auf breiten Viewports, laesst oben die Decke und
#                   unten die Pfoten gerade noch im Bild.
#   36% horizontal — greift auf Telefonen, wo nur rund 31 % der Bildbreite zu
#                   sehen sind. Bei den vorher gesetzten 50 % zeigte das
#                   Telefon einen leeren Buroflur: ihr Gesicht links raus,
#                   der Hund hinter dem Text. 36 % holt beide ins Bild.
#                   Gemessen, nicht geschaetzt — 30/36/42 % gerendert und
#                   verglichen.
must_sed "s|assets/hero-office-dogs\.jpg') 62% bottom|assets/hero-office-dogs.jpg') 36% 44%|" \
         "hero-office-dogs.jpg') 62% bottom"

# --- Hero-Schleier ----------------------------------------------------------
# Der blaugraue Verlauf ueber dem Hero war zu kraeftig; das Foto kam kaum durch.
# Alle Stopps um rund ein Fuenftel zurueckgenommen (mittlere Bildhelligkeit
# 0,071 -> 0,085). Die Stopps unten bleiben fast unangetastet: dort steht der
# Text, und dessen Lesbarkeit haengt genau daran.
#
# Gemessen wurde nicht nach Gefuehl, sondern per Canvas — Hero-Bild im echten
# cover-Ausschnitt plus beide Verlaeufe gerendert, dann der schlechteste
# Kontrastwert hinter jedem Textblock. Ergebnis nachher: H1 3,81 (Grosstext
# braucht 3,0), Fliesstext 6,97 (braucht 4,5).
must_sed "s|^\.hero-overlay{.*}$|.hero-overlay{position:absolute;inset:0;background:linear-gradient(to right,oklch(22% 0.04 250 / .62) 0%,oklch(22% 0.04 250 / .24) 58%,oklch(22% 0.04 250 / .05) 100%),linear-gradient(to bottom,oklch(24% 0.04 250 / .42) 0%,oklch(24% 0.04 250 / .14) 32%,oklch(22% 0.04 250 / .60) 72%,oklch(18% 0.04 250 / .87) 100%)}|" \
         "^\.hero-overlay{"

# Zwei Textstellen liegen schon im Original knapp unter dem AA-Kontrast (die
# Navigationslinks bei 3,4 ueber der hellen Fensterfront, die Zeile ueber der
# Headline bei 3,4) und wuerden durch den helleren Schleier weiter absacken.
# Gegengewicht: engerer Schatten statt breiter Weichzeichnung — 10 px Blur
# verteilt die Deckkraft so weit, dass direkt an der Buchstabenkante kaum
# etwas ankommt. Ein 3-px-Kern traegt dort deutlich mehr.
#
# Beide ueber must_sed, und beide Sonden tragen dieselbe Bedingung wie ihre
# Ersetzung. Das ist hier keine Formsache: der Ausgleich ist gemessen, und ohne
# ihn liefert der Import eine Seite, die den helleren Schleier bekommt, aber
# nicht sein Gegengewicht — zwei Textstellen faenden sich dann unter AA wieder,
# ohne dass der Lauf etwas sagt. Vorher lief der erste als blankes sed, und die
# Sonde des zweiten fragte nur nach "^\.hero \.label{": ein minimal
# verschobener Sandton haette das sed leerlaufen lassen, waehrend grep
# weiterhin fuendig wurde.
must_sed 's|text-shadow:0 1px 10px oklch(0% 0 0 / \.3)|text-shadow:0 1px 3px oklch(0% 0 0 / .5),0 2px 14px oklch(0% 0 0 / .4)|g' \
         'text-shadow:0 1px 10px oklch(0% 0 0 / \.3)'

must_sed "s|^\.hero \.label{color:oklch(93% 0.02 85)}$|.hero .label{color:oklch(93% 0.02 85);text-shadow:0 1px 3px oklch(0% 0 0 / .5),0 1px 14px oklch(0% 0 0 / .4)}|" \
         "^\.hero \.label{color:oklch(93% 0\.02 85)}$"

# --- Marke in der Kopfzeile -------------------------------------------------
# Neben dem Logo stand "Office Dogs" mit dem Zusatz "Adventure Dogs · Julia
# Doubrawa". Auf einer eigenen Domain mit eigener Marke ist das eine Marke zu
# viel; die Zuordnung zur Hundeschule steht weiterhin im Menue, im Footer und
# im Impressum. Danach ist <b> einzeilig, und das align-items:center der
# .brand-Zeile zentriert den Text von selbst zum 46-px-Logo — kein CSS noetig.
# [^<]* statt des Mittelpunkts: sed ist in Git Bash mit Nicht-ASCII unzuverlaessig.
must_sed "s|<small>Adventure Dogs[^<]*</small>||" "<small>Adventure Dogs"
# Die drei Regeln dazu sind damit tot.
sed -i '/^nav \.brand small{/d;/^nav\.scrolled \.brand small{/d;/^\.brand small{/d' "$F"

# Der Hero trug frueher ein grosses Logo (daher der Seitenname "Vollbild
# Logo"); seit v53 ist es raus, die zwei Regeln dafuer blieben stehen.
# Bewusst an das Markup gekoppelt statt fest geloescht: kommt das Bild im
# Design zurueck, bleiben die Regeln stehen und es steht nicht ploetzlich
# ungestylt im Hero.
if ! sed -n '/<div class="hero-in">/,/^  <\/div>/p' "$F" | grep -q '<img'; then
  sed -i '/^\.hero-in img{/d;/^  \.hero-in img{/d' "$F"
  echo "  tote Regeln .hero-in img entfernt (kein Logo mehr im Hero)"
fi

# --- Bildpanel im "Warum Office Dogs"-Block ---------------------------------
# Das Design zeigt Julia in einem 200-px-Kreis. Das Bild traegt den ganzen
# Abschnitt (Trainerin mit eigenem Hund) und soll deshalb gross zu sehen sein:
# statt des Kreisausschnitts ein Panel ueber die halbe Kartenbreite, das bis an
# die Kante laeuft und so hoch ist wie der Text daneben.
#
# Als <img> statt CSS-Hintergrund, aus drei Gruenden: es steht unter der Falz
# und kann so per loading="lazy" wirklich nachgeladen werden, es bekommt einen
# Alt-Text, und es kann per srcset mehrere Breiten anbieten — ein
# Hintergrundbild haette nichts davon.
#
# sizes: HIER STAND BIS ZUM 02.09.2026 EIN DENKFEHLER, bitte nicht zurueckbauen.
# Er lautete: "auf dem Desktop ist das Panel die halbe Karte, also rund 570 px"
# -- und daraus folgte sizes="570px". Die Boxbreite stimmt auch, sie ist bloss
# nicht die Zahl, die srcset braucht. Das Panel ist naemlich so HOCH wie die
# Textspalte daneben (gemessen 719-737 px) und damit hochkant, waehrend die
# Quelle quer liegt. object-fit:cover fuellt also ueber die HOEHE und malt das
# Bild dabei rund 1104 CSS-px breit -- fast doppelt so breit wie die Box, der
# Rest faellt links und rechts weg. Mit sizes="570px" holte der Browser
# folgerichtig die 620er und zog sie auf 1104 px: 1,8x hoch, und das sieht man
# dem Fell an. sizes muss die GEMALTE Breite nennen, nicht die Boxbreite.
#
# Darum jetzt <picture> mit zwei Kandidatenlisten -- ober- und unterhalb von
# 1020 px hat das Panel schlicht eine andere Geometrie:
#   Desktop  sizes="1104px", Kandidaten 1240 (1x, 225 KB), 1656 (dpr 1,25/1,5,
#            369 KB -- Windows auf 125/150 %) und 2208 (2x, 598 KB)
#   Mobil    .portrait liegt auf aspect-ratio 3/2, gemalte Breite = Boxbreite =
#            100vw; die Liste endet bewusst bei 1240, sonst holt sich ein
#            430-px-Telefon mit dpr 3 (430*3=1290) die 598-KB-Datei.
PIC="<picture>"
PIC="$PIC<source media=\"(max-width:1020px)\" sizes=\"100vw\""
PIC="$PIC srcset=\"assets/julia-mit-hund-620.jpg 620w, assets/julia-mit-hund-1240.jpg 1240w\">"
PIC="$PIC<img class=\"portrait\" src=\"assets/julia-mit-hund-1240.jpg\""
PIC="$PIC srcset=\"assets/julia-mit-hund-1240.jpg 1240w, assets/julia-mit-hund-1656.jpg 1656w, assets/julia-mit-hund-2208.jpg 2208w\""
PIC="$PIC sizes=\"1104px\""
PIC="$PIC width=\"1240\" height=\"828\" loading=\"lazy\" decoding=\"async\""
PIC="$PIC alt=\"Julia Doubrawa sitzt entspannt in einem Sessel in einem hellen Loungebereich, ihr Hund wartet ruhig neben ihr\">"
PIC="$PIC</picture>"
must_sed "s|<div class=\"portrait\"></div>|$PIC|" "<div class=\"portrait\"></div>"

# Karte: Innenabstand wandert vom Container in die Textspalte, damit das Bild
# buendig abschliesst. overflow:hidden haelt es in den runden Ecken.
must_sed "s|^\.quote-in{.*}$|.quote-in{display:grid;grid-template-columns:1fr 1fr;align-items:stretch;background:var(--cream);border-radius:var(--r);overflow:hidden}\n.quote-in>div{padding:clamp(30px,4vw,56px)}|" \
         "^\.quote-in{"
# object-position 42%: Julia sitzt bei 25 % der Bildbreite, der Hund bei 58 % --
# dazwischen liegt der Ausschnitt, der beide zeigt.
#
# ACHTUNG: index.html steht seit dem 12.08.2026 auf 47 % plus einer Ausnahme
# @media (min-width:1240px) mit 52 %. Grund war die auf vier Absaetze
# gewachsene Textspalte — der Kasten wurde hoeher und das cover-Fenster damit
# SCHMALER, wodurch der Hund rechts herausfiel. Die 42 % hier sind der alte
# Stand des Designs; beim Uebernehmen den Wert aus index.html behalten.
# Grid-Item ist jetzt das <picture>, also traegt es die Panelmasse und das
# <img> fuellt es nur aus. display:contents auf dem <picture> waere eleganter,
# faellt aber aus: das <img> wuerde zwar Grid-Item, sein height:100% findet
# dann keine definite Bezugshoehe mehr und klappt auf die Eigenhoehe des
# Bildes zusammen -- gemessen 379 statt 737 px.
must_sed "s|^\.portrait{.*}$|.quote-in>picture{display:block;min-height:340px}\n.portrait{width:100%;height:100%;object-fit:cover;object-position:42% 50%;display:block}|" \
         "^\.portrait{"

# Zwei Regeln aus dem Design sind auf den Kreis zugeschnitten und muessen fuer
# das Panel nachgezogen werden. Sie stehen in einer Sammelregel zusammen mit
# .approach-in und .pkg, lassen sich also nicht einzeln herausoperieren —
# deshalb als Nachtrag ans Ende des Stylesheets, wo die Kaskade sie gewinnen
# laesst.
cat > "$DST/.css-patch.tmp" <<'CSS'
/* Die kleinen Grossbuchstaben-Zeilen ueber den Ueberschriften. `.label` legt
   sie auf 11px/600 fest, aber in fuenf von neun Faellen gewinnt eine
   Absatzregel des jeweiligen Abschnitts (`.hero p`, `.value-head p`,
   `.approach p`, `.pkg-l>p`, `.quote-in p`, `.cta p`) -- alle sind
   Klasse+Element und damit spezifischer als die blosse Klasse. Ergebnis waren
   fuenf verschiedene Groessen zwischen 11 und 18 px, im Hero mit 18px/300 so
   gross, dass die Zeile umbrach. `p.label` ist gleich spezifisch und steht
   weiter hinten, gewinnt also. max-width und margin-bottom muessen mit: 50ch
   waeren bei 11px keine 300px und wuerden weiter umbrechen, und die geerbten
   26-32px Abstand rissen Luecken, die es in den korrekt gerenderten
   Abschnitten (dort 16px) nicht gibt. margin-bottom statt margin, damit das
   zentrierende `margin:0 auto` im Kontaktblock erhalten bleibt. */
p.label{font-size:11px;font-weight:600;line-height:1.6;max-width:none;margin-bottom:0}

/* Bildpanel im "Warum Office Dogs"-Block, schmale Viewports: ueber dem Text,
   volle Breite. Der 28-px-Gap der Sammelregel wuerde das buendige Panel
   wieder abloesen, und justify-items:start liesse das <img> auf seine
   Eigenbreite zusammenfallen. */
@media (max-width:1020px){
  .quote-in{gap:0;justify-items:stretch}
  .quote-in>picture{min-height:0}
  .portrait{height:auto;aspect-ratio:3/2}
}

/* Hero-Schleier auf Telefonen. Der Verlauf des Designs hat seine helle Delle
   bei 32 % Hoehe und wird erst ab 72 % richtig dunkel — das passt zum Desktop,
   wo der Textblock bei rund 56 % beginnt. Auf einem Telefon umbricht derselbe
   Text auf neun Zeilen und faengt schon bei 42 % an: die Kicker-Zeile steht
   dann genau in der Delle. Gemessen an den Glyphen-Pixeln (inklusive
   Textschatten) kam sie dort auf 3,7:1 gegen die geforderten 4,5:1 — und zwar
   bei JEDER horizontalen Ankerung, das Problem hing nie am Bildausschnitt.
   Hier wandert die Delle auf 20 % und die dunkle Rampe beginnt bei 42 %, also
   dort, wo der Text beginnt. Ergebnis 5,0:1. Bewusst der kleinste Wert, der
   traegt: 0.38 haette mit 4,66:1 zu wenig Luft gelassen, 0.46 nahm dem Foto
   sichtbar zu viel.
   660px ist der Telefon-Breakpoint, den das Design ohnehin schon nutzt. Der
   Umschlagpunkt liegt gemessen zwischen 500 und 560 px Breite; die paar
   Pixel dazwischen bekommen etwas mehr Schleier als noetig — das ist mir ein
   fuenfter Breakpoint nicht wert. */
@media (max-width:660px){
  .hero-overlay{background:
    linear-gradient(to right,oklch(22% 0.04 250 / .62) 0%,oklch(22% 0.04 250 / .24) 58%,oklch(22% 0.04 250 / .05) 100%),
    linear-gradient(to bottom,oklch(24% 0.04 250 / .42) 0%,oklch(24% 0.04 250 / .14) 20%,oklch(22% 0.04 250 / .42) 42%,oklch(22% 0.04 250 / .66) 74%,oklch(18% 0.04 250 / .88) 100%)}
}
CSS
awk -v s="$DST/.css-patch.tmp" '
  /^<\/style>$/ && !done { while ((getline line < s) > 0) print line; done=1 }
  { print }' "$F" > "$F.tmp" && mv "$F.tmp" "$F"
rm -f "$DST/.css-patch.tmp"
echo "  Bildpanel statt Portrait-Kreis eingebaut"

# --- Struktur / Barrierefreiheit -------------------------------------------
# 1) <main>-Landmark. Das Design liefert nav/header/footer, aber kein <main> —
#    Screenreader haben damit keinen "zum Hauptinhalt"-Sprungpunkt. Beide
#    Anker sind auf der Seite eindeutig, und die mobile Nav (div.mnav) steht
#    davor, bleibt also korrekterweise ausserhalb.
if ! grep -q '<main' "$F"; then
  sed -i 's|<header class="hero"|<main>\n<header class="hero"|' "$F"
  sed -i 's|<footer>|</main>\n<footer>|' "$F"
  echo "  <main>-Landmark ergänzt"
fi

# 2) Das Logo steht zweimal identisch im Markup: in der Nav (dort trägt es die
#    Bedeutung "Office Dogs") und in der Kontakt-Sektion, wo es rein
#    dekorativ ist. Screenreader lesen es sonst doppelt vor. Der sed-Bereich
#    grenzt auf die cta-Section ein, sonst wäre das zweite Vorkommen vom
#    ersten nicht zu unterscheiden.
sed -i '/<section class="cta"/,/<\/section>/ s|\(<img class="badge"[^>]*\)alt="Office Dogs"|\1alt=""|' "$F"

# --- SEO / Social / Performance --------------------------------------------
# title + description liefert das Design (Single Source of Truth); hier kommen
# nur die Dinge dazu, die das Design-Tool nicht ausgibt:
#   - canonical, OpenGraph, Twitter-Card
#   - Favicon-Varianten: das Design liefert nur SVG. PNG als Fallback für
#     ältere Browser, apple-touch-icon für den iOS-Homescreen.
#   - Preload des Heros: der liegt als CSS-Hintergrund in .hero-img und wird
#     dadurch erst nach dem CSS-Parse entdeckt. Er ist aber das grösste
#     Element above the fold, also der LCP-Kandidat — ein Preload mit
#     fetchpriority=high zieht ihn nach vorn.
inject_seo() {
  local f="$1"
  grep -q '<link rel="canonical"' "$f" && { echo "  SEO bereits vorhanden"; return; }

  local title=$(grep -oE '<title>[^<]+</title>' "$f" | head -1 | sed 's/<title>//;s|</title>||')
  local desc=$(grep -oE '<meta name="description" content="[^"]+"' "$f" | head -1 | sed 's|.*content="||;s|"$||')

  local block="<link rel=\"canonical\" href=\"${BASE}/\">\n\
<meta name=\"theme-color\" content=\"#2b3444\">\n\
<meta property=\"og:type\" content=\"website\">\n\
<meta property=\"og:site_name\" content=\"Office Dogs\">\n\
<meta property=\"og:locale\" content=\"de_DE\">\n\
<meta property=\"og:title\" content=\"${title}\">\n\
<meta property=\"og:description\" content=\"${desc}\">\n\
<meta property=\"og:url\" content=\"${BASE}/\">\n\
<meta property=\"og:image\" content=\"${BASE}/assets/og-office-dogs.jpg\">\n\
<meta property=\"og:image:width\" content=\"1200\">\n\
<meta property=\"og:image:height\" content=\"630\">\n\
<meta property=\"og:image:alt\" content=\"Frau am Schreibtisch in einem offenen Büro streichelt ihren großen hellen Hund, der entspannt neben ihr auf dem Boden liegt\">\n\
<meta name=\"twitter:card\" content=\"summary_large_image\">\n\
<link rel=\"icon\" type=\"image/png\" href=\"/assets/favicon-192.png\">\n\
<link rel=\"apple-touch-icon\" href=\"/assets/apple-touch-icon.png\">\n\
<link rel=\"preload\" as=\"image\" href=\"/assets/hero-office-dogs.jpg\" fetchpriority=\"high\">"

  # ASCII GS (0x1d) als sed-Delimiter — kommt in HTML/URLs nie vor.
  local D=$(printf '\035')
  sed -i "s${D}</title>${D}</title>\n${block}${D}" "$f"
  echo "  SEO/OG injiziert"
}
inject_seo "$F"

# Schema.org: eigenständige ProfessionalService-Entität, die per
# parentOrganization auf Adventure Dogs verweist. Adresse/Telefon sind
# identisch zum Hauptbetrieb (gleiche Betreiberin).
#
# build-schema.py ergänzt den statischen Rumpf um das konkrete Angebot und
# liest Preis, Paketname und Leistungsposten dafür aus der Seite — damit
# kann die Preisangabe in den strukturierten Daten nicht von der sichtbaren
# Seite abdriften.
inject_schema() {
  local f="$1"
  grep -q 'application/ld+json' "$f" && { echo "  Schema bereits vorhanden"; return; }
  py "$DST/tools/build-schema.py" "$f" "$DST/.schema.tmp"
  # Per awk vor </body> einfügen statt per sed — der JSON-Block enthält
  # Zeichen (&, \, /), die in einem sed-Replacement escapt werden müssten.
  awk -v s="$DST/.schema.tmp" '
    /<\/body>/ && !done { while ((getline line < s) > 0) print line; done=1 }
    { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  rm -f "$DST/.schema.tmp"
  echo "  Schema.org injiziert"
}
inject_schema "$F"

# --- Bericht ---------------------------------------------------------------
# Der eigentliche Zweck des Import-Laufs: zeigen, wie weit Export und Quelle
# auseinander sind. Ein blosses "fertig" waere hier wertlos — die Zahl darunter
# ist die Entscheidungsgrundlage dafuer, ob sich das Uebernehmen ueberhaupt
# lohnt oder ob der Export laengst hinterherhinkt.
echo
echo "──────────────────────────────────────────────────────────────────────"
if [ -f "$DST/index.html" ]; then
  WEG=$(diff "$DST/index.html" "$F" | grep -c '^<' || true)
  NEU=$(diff "$DST/index.html" "$F" | grep -c '^>' || true)
  echo "index.neu.html steht bereit. index.html wurde NICHT angefasst."
  echo
  echo "  $WEG Zeilen stehen nur in index.html (gingen beim Uebernehmen verloren)"
  echo "  $NEU Zeilen stehen nur in index.neu.html (kaemen neu dazu)"
  echo
  echo "Vergleichen:   diff index.html index.neu.html"
  echo "Aufraeumen:    rm index.neu.html"
else
  echo "index.neu.html steht bereit (index.html existiert nicht)."
fi
echo "──────────────────────────────────────────────────────────────────────"
