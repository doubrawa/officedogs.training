#!/usr/bin/env python3
"""Prueft die Website vor dem Commit.

Aufruf:  py tools/check-site.py        (oder: python3 tools/check-site.py)

Das Gegenstueck zu tools/check-site.py im Hauptrepo, auf diese Site
zugeschnitten. Geprueft wird:

  1. Seiten und Sitemap - liegt jede Seite in sitemap.xml und umgekehrt?
  2. SEO               - hat jede Seite title, description, canonical, og:*,
                         viewport, und zeigt das canonical auf die eigene URL?
  3. Verweise          - loesen alle internen href/src auf eine Datei auf?
  4. Bilder            - keine Ausreisser bei Massen und Gewicht
  5. Seitengewicht     - bleibt jede Seite unter dem Budget?

FEHLER blockieren (Exit 1), WARNUNG nicht. tools/hooks/pre-commit ruft das
Skript auf, damit niemand mehr daran denken muss.

Das JSON-LD prueft nicht dieses Skript, sondern tools/build-schema.py --check:
dort wird der Block aus dem Markup nachgerechnet statt nur auf Vorhandensein
geklopft. Der Hook ruft beide auf.

Ohne Seitenliste, anders als im Hauptrepo (dort tools/pages.tsv): hier gibt es
zwei Seiten, und welche das sind, steht auf der Platte. Genau deshalb ist
Pruefung 1 wichtig - die URL-Liste in tools/generate-sitemap.sh ist fest
verdrahtet und muesste bei einer dritten Seite von Hand mitwachsen.
"""
import os
import re
import struct
import sys
import xml.etree.ElementTree as ET

WURZEL = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = 'https://officedogs.training'

# Ordner, die nicht zur Website gehoeren. tools/ ist seit dem 09.09.2026
# zusaetzlich in _config.yml ausgeschlossen und wird gar nicht ausgeliefert.
IGNORIERT = {'.git', 'tools', 'assets'}

# Seiten, die absichtlich in keiner Sitemap stehen und deren <head> nicht dem
# Pflichtprogramm unterliegt. 404.html traegt noindex und wird nie verlinkt.
SEITEN_AUSNAHMEN = {'404.html'}

# Dateien in assets/, auf die bewusst keine Seite zeigt.
#
# Der One-Pager ist ein Druckstueck zum Versenden per Mail, kein Seitenelement
# (siehe DEPLOY.md). Das PDF liegt trotzdem im Repo, damit es unter einer
# stabilen URL abrufbar ist; die PNG-Vorschau daneben ist gitignoriert und
# taucht nur in Arbeitskopien auf, in denen build-onepager.ps1 -Preview lief.
NICHT_VERLINKT = {'office-dogs-onepager.pdf', 'office-dogs-onepager.png'}

# Was im <head> jeder gelisteten Seite stehen muss.
PFLICHT_TAGS = [
    ('title',       r'<title>[^<]{10,}</title>'),
    ('description', r'<meta\s+name="description"\s+content="[^"]{30,}"'),
    ('canonical',   r'<link\s+rel="canonical"\s+href="https://officedogs\.training[^"]*"'),
    ('og:title',    r'property="og:title"'),
    ('og:image',    r'property="og:image"'),
    ('viewport',    r'<meta\s+name="viewport"'),
]

# JSON-LD gehoert auf die Startseite (ProfessionalService mit Angebot und
# Preis). Auf dem Impressum waere es Beiwerk, deshalb wird es dort nicht
# angemahnt - eine Warnung, die bei jedem Lauf erscheint, liest nach der
# dritten Woche niemand mehr.
SCHEMA_SEITEN = {'index.html'}

