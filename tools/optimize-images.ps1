# Bildoptimierung fuer officedogs.training.
#
# Der claude.ai/design-Export liefert die Bilder unoptimiert (Hero als 1,9-MB-PNG,
# Portrait als 3073x4097-JPG). Dieses Script erzeugt daraus die ausgelieferten
# Varianten. Wird von tools/_rederive.sh aufgerufen.
#
# Hinweis: kein ImageMagick/pngquant auf diesem Rechner -> System.Drawing.
# Umlaute in .ps1 bewusst vermieden (PowerShell 5.1 liest die Datei als CP1252).
param(
  [string]$Src = "C:\DATA\Claude\design-extract-v52\assets",
  [string]$Dst = "C:\DATA\Claude\officedogs.training\assets"
)
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
  Where-Object { $_.MimeType -eq 'image/jpeg' }

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
  $img = [System.Drawing.Image]::FromFile($srcPath)
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
  $img = [System.Drawing.Image]::FromFile($srcPath)
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
# Hero: full-bleed Hintergrund. Quelle ist nur 1536x1024, also nicht hochskalieren.
# Bewusst KEINE kleinere Mobil-Variante: der Hero ist "cover" auf einem hohen
# Viewport, dort limitiert die Hoehe — ein 375x812-Display braucht rechnerisch
# mehr Bildbreite als ein Desktop, nicht weniger.
Convert-Image "$Src\hero-office-dogs.png" "$Dst\hero-office-dogs.jpg" 1536 1024 82 0.5
# Portrait: runder Ausschnitt, Box max. 200 px bei background-size:150% —
# also 300 px bei 1x, 600 px bei 2x. 640 px deckt das mit Reserve ab.
Convert-Image "$Src\julia-portrait.jpg"   "$Dst\julia-portrait.jpg"   640  853  82 0.18
# og:image fuer Social-Previews (Facebook/LinkedIn/WhatsApp erwarten 1200x630).
Convert-Image "$Src\hero-office-dogs.png" "$Dst\og-office-dogs.jpg"   1200 630  84 0.5
# Favicon-Fallback fuer Browser ohne SVG-Support (Alpha bleibt).
Convert-Png   "$Src\logo-office-dogs.png" "$Dst\favicon-192.png"      192 ""
# iOS-Homescreen: deckende Flaeche in Paper-Ton, sonst komponiert iOS auf Schwarz.
Convert-Png   "$Src\logo-office-dogs.png" "$Dst\apple-touch-icon.png" 180 "#FCFAF6"
