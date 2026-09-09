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

Aufruf:  py tools/build-schema.py --check <index.html>
         py tools/build-schema.py <index.html> <ausgabe>

--check schreibt nichts, sondern vergleicht den JSON-LD-Block, der in der Datei
steht, mit dem, der sich aus ihrem Markup ergibt. Das ist seit dem
Rollenwechsel am 13.08.2026 der einzige Weg, auf dem die Zusage oben noch fuer
index.html gilt: geschrieben wird die Datei von Hand, gelesen wird sie hier.
Deshalb ruft tools/hooks/pre-commit genau diesen Aufruf vor jedem Commit auf.

Die zweite Form schreibt den Block in eine Datei, statt zu vergleichen. Sie
bediente frueher den Design-Import; geblieben ist sie fuer den Fall, dass der
Block in index.html einmal komplett neu gesetzt werden muss.
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
    """'649 €' -> '649', '1.299,50 €' -> '1299.50'. Schema.org will einen Punkt.

    Bekommt seit dem MwSt.-Zusatz auch Markup herein ('649 € <span ...>zzgl.
    MwSt.</span>'). Der erste Zahlentreffer ist der Preis; was danach kommt,
    interessiert hier nicht.
    """
    m = re.search(r"([\d.,]+)", roh)
    if not m:
        raise SystemExit(f"FEHLER: keine Zahl in der Preisangabe '{roh}'")
    return m.group(1).replace(".", "").replace(",", ".")


def main() -> int:
    argv = sys.argv[1:]
    pruefen = bool(argv) and argv[0] == "--check"
    if pruefen:
        argv = argv[1:]
    seite = Path(argv[0])
    quelle = seite.read_text(encoding="utf-8")
    ziel = None if pruefen else Path(argv[1])

    # Rumpf aus schema.json.html: erste und letzte Zeile sind die <script>-Tags.
    rohdatei = (REPO / "tools" / "schema.json.html").read_text(encoding="utf-8")
    daten = json.loads("\n".join(rohdatei.strip().splitlines()[1:-1]))

    # (.*?) statt ([^<]+): in .price steht seit dem MwSt.-Zusatz ein <span>,
    # an dem eine Zeichenklasse ohne '<' scheitern wuerde. Nicht gierig, damit
    # beim ersten </div> Schluss ist.
    preis = preis_zahl(text_of(r'<div class="price">(.*?)</div>', quelle, "Preis"))
    paket = text_of(r'<div class="pkg-l">.*?<h2>([^<]+)</h2>', quelle, "Paketname")
    # Erst die Liste eingrenzen, dann darin suchen. Ohne diesen Anker lief das
    # findall ueber die GANZE Seite -- gut gegangen ist das nur, weil sonst
    # kein <li> auf "</span>Text</li>" endet (die Nav-Punkte enden auf </a>).
    # Bekaeme irgendein anderes <li> ein <span> davor, waere sein Text
    # klanglos als weitere Leistung in den strukturierten Daten gelandet.
    liste = re.search(r'<ul class="pkg-list">(.*?)</ul>', quelle, re.S)
    if not liste:
        raise SystemExit('FEHLER: <ul class="pkg-list"> nicht in index.html gefunden')
    posten = [html.unescape(t).strip()
              for t in re.findall(r"</span>([^<]+)</li>", liste.group(1))]
    if not posten:
        raise SystemExit("FEHLER: keine Leistungsposten in .pkg-list gefunden")

    # Weiterhin kein valueAddedTaxIncluded -- aber aus einem anderen Grund als
    # frueher: die Seite weist seit dem 12.08.2026 "zzgl. MwSt." aus, das
    # Impressum nennt dagegen unveraendert die Kleinunternehmerregelung nach
    # § 19 UStG. Solange sich die beiden widersprechen, ist "false" eine
    # maschinenlesbare Steueraussage, die niemand gedeckt hat. Die 649 selbst
    # stimmen in beiden Faellen -- es ist der Betrag vor einer etwaigen
    # Steuer. Ist die Frage entschieden, gehoert hier "valueAddedTaxIncluded":
    # False hinein (und der § 19-Absatz im Impressum raus).
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

    block = ('<script type="application/ld+json">\n'
             + json.dumps(daten, ensure_ascii=False, indent=2)
             + "\n</script>\n")

    if pruefen:
        drin = re.search(r'<script type="application/ld\+json">.*?</script>',
                         quelle, re.S)
        if drin and drin.group(0).strip() == block.strip():
            print(f"  Schema in {seite.name} deckt sich mit der Seite "
                  f"({preis} EUR, {len(posten)} Leistungsposten)")
            return 0
        print(f"FEHLER: das JSON-LD in {seite.name} passt nicht mehr zu Preis, "
              f"Paketname oder Leistungsliste im Markup.")
        print(f"        Aus der Seite gelesen: {preis} EUR, {paket!r}, "
              f"{len(posten)} Posten.")
        print("        Neu bauen und den Block von Hand uebernehmen:")
        print(f"          py tools/build-schema.py {seite} neu.html")
        return 1

    ziel.write_text(block, encoding="utf-8")
    print(f"  Schema: Angebot {preis} EUR, {len(posten)} Leistungsposten "
          f"aus der Seite gelesen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