# Seitenbudget: Summe aus HTML + Schriften + ALLEN referenzierten Bildern.
#
# Das ist bewusst nicht das, was ein Besucher beim ersten Aufruf laedt. Allein
# die vier srcset-Fassungen des Portraits wiegen zusammen 1259 KB, geladen wird
# davon genau eine; dazu haengt das Portrait an loading="lazy" und kommt erst
# beim Scrollen. Die Zahl taugt also nicht als Ladezeit, wohl aber als
# Sperrklinke gegen Wachstum. Gemessen am 09.09.2026: Startseite 1752 KB,
# Impressum 103 KB. Die Schwellen liegen knapp darueber, damit heute alles
# durchgeht und ein unbedachtes weiteres Grossbild auffaellt.
SEITE_FEHLER_KB = 2200
SEITE_WARNUNG_KB = 1900

# Einzelbild. Die Breite ist hart - dieselbe Grenze, die auch das Hauptrepo
# zieht; das breiteste Bild hier ist die 2208er-Fassung des Portraits. Die
# Gewichtsschwelle gilt nur fuer Bilder, die ein Besucher wirklich laedt:
# og-office-dogs.jpg holt kein Browser, sondern einmal ein Social-Crawler.
BILD_MAX_BREITE = 2400
BILD_MAX_KB = 700

fehler = []
warnungen = []


def melde_fehler(bereich, text):
    fehler.append((bereich, text))


def melde_warnung(bereich, text):
    warnungen.append((bereich, text))


def html_dateien():
    """Alle HTML-Dateien der Website, relativ zur Wurzel, mit / als Trenner."""
    gefunden = []
    for ordner, unter, dateien in os.walk(WURZEL):
        unter[:] = [u for u in unter if u not in IGNORIERT and not u.startswith('.')]
        for name in dateien:
            if name.endswith('.html'):
                rel = os.path.relpath(os.path.join(ordner, name), WURZEL)
                gefunden.append(rel.replace(os.sep, '/'))
    return sorted(gefunden)


def seiten():
    """Die Seiten, die in der Sitemap stehen und den <head>-Pflichten unterliegen."""
    return [d for d in html_dateien() if d not in SEITEN_AUSNAHMEN]


def url_of(datei):
    """'index.html' -> '/', 'impressum/index.html' -> '/impressum/'."""
    if datei == 'index.html':
        return '/'
    if datei.endswith('/index.html'):
        return '/' + datei[:-len('index.html')]
    return '/' + datei


def webp_masse(kopf):
    """(Breite, Hoehe) aus einem WebP-Kopf. Drei Varianten, drei Ablagen.

    Heute liegt hier kein WebP; die Zweige stehen trotzdem da, damit ein
    spaeter dazugelegtes Bild nicht stillschweigend ungeprueft durchlaeuft.
    """
    art = kopf[12:16]
    if art == b'VP8X':                       # erweitert: Leinwandgroesse, je 24 Bit, minus 1
        b = int.from_bytes(kopf[24:27], 'little') + 1
        h = int.from_bytes(kopf[27:30], 'little') + 1
        return b, h
    if art == b'VP8 ':                       # verlustbehaftet: je 14 Bit
        b, h = struct.unpack('<HH', kopf[26:30])
        return b & 0x3FFF, h & 0x3FFF
    if art == b'VP8L':                       # verlustfrei: 14 Bit gepackt ab Bit 0
        n = int.from_bytes(kopf[21:25], 'little')
        return (n & 0x3FFF) + 1, ((n >> 14) & 0x3FFF) + 1
    return None


def bildmasse(pfad):
    """(Breite, Hoehe) fuer JPEG, PNG und WebP, sonst None."""
    try:
        with open(pfad, 'rb') as f:
            kopf = f.read(32)
            if kopf[:8] == b'\x89PNG\r\n\x1a\n':
                return struct.unpack('>II', kopf[16:24])
            if kopf[:4] == b'RIFF' and kopf[8:12] == b'WEBP':
                return webp_masse(kopf)
            if kopf[:2] != b'\xff\xd8':
                return None
            f.seek(2)
            daten = f.read()
        i = 0
        while i < len(daten) - 9:
            if daten[i] != 0xFF:
                i += 1
                continue
            marker = daten[i + 1]
            if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                          0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
                hoehe, breite = struct.unpack('>HH', daten[i + 5:i + 9])
                return breite, hoehe
            if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            i += 2 + struct.unpack('>H', daten[i + 2:i + 4])[0]
    except Exception:
        return None
    return None


