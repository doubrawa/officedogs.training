#!/bin/bash
# Import-Pipeline für officedogs.training.
#
# Die Seite wird im gemeinsamen claude.ai/design-Projekt "Adventure Dogs
# Training" gepflegt (Seite: "Office Dogs Vollbild Logo") und lebt trotzdem
# auf einer eigenen Domain/GitHub-Pages-Site. Dieses Script zieht genau
# diese eine Seite aus dem Export und macht daraus die Startseite hier.
#
# Workflow pro neuem Export:
#   1. "Adventure Dogs Training.zip" nach C:/DATA/Claude/design-extract-vN
#      entpacken (der gleiche Export, den auch das Hauptrepo benutzt)
#   2. SRC unten auf design-extract-vN setzen
#   3. bash tools/_rederive.sh
#   4. Diff prüfen, committen, pushen
#
# Bewusst schlank gehalten: keine Artikel-/Hub-/Bilder-Sitemap-Maschinerie
# wie im Hauptrepo — hier gibt es genau eine Seite.
set -e
SRC="C:/DATA/Claude/design-extract-v53"
PAGE="Office Dogs Vollbild Logo.html"
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="https://officedogs.training"
MAIN="https://adventuredogs.training"

[ -f "$SRC/$PAGE" ] || { echo "FEHLER: $SRC/$PAGE nicht gefunden"; exit 1; }

F="$DST/index.html"
cp "$SRC/$PAGE" "$F"
echo "index.html aus '$PAGE' erzeugt"

# Ersetzt ein Muster in index.html und bricht ab, wenn es gar nicht vorkommt.
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
must_sed "s|^<meta name=\"description\" content=\".*\">$|<meta name=\"description\" content=\"Bürohunde-Beratung für Unternehmen in Bayern: Analyse vor Ort, individueller Office Dog Guide und Praxis-Coaching – damit Hunde im Büro funktionieren.\">|" \
         "^<meta name=\"description\""

# --- E-Mail-Adresse --------------------------------------------------------
# Das Design liefert info@adventuredogs.training — die Adresse existiert nicht.
# Auf dieser Domain gilt julia@officedogs.training. Sobald das im
# claude.ai/design-Projekt korrigiert ist, läuft dieses sed einfach leer.
sed -i "s|info@adventuredogs\.training|julia@officedogs.training|g" "$F"

# --- Preisangabe -----------------------------------------------------------
# Julia ist Kleinunternehmerin nach § 19 UStG — es wird also gar keine
# Umsatzsteuer ausgewiesen. Der Zusatz "zzgl. MwSt." aus dem Design ist
# damit schlicht falsch und widerspricht dem eigenen Impressum.
# (Ab 2027 wird das Thema relevant, dann hier bewusst neu entscheiden.)
#
# Der Zusatz trug 28 px Abstand zum Button bei; beim Entfernen wandert der
# Ausgleich in die margin von .price, sonst klebt der Button am Preis.
# Beides passiert nur, wenn der Zusatz überhaupt noch da ist — sobald es im
# Design korrigiert ist, greift der Block gar nicht mehr.
if grep -q 'class="price-sub">zzgl\. MwSt\.' "$F"; then
  sed -i '/<div class="price-sub">zzgl\. MwSt\.<\/div>/d' "$F"
  sed -i 's|\(\.price{[^}]*\)margin:12px 0 7px}|\1margin:12px 0 34px}|' "$F"
  echo "  Preis: 'zzgl. MwSt.' entfernt (Kleinunternehmerregelung)"
fi

# --- Bilder ----------------------------------------------------------------
# Der Export referenziert den Hero als PNG; optimize-images.ps1 legt ein JPG ab.
must_sed "s|assets/hero-office-dogs\.png|assets/hero-office-dogs.jpg|g" \
         "assets/hero-office-dogs.png"

powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -w "$DST/tools/optimize-images.ps1")" \
  -Src   "$(cygpath -w "$SRC/assets")" \
  -Local "$(cygpath -w "$DST/tools/assets-src")" \
  -Dst   "$(cygpath -w "$DST/assets")"

