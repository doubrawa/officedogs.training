#!/bin/bash
# Schreibt sitemap.xml — die einzige erzeugte Datei dieser Site.
#
#   bash tools/generate-sitemap.sh
#
# Idempotent. Der pre-commit-Hook ruft das Skript selbst auf; von Hand braucht
# man es nur zur Kontrolle zwischendurch.
#
# Bewusst ohne Seitenliste wie im Hauptrepo (dort tools/pages.tsv): hier gibt
# es genau zwei Seiten, und eine dritte kommt nicht mehr dazu.
set -e
DST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="https://officedogs.training"

# lastmod je Seite: hat sich die Datei gegenüber HEAD geändert, ist heute das
# Datum der Änderung — sonst zählt der letzte Commit der Datei.
#
# Warum nicht einfach immer das Commit-Datum: die Sitemap entsteht VOR dem
# Commit, `git log` liefert also den Stand von vorher. Für eine gerade
# bearbeitete Seite stünde dort hartnäckig das Datum der vorherigen Runde. Das
# fällt nicht auf, solange Bearbeitung und Commit auf denselben Tag fallen —
# sonst steht dort ein Datum zu früh. Google gewichtet lastmod ohnehin nur,
# wenn es nachweislich stimmt.
#
# `diff HEAD` deckt Arbeitsverzeichnis UND Index ab, egal ob schon `git add`
# gelaufen ist. Im frisch initialisierten Repo (noch kein HEAD) scheitert es
# mit Exit 128 — dann greift ebenfalls das heutige Datum, was dort richtig ist.
# Beides steht in einer `if`-Bedingung, `set -e` greift also nicht.
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
