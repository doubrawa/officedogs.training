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
SRC="C:/DATA/Claude/design-extract-v52"
PAGE="Office Dogs Vollbild Logo.html"
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="https://officedogs.training"
MAIN="https://adventuredogs.training"

[ -f "$SRC/$PAGE" ] || { echo "FEHLER: $SRC/$PAGE nicht gefunden"; exit 1; }

F="$DST/index.html"
cp "$SRC/$PAGE" "$F"
echo "index.html aus '$PAGE' erzeugt"

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
# Der Export liefert den Hero als 1,9-MB-PNG. optimize-images.ps1 macht daraus
# ein ~140-KB-JPG; die Referenz im HTML muss mitwandern.
sed -i "s|assets/hero-office-dogs\.png|assets/hero-office-dogs.jpg|g" "$F"

powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "$(cygpath -w "$DST/tools/optimize-images.ps1")" \
  -Src "$(cygpath -w "$SRC/assets")" -Dst "$(cygpath -w "$DST/assets")"

# Logo direkt übernehmen (SVG, ~30 KB — keine Optimierung nötig).
cp "$SRC/assets/logo-office-dogs.svg" "$DST/assets/"

# --- SEO / Social ----------------------------------------------------------
# title + description liefert das Design (Single Source of Truth); hier kommen
# nur die Dinge dazu, die das Design-Tool nicht ausgibt.
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
<meta name=\"twitter:card\" content=\"summary_large_image\">"

  # ASCII GS (0x1d) als sed-Delimiter — kommt in HTML/URLs nie vor.
  local D=$(printf '\035')
  sed -i "s${D}</title>${D}</title>\n${block}${D}" "$f"
  echo "  SEO/OG injiziert"
}
inject_seo "$F"

# Schema.org: eigenständige ProfessionalService-Entität, die per
# parentOrganization auf Adventure Dogs verweist. Adresse/Telefon sind
# identisch zum Hauptbetrieb (gleiche Betreiberin).
inject_schema() {
  local f="$1"
  grep -q 'application/ld+json' "$f" && { echo "  Schema bereits vorhanden"; return; }
  # Per awk vor </body> einfügen statt per sed — der JSON-Block enthält
  # Zeichen (&, \, /), die in einem sed-Replacement escapt werden müssten.
  awk -v s="$DST/tools/schema.json.html" '
    /<\/body>/ && !done { while ((getline line < s) > 0) print line; done=1 }
    { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
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