# --------------------------------------------------------- 1. Seiten und Sitemap
def pruefe_sitemap(liste):
    pfad = os.path.join(WURZEL, 'sitemap.xml')
    if not os.path.exists(pfad):
        melde_fehler('Sitemap', 'sitemap.xml fehlt - generate-sitemap.sh laufen lassen')
        return
    try:
        baum = ET.parse(pfad)
    except ET.ParseError as e:
        melde_fehler('Sitemap', 'sitemap.xml ist kein wohlgeformtes XML: %s' % e)
        return

    locs = {e.text for e in baum.getroot().iter() if e.tag.endswith('}loc') and e.text}
    soll = {BASE + url_of(d) for d in liste}
    for fehlt in sorted(soll - locs):
        melde_fehler('Sitemap',
                     '%s fehlt in sitemap.xml - die URL-Liste in '
                     'tools/generate-sitemap.sh mitwachsen lassen' % fehlt)
    for zuviel in sorted(locs - soll):
        melde_fehler('Sitemap',
                     '%s steht in sitemap.xml, aber es gibt keine solche Seite' % zuviel)

    # lastmod muss ein Datum sein, sonst ignoriert Google es stillschweigend.
    for e in baum.getroot().iter():
        if e.tag.endswith('}lastmod') and not re.fullmatch(r'\d{4}-\d{2}-\d{2}', (e.text or '').strip()):
            melde_fehler('Sitemap', 'lastmod "%s" ist kein Datum im Format JJJJ-MM-TT' % e.text)


# ------------------------------------------------------------------------ 2. SEO
def pruefe_seo(liste):
    for datei in liste:
        pfad = os.path.join(WURZEL, datei.replace('/', os.sep))
        text = open(pfad, encoding='utf-8', errors='ignore').read()
        kopf = text[:text.find('</head>')] if '</head>' in text else text
        for name, muster in PFLICHT_TAGS:
            if not re.search(muster, kopf, re.I):
                melde_fehler('SEO', '%s: %s fehlt oder ist zu kurz' % (datei, name))
        if datei in SCHEMA_SEITEN and not re.search(r'application/ld\+json', text, re.I):
            melde_warnung('SEO', '%s: JSON-LD fehlt' % datei)

        # canonical muss auf die eigene URL zeigen, nicht auf eine andere Seite.
        treffer = re.search(r'<link\s+rel="canonical"\s+href="([^"]+)"', kopf, re.I)
        if treffer:
            soll = BASE + url_of(datei)
            if treffer.group(1).rstrip('/') + '/' != soll.rstrip('/') + '/':
                melde_fehler('SEO', '%s: canonical zeigt auf %s statt auf %s'
                             % (datei, treffer.group(1), soll))

        # Die Description wird in den Suchergebnissen bei rund 155 Zeichen
        # abgeschnitten, der Titel bei rund 60. Beides ist kein Fehler, aber
        # der abgeschnittene Rest ist verschenkt.
        m = re.search(r'<title>([^<]+)</title>', kopf, re.I)
        if m and len(m.group(1)) > 60:
            melde_warnung('SEO', '%s: title ist %d Zeichen lang (Anzeige endet bei rund 60)'
                          % (datei, len(m.group(1))))
        m = re.search(r'<meta\s+name="description"\s+content="([^"]+)"', kopf, re.I)
        if m and len(m.group(1)) > 155:
            melde_warnung('SEO', '%s: description ist %d Zeichen lang (Anzeige endet bei rund 155)'
                          % (datei, len(m.group(1))))


# -------------------------------------------------------------------- 3. Verweise
def ziel_pfad(ordner, ziel):
    """Verweisziel -> Pfad auf der Platte, oder None wenn nichts zu pruefen ist."""
    if ziel.startswith(('http', 'mailto:', 'tel:', 'data:', '//', '#')):
        return None
    sauber = ziel.split('?')[0].split('#')[0]
    if not sauber:
        return None
    basis = WURZEL if sauber.startswith('/') else ordner
    voll = os.path.normpath(os.path.join(basis, sauber.lstrip('/').replace('/', os.sep)))
    if os.path.isdir(voll):
        voll = os.path.join(voll, 'index.html')
    return voll


