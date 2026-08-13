"""PDF-Seiten als PNG rastern — nur zur Sichtkontrolle des One-Pagers.

    py tools/onepager/rasterize.py assets/office-dogs-onepager.pdf vorschau.png 1.6

Braucht `pypdfium2` (pip install pypdfium2). Gehoert nicht zum Build, das PDF
entsteht ohne Python; das hier ist ausschliesslich das Auge.
"""
import sys

import pypdfium2 as pdfium

src, dst = sys.argv[1], sys.argv[2]
scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1.5

pdf = pdfium.PdfDocument(src)
print(f"Seiten: {len(pdf)}")
for i, page in enumerate(pdf):
    w, h = page.get_size()
    print(f"  Seite {i + 1}: {w:.2f} x {h:.2f} pt  =  {w * 25.4 / 72:.1f} x {h * 25.4 / 72:.1f} mm")
    img = page.render(scale=scale).to_pil()
    out = dst if len(pdf) == 1 else dst.replace(".png", f"-{i + 1}.png")
    img.save(out)
    print(f"  -> {out}  ({img.width}x{img.height})")
