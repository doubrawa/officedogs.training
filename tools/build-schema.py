"""Baut den JSON-LD-Block fuer index.html.

Die statischen Felder (Adresse, Telefon, Gebiet, Mutterorganisation) stehen in
tools/schema.json.html. Dazu kommt hier das konkrete Angebot -- Preis, Paketname
und die Leistungsposten werden AUS DER SEITE gelesen, nicht noch einmal
hingeschrieben.

Warum der Umweg: strukturierte Daten, die eine Preisangabe wiederholen, laufen
frueher oder spaeter aus dem Ruder. Julia aendert den Preis im Design, die
Seite zeigt den neuen -- und Google bekommt monatelang den alten serviert, ohne
dass es jemandem auffaellt. Google wertet das als irrefuehrend. Gelesen statt
gespiegelt kann das nicht passieren.

Aufruf (macht _rederive.sh): py tools/build-schema.py <index.html> <ausgabe>
"""
import html
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BASE = "https://officedogs.training"


def text_of(pattern: str, quelle: str, was: str) -> str:
    """Erster Treffer der ersten Gruppe, HTML-Entities aufgeloest.

    re.S, weil die Muster ueber Zeilengrenzen laufen (der Paketname steht ein
    paar Zeilen unter dem umschliessenden div).
    """
    m = re.search(pattern, quelle, re.S)
    if not m:
        raise SystemExit(f"FEHLER: {was} nicht in index.html gefunden ({pattern})")
    return html.unescape(m.group(1)).strip()


def preis_zahl(roh: str) -> str:
    """'649 €' -> '649', '1.299,50 €' -> '1299.50'. Schema.org will einen Punkt."""
    m = re.search(r"([\d.,]+)", roh)
    if not m:
        raise SystemExit(f"FEHLER: keine Zahl in der Preisangabe '{roh}'")
    return m.group(1).replace(".", "").replace(",", ".")


def main() -> int:
    quelle = Path(sys.argv[1]).read_text(encoding="utf-8")
    ziel = Path(sys.argv[2])

    # Rumpf aus schema.json.html: erste und letzte Zeile sind die <script>-Tags.
    rohdatei = (REPO / "tools" / "schema.json.html").read_text(encoding="utf-8")
    daten = json.loads("\n".join(rohdatei.strip().splitlines()[1:-1]))

    preis = preis_zahl(text_of(r'<div class="price">([^<]+)</div>', quelle, "Preis"))
    paket = text_of(r'<div class="pkg-l">.*?<h2>([^<]+)</h2>', quelle, "Paketname")
    posten = [html.unescape(t).strip()
              for t in re.findall(r"</span>([^<]+)</li>", quelle)]
    if not posten:
        raise SystemExit("FEHLER: keine Leistungsposten in .pkg-list gefunden")

    # Kein valueAddedTaxIncluded: Julia ist Kleinunternehmerin nach § 19 UStG,
    # es wird gar keine Umsatzsteuer erhoben. Weder "true" noch "false" waere
    # dafuer richtig, also lieber nichts behaupten.
    daten["makesOffer"] = {
        "@type": "Offer",
        "name": paket,
        "price": preis,
        "priceCurrency": "EUR",
        "availability": "https://schema.org/InStock",
        "url": f"{BASE}/#paket",
        "itemOffered": {
            "@type": "Service",
            "name": paket,
            "serviceType": daten.get("serviceType", "Bürohunde-Beratung"),
            "provider": {"@id": f"{BASE}/#business"},
            "hasOfferCatalog": {
                "@type": "OfferCatalog",
                "name": "Enthaltene Leistungen",
                "itemListElement": [
                    {"@type": "Offer",
                     "itemOffered": {"@type": "Service", "name": p}}
                    for p in posten
                ],
            },
        },
    }

    ziel.write_text(
        '<script type="application/ld+json">\n'
        + json.dumps(daten, ensure_ascii=False, indent=2)
        + "\n</script>\n",
        encoding="utf-8",
    )
    print(f"  Schema: Angebot {preis} EUR, {len(posten)} Leistungsposten "
          f"aus der Seite gelesen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