def pruefe_verweise():
    anzahl = 0
    for rel in html_dateien():
        pfad = os.path.join(WURZEL, rel.replace('/', os.sep))
        ordner = os.path.dirname(pfad)
        text = open(pfad, encoding='utf-8', errors='ignore').read()

        ziele = [t.group(1) for t in re.finditer(r'(?:href|src)="([^"#][^"]*)"', text)]

        # srcset traegt eine Kandidatenliste ("datei 620w, datei 1240w") und
        # faellt durch das Muster oben. Ohne diesen Zweig bleibt eine fehlende
        # Fassung unsichtbar: das <img> zeigt per src auf eine ANDERE Datei,
        # und nur ein Geraet mit passender Pixeldichte fordert die
        # verschwundene an. Nachgemessen am 09.09.2026 -- ein geloeschtes
        # julia-mit-hund-1656.jpg lief glatt durch, obwohl jedes
        # Windows-Notebook auf 125 oder 150 % Skalierung genau diese Datei holt.
        for treffer in re.finditer(r'srcset="([^"]+)"', text, re.I):
            ziele.extend(k.strip().split(' ')[0] for k in treffer.group(1).split(','))

        for ziel in ziele:
            voll = ziel_pfad(ordner, ziel)
            if voll is None:
                continue
            anzahl += 1
            if not os.path.exists(voll):
                melde_fehler('Verweise', '%s verweist auf %s - existiert nicht' % (rel, ziel))
    return anzahl


# ---------------------------------------------------------------------- 4. Bilder
def bildverwendung():
    """Trennt die Assets danach, wer sie laedt.

    Gerendert wird, was im <img>, in einem CSS-Hintergrund oder in einem
    Preload steht. Daneben gibt es Dateien, die im Quelltext stehen, ohne dass
    ein Besucher sie holt: og:image (einmal ein Social-Crawler), die Favicons,
    das Logo im JSON-LD. Die Gewichtsschwelle auf beide anzuwenden hiesse, ein
    og:image anzumahnen, das niemand herunterlaedt.
    """
    gerendert, irgendwo = set(), set()
    for rel in html_dateien():
        text = open(os.path.join(WURZEL, rel.replace('/', os.sep)),
                    encoding='utf-8', errors='ignore').read()
        for muster in (r'<img[^>]*?src="[^"]*assets/([^"]+)"',
                       r'<source[^>]*?srcset="([^"]+)"',
                       r'<img[^>]*?srcset="([^"]+)"',
                       r'url\(\s*[\'"]?[^)\'"]*assets/([^)\'"]+)',
                       r'<link[^>]*?rel="preload"[^>]*?href="[^"]*assets/([^"]+)"'):
            for m in re.finditer(muster, text, re.I):
                # srcset liefert eine Kandidatenliste ("datei 620w, datei 1240w"),
                # die einzeln aufgedroeselt werden muss.
                for stueck in m.group(1).split(','):
                    name = stueck.strip().split(' ')[0]
                    if 'assets/' in name:
                        name = name.split('assets/', 1)[1]
                    if name:
                        gerendert.add(name)
        # Fuer die Verwaisungsfrage zaehlt jede Erwaehnung, egal in welcher
        # Rolle. Eng gefasste Muster wuerden hier zuverlaessig danebengreifen.
        irgendwo.update(m.group(1) for m in re.finditer(r'assets/([A-Za-z0-9._%-]+)', text))
    return gerendert, irgendwo


