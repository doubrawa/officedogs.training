"""Verkleinert die ausgelieferten Web-Fonts auf das, was diese Seite braucht.

Hintergrund
-----------
google-webfonts-helper liefert fuer JEDES angeforderte Gewicht denselben
Variable Font aus, nur unter anderem Dateinamen. Die neun woff2-Dateien im
Hauptrepo sind in Wahrheit drei verschiedene Schriften:

    dm-sans-300/400/500/600.woff2          -> byte-identisch
    playfair-600/700/900.woff2             -> byte-identisch
    playfair-600-italic/700-italic.woff2   -> byte-identisch

Jede traegt die komplette Gewichtsachse (wght 100-1000 bei DM Sans) in der
gvar-Tabelle mit — allein 33 der 36 KB. Das CSS fordert aber je ein festes
Gewicht an, die Achse wird also nie genutzt.

Zwei Schritte:
  1. Instanzieren: Achse auf das im Dateinamen genannte Gewicht festzurren.
     Damit faellt gvar komplett weg. Das ist der grosse Hebel.
  2. Unicode-Subset: Zeichenvorrat auf Deutsch + Typografie eindampfen.
     Bringt wenig, weil die Quellen schon auf Latin beschnitten sind, kostet
     aber auch nichts.

Das Rendering aendert sich nicht: der Browser waehlt die Schnitte weiterhin
ueber die font-weight-Angaben der @font-face-Regeln, und jede Datei liefert
danach genau das Gewicht, unter dem sie deklariert ist.

NICHT Teil von _rederive.sh — Schriften aendern sich nicht mit einem
Design-Export. Nur laufen lassen, wenn ein Schnitt dazukommt oder die
Quelldateien getauscht werden.

Voraussetzung:  py -m pip install fonttools brotli
Aufruf:         py tools/subset-fonts.py
"""
import re
import sys
from pathlib import Path

from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset

sys.stdout.reconfigure(encoding="utf-8")

REPO = Path(__file__).resolve().parent.parent
# Quelle sind die ungekuerzten Originale im Hauptrepo — dort bleiben sie
# vollstaendig, weil adventuredogs.training sie unveraendert nutzt.
SRC = Path(sys.argv[1] if len(sys.argv) > 1
           else r"C:/DATA/Claude/adventuredogs.training/assets/fonts")
DST = REPO / "assets" / "fonts"

# Bewusst weiter gefasst als der aktuelle Textbestand (der braucht nur
# Latin-1 plus – „ €), damit eine Textaenderung im Design keine
# Tofu-Kaestchen produziert.
UNICODES = (
    "U+0020-007E,"      # Basis-Latin
    "U+00A0-00FF,"      # Latin-1: ä ö ü ß Ü § · é …
    "U+2010-2015,"      # Gedankenstriche
    "U+2018-201F,"      # Anfuehrungszeichen aller Art
    "U+2022,U+2026,"    # Bullet, Ellipse
    "U+2039-203A,"      # einfache Guillemets
    "U+20AC,U+2122"     # Euro, Trademark
)


def target_weight(name: str) -> int | None:
    """Gewicht aus dem Dateinamen: dm-sans-300.woff2 -> 300."""
    m = re.search(r"-(\d{3})(?:-italic)?\.woff2$", name)
    return int(m.group(1)) if m else None


def main() -> int:
    if not SRC.is_dir():
        print(f"FEHLER: Quellverzeichnis {SRC} nicht gefunden")
        return 1
    DST.mkdir(parents=True, exist_ok=True)

    before_total = after_total = 0
    print(f"Fonts instanzieren + subsetten (Quelle: {SRC}):")

    for src_file in sorted(SRC.glob("*.woff2")):
        before = src_file.stat().st_size
        font = TTFont(src_file)

        wght = target_weight(src_file.name)
        pinned = ""
        if "fvar" in font and wght is not None:
            font = instancer.instantiateVariableFont(
                font, {"wght": wght}, inplace=True, updateFontNames=False)
            pinned = f"wght={wght}"
        elif "fvar" in font:
            print(f"  WARNUNG: {src_file.name} ist variabel, aber im Namen "
                  f"steht kein Gewicht — Achse bleibt drin")

        options = subset.Options(
            flavor="woff2",
            layout_features=["*"],   # Kerning/Ligaturen behalten
            notdef_outline=True,
        )
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=subset.parse_unicodes(UNICODES))
        subsetter.subset(font)

        font.flavor = "woff2"
        out = DST / src_file.name
        font.save(out)
        font.close()

        after = out.stat().st_size
        before_total += before
        after_total += after
        print(f"  {src_file.name:<30} {before // 1024:>3} KB -> "
              f"{after // 1024:>3} KB  {pinned}")

    saved = 100 * (before_total - after_total) // before_total
    print("  " + "-" * 54)
    print(f"  {'gesamt':<30} {before_total // 1024:>3} KB -> "
          f"{after_total // 1024:>3} KB  (-{saved}%)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
