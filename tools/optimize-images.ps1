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

Write-Output "Bilder optimieren:"
# Hero: full-bleed Hintergrund. Quelle ist nur 1536x1024, also nicht hochskalieren.
Convert-Image "$Src\hero-office-dogs.png" "$Dst\hero-office-dogs.jpg" 1536 1024 82 0.5
# Portrait: wird nur in einer schmalen Spalte gezeigt (max ~520 px), 900 px reicht mit Reserve.
Convert-Image "$Src\julia-portrait.jpg"   "$Dst\julia-portrait.jpg"   900  1200 82 0.18
# og:image fuer Social-Previews (Facebook/LinkedIn/WhatsApp erwarten 1200x630).
Convert-Image "$Src\hero-office-dogs.png" "$Dst\og-office-dogs.jpg"   1200 630  84 0.5