def pruefe_bilder():
    ordner = os.path.join(WURZEL, 'assets')
    gerendert, irgendwo = bildverwendung()
    gezaehlt = 0
    for name in sorted(os.listdir(ordner)):
        pfad = os.path.join(ordner, name)
        if not os.path.isfile(pfad) or not name.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
            continue
        gezaehlt += 1
        masse = bildmasse(pfad)
        if not masse:
            continue
        breite, _hoehe = masse
        groesse = os.path.getsize(pfad)

        # Die Breite gilt fuer alle: ein 4000-px-Bild ist auch als og:image
        # falsch, und es zeigt, dass jemand ein Original ungeprueft abgelegt hat.
        if breite > BILD_MAX_BREITE:
            melde_fehler('Bilder', '%s ist %d px breit (max %d) - optimize-images.ps1 laufen lassen'
                         % (name, breite, BILD_MAX_BREITE))

        # Das Gewicht nur da, wo es ein Besucher bezahlt.
        if name in gerendert and groesse / 1024 > BILD_MAX_KB:
            melde_warnung('Bilder', '%s wiegt %d KB (Schwelle %d) - optimize-images.ps1 pruefen'
                          % (name, groesse / 1024, BILD_MAX_KB))

    verwaist = sorted(n for n in os.listdir(ordner)
                      if os.path.isfile(os.path.join(ordner, n))
                      and n not in irgendwo and n not in NICHT_VERLINKT)
    for name in verwaist:
        melde_warnung('Bilder', '%s wird von keiner Seite referenziert' % name)
    return gezaehlt


# --------------------------------------------------------------- 5. Seitengewicht
def pruefe_gewicht(liste):
    schriften = 0
    ordner = os.path.join(WURZEL, 'assets', 'fonts')
    if os.path.isdir(ordner):
        schriften = sum(os.path.getsize(os.path.join(ordner, n)) for n in os.listdir(ordner))
    zeilen = []
    for datei in liste:
        pfad = os.path.join(WURZEL, datei.replace('/', os.sep))
        text = open(pfad, encoding='utf-8', errors='ignore').read()
        assets = set(re.findall(r'assets/([A-Za-z0-9._%-]+\.(?:jpg|jpeg|png|webp|svg|gif))', text, re.I))
        gewicht = os.path.getsize(pfad) + schriften
        for a in assets:
            ap = os.path.join(WURZEL, 'assets', a)
            if os.path.exists(ap):
                gewicht += os.path.getsize(ap)
        kb = gewicht / 1024
        zeilen.append((kb, url_of(datei), len(assets)))
        if kb > SEITE_FEHLER_KB:
            melde_fehler('Gewicht', '%s waere %d KB schwer (Grenze %d KB)'
                         % (url_of(datei), kb, SEITE_FEHLER_KB))
        elif kb > SEITE_WARNUNG_KB:
            melde_warnung('Gewicht', '%s waere %d KB schwer (Warnschwelle %d KB)'
                          % (url_of(datei), kb, SEITE_WARNUNG_KB))
    return sorted(zeilen, reverse=True)


def main():
    liste = seiten()
    if not liste:
        print('FEHLER: keine HTML-Seiten gefunden.')
        return 1
    pruefe_sitemap(liste)
    pruefe_seo(liste)
    verweise = pruefe_verweise()
    bilder = pruefe_bilder()
    gewichte = pruefe_gewicht(liste)

    print('  %d Seiten, %d interne Verweise, %d Bilder in assets/'
          % (len(liste), verweise, bilder))
    if gewichte:
        kb, url, n = gewichte[0]
        print('  schwerste Seite: %s mit %d KB an Bildern insgesamt (%d Stueck);' % (url, kb, n))
        print('    beim ersten Aufruf laedt der Browser davon nur einen Bruchteil')
        print('    (lazy, und von den srcset-Fassungen genau eine).')

    for bereich, text in warnungen:
        print('  WARNUNG  [%s] %s' % (bereich, text))
    for bereich, text in fehler:
        print('  FEHLER   [%s] %s' % (bereich, text))

    if fehler:
        print('\n  %d Fehler - Commit besser erst nach der Korrektur.' % len(fehler))
        return 1
    print('  alles in Ordnung%s' % (' (%d Warnungen)' % len(warnungen) if warnungen else ''))
    return 0


if __name__ == '__main__':
    sys.exit(main())
