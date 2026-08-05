# Bildoptimierung fuer officedogs.training.
#
# Erzeugt die ausgelieferten Bildvarianten aus zwei Quellen:
#   $Src   = claude.ai/design-Export, liefert unoptimiert (2400x1602 u.ae.)
#   $Local = tools\assets-src, Originale die es im Design gar nicht gibt
# Wird von tools/_rederive.sh aufgerufen.
#
# Hinweis: kein ImageMagick/pngquant auf diesem Rechner -> System.Drawing.
# Umlaute in .ps1 bewusst vermieden (PowerShell 5.1 liest die Datei als CP1252).
param(
  [string]$Src   = "C:\DATA\Claude\design-extract-v53\assets",
  [string]$Local = "C:\DATA\Claude\officedogs.training\tools\assets-src",
  [string]$Dst   = "C:\DATA\Claude\officedogs.training\assets"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq 'image/jpeg' }

# System.Drawing kennt kein WebP. Schlaegt der GDI-Loader fehl, wird ueber WIC
# dekodiert (Windows bringt seit 10/11 einen WebP-Codec mit) und das Ergebnis
# in eine eigenstaendige Bitmap kopiert -- FromStream wuerde sonst am Stream
# haengen, den wir gleich danach schliessen.
function Open-Image($path) {
  try { return [System.Drawing.Image]::FromFile($path) } catch { }
  $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
           (New-Object System.Uri($path)), 'None', 'OnLoad')
  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add($dec.Frames[0])
  $ms = New-Object System.IO.MemoryStream
  $enc.Save($ms); $ms.Position = 0
  $tmp = [System.Drawing.Image]::FromStream($ms)
  $out = New-Object System.Drawing.Bitmap($tmp)
  $tmp.Dispose(); $ms.Dispose()
  return $out
}

function Save-Jpeg($bmp, $path, $quality) {
  $ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
  $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [int64]$quality)
  $bmp.Save($path, $jpegCodec, $ep)
  $ep.Dispose()
}

# Zeichnet $img skaliert/beschnitten in eine Zielflaeche $w x $h (cover-Verhalten,
# $anchorY 0..1 bestimmt den vertikalen Bildausschnitt) und speichert als JPEG.
function Convert-Image($srcPath, $dstPath, $w, $h, $quality, $anchorY) {
  $img = Open-Image $srcPath
  try {
    if (-not $h) { $h = [int][math]::Round($w * $img.Height / $img.Width) }
    $scale  = [math]::Max($w / $img.Width, $h / $img.Height)
    $sw     = [int][math]::Round($img.Width  * $scale)
    $sh     = [int][math]::Round($img.Height * $scale)
    $offX   = [int][math]::Round(($w - $sw) / 2)
    $offY   = [int][math]::Round(($h - $sh) * $anchorY)

    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingQuality = 'HighQuality'
    $g.InterpolationMode  = 'HighQualityBicubic'
    $g.SmoothingMode      = 'HighQuality'
    $g.PixelOffsetMode    = 'HighQuality'
    # Weiss unterlegen, damit PNG-Transparenz nicht schwarz wird
    $g.Clear([System.Drawing.Color]::White)
    $g.DrawImage($img, $offX, $offY, $sw, $sh)
    $g.Dispose()
    Save-Jpeg $bmp $dstPath $quality
    $bmp.Dispose()
    $kb = [math]::Round((Get-Item $dstPath).Length / 1KB, 1)
    Write-Output ("  {0,-26} {1}x{2}  {3} KB" -f (Split-Path $dstPath -Leaf), $w, $h, $kb)
  } finally { $img.Dispose() }
}

# Wie Convert-Image, aber PNG. $bgHex leer -> Transparenz bleibt erhalten
# (fuer das Browser-Favicon), sonst wird die Flaeche unterlegt (fuer das
# apple-touch-icon: iOS komponiert Alpha auf Schwarz, das saehe haesslich aus).
function Convert-Png($srcPath, $dstPath, $size, $bgHex) {
  $img = Open-Image $srcPath
  try {
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingQuality = 'HighQuality'
    $g.InterpolationMode  = 'HighQualityBicubic'
    $g.SmoothingMode      = 'HighQuality'
    $g.PixelOffsetMode    = 'HighQuality'
    if ($bgHex) { $g.Clear([System.Drawing.ColorTranslator]::FromHtml($bgHex)) }
    $g.DrawImage($img, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($dstPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    $kb = [math]::Round((Get-Item $dstPath).Length / 1KB, 1)
    Write-Output ("  {0,-26} {1}x{1}  {2} KB" -f (Split-Path $dstPath -Leaf), $size, $kb)
  } finally { $img.Dispose() }
}

Write-Output "Bilder optimieren:"
# Hero: full-bleed Hintergrund. Die Quelle liegt NICHT im Design-Export, sondern
# als Original in tools\assets-src -- das Bild kam direkt vom Auftraggeber. Mit
# 1200x801 ist sie klein fuer einen Vollbild-Hero; nicht hochskalieren, das
# erfindet keine Details und kostet nur Bytes.
# Bewusst KEINE kleinere Mobil-Variante: der Hero ist "cover" auf einem hohen
# Viewport, dort limitiert die Hoehe -- ein 375x812-Display braucht rechnerisch
# mehr Bildbreite als ein Desktop, nicht weniger.
Convert-Image "$Local\hero-office-dogs.webp" "$Dst\hero-office-dogs.jpg" 1200 800 82 0.5
# og:image fuer Social-Previews (Facebook/LinkedIn/WhatsApp erwarten 1200x630).
# anchorY 0.35: 170 px muessen weg, oben bleiben die Gesichter, unten der Hund.
Convert-Image "$Local\hero-office-dogs.webp" "$Dst\og-office-dogs.jpg"   1200 630  84 0.35
# Bildpanel im "Warum Office Dogs"-Block, zwei Breiten fuer srcset. Angezeigt
# wird es mit rund 570 CSS-px (halbe Karte): 620 px reichen fuer normale
# Displays, 1240 px sind die 2x-Fassung. Zielverhaeltnis 1.498 entspricht der
# Quelle (2400x1602), es wird also praktisch nichts beschnitten -- den
# Ausschnitt macht spaeter object-fit im Browser, je nach Texthoehe.
Convert-Image "$Src\hero-alltagstipps.jpg" "$Dst\julia-mit-hund-1240.jpg" 1240 828  82 0.5
Convert-Image "$Src\hero-alltagstipps.jpg" "$Dst\julia-mit-hund-620.jpg"   620 414  82 0.5
# Favicon-Fallback fuer Browser ohne SVG-Support (Alpha bleibt).
Convert-Png   "$Src\logo-office-dogs.png" "$Dst\favicon-192.png"      192 ""
# iOS-Homescreen: deckende Flaeche in Paper-Ton, sonst komponiert iOS auf Schwarz.
Convert-Png   "$Src\logo-office-dogs.png" "$Dst\apple-touch-icon.png" 180 "#FCFAF6"