# Hero-Ausschnitt. Das Design ankert 62%/bottom — das passte zum alten Motiv
# (ein Hund unter dem Schreibtisch). Das jetzige Bild zeigt ein Team am Tisch:
# oben die Gesichter, in der Mitte der Hund, unten nur Boden. Auf breiten
# Viewports beschneidet "cover" vertikal, und "bottom" wuerde ausgerechnet die
# Gesichter abschneiden — deshalb nach oben ankern. Horizontal (nur auf
# schmalen Viewports relevant) haelt 50% den Hund im Bild.
must_sed "s|\(assets/hero-office-dogs\.jpg') \)62% bottom|\150% 44%|" \
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
sed -i 's|text-shadow:0 1px 10px oklch(0% 0 0 / \.3)|text-shadow:0 1px 3px oklch(0% 0 0 / .5),0 2px 14px oklch(0% 0 0 / .4)|g' "$F"

must_sed "s|^\.hero \.label{color:oklch(93% 0.02 85)}$|.hero .label{color:oklch(93% 0.02 85);text-shadow:0 1px 3px oklch(0% 0 0 / .5),0 1px 14px oklch(0% 0 0 / .4)}|" \
         "^\.hero \.label{"

# --- Logo ------------------------------------------------------------------
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
# Alt-Text, und es kann per srcset zwei Breiten anbieten — ein
# Hintergrundbild haette nichts davon.
#
# sizes: auf dem Desktop ist das Panel die halbe Karte, also rund 570 px, egal
# wie breit das Fenster ist (die Karte deckelt bei 1240 px). Darunter stapelt
# das Layout und das Bild laeuft ueber die volle Breite. Damit waehlt ein
# normales Display die 620er Datei (70 KB) und nur ein 2x-Display die
# 1240er (224 KB).
IMG="<img class=\"portrait\" src=\"assets/julia-mit-hund-620.jpg\""
IMG="$IMG srcset=\"assets/julia-mit-hund-620.jpg 620w, assets/julia-mit-hund-1240.jpg 1240w\""
IMG="$IMG sizes=\"(max-width:1020px) 100vw, 570px\""
IMG="$IMG width=\"1240\" height=\"828\" loading=\"lazy\" decoding=\"async\""
IMG="$IMG alt=\"Julia Doubrawa sitzt entspannt in einem Sessel in einem hellen Loungebereich, ihr Hund wartet ruhig neben ihr\">"
must_sed "s|<div class=\"portrait\"></div>|$IMG|" "<div class=\"portrait\"></div>"

# Karte: Innenabstand wandert vom Container in die Textspalte, damit das Bild
# buendig abschliesst. overflow:hidden haelt es in den runden Ecken.
must_sed "s|^\.quote-in{.*}$|.quote-in{display:grid;grid-template-columns:1fr 1fr;align-items:stretch;background:var(--cream);border-radius:var(--r);overflow:hidden}\n.quote-in>div{padding:clamp(30px,4vw,56px)}|" \
         "^\.quote-in{"
# object-position 42%: Julia sitzt bei 25 % der Bildbreite, der Hund bei 58 % --
# dazwischen liegt der Ausschnitt, der beide zeigt.
must_sed "s|^\.portrait{.*}$|.portrait{width:100%;height:100%;min-height:340px;object-fit:cover;object-position:42% 50%;display:block}|" \
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
  .portrait{height:auto;min-height:0;aspect-ratio:3/2}
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
<meta property=\"og:image:alt\" content=\"Drei Kolleginnen und Kollegen an einem Bürotisch, einer streichelt einen Golden Retriever, der entspannt daneben sitzt\">\n\
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
# liest Preis, Paketname und Leistungsposten dafür aus index.html — damit
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

# --- sitemap.xml -----------------------------------------------------------
# lastmod je Seite aus dem letzten Commit der jeweiligen Datei.
# `|| true`: in einem frisch initialisierten Repo (noch kein Commit) liefert
# git log Exit 128 — das würde sonst wegen `set -e` das Script abbrechen.
lastmod_of() {
  local d=$(git -C "$DST" log -1 --format=%cd --date=short -- "$1" 2>/dev/null || true)
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

echo
echo "Fertig. Diff prüfen: git -C \"$DST\" status"
