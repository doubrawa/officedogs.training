<#
    build-onepager.ps1 - erzeugt aus tools/onepager/onepager.html das PDF
    assets/office-dogs-onepager.pdf.

    Aufruf aus dem Repo-Wurzelverzeichnis:
        powershell -ExecutionPolicy Bypass -File tools\build-onepager.ps1

    Diese Datei ist absichtlich rein ASCII (keine Umlaute, keine
    Gedankenstriche). PowerShell 5.1 liest .ps1 ohne BOM als CP1252; ein
    einzelnes UTF-8-Zeichen zerlegt sonst das Parsing der Zeichenketten.

    Warum headless Chrome und nicht ein PDF-Werkzeug: die Quelle IST die
    Website-Technik - dieselben woff2-Dateien, dieselben oklch-Farbwerte,
    dieselben Bilder aus assets/. Chrome rendert das identisch zur Site und
    bettet die Schriften als Subset ein.

    Das Blatt ist seit dem 11.08.2026 NICHT mehr A4: Breite wie A4 (210 mm),
    Hoehe am Inhalt gemessen und in Punkt gesetzt, damit unten kein weisser
    Streifen bleibt (siehe die Pruefung weiter unten).

    Der konkrete Wert steht hier bewusst NICHT - dieses Skript liest ihn aus der
    @page-Regel von onepager.html und schreibt ihn nirgends selbst fest. Eine
    Zahl im Kommentarkopf waere eine zweite Wahrheit, die niemand mitpflegt:
    genau das war am 13.08.2026 der Fall, als hier "1212 pt" stand und die
    Quelle laengst auf 1194 lief.

    Zwei Fallen, die hier abgefangen sind:

    1. Das alte `--headless` liefert stillschweigend KEIN PDF, wenn ein
       Chrome-Fenster offen ist und das Standardprofil gesperrt ist. Deshalb
       `--headless=new` mit eigenem --user-data-dir.
    2. Laeuft der Inhalt ueber die in @page gesetzte Hoehe, entsteht klanglos
       eine zweite Seite. Das Skript prueft die Seitenzahl und bricht dann ab,
       statt ein kaputtes PDF zurueckzulassen. Das ist die eigentliche
       Schutzplanke des Blattes.

    Was hier NICHT auffaellt: eine Hoehe in `html,body`, die kleiner ist als
    die in `@page`. Nachgemessen am 11.08.2026 - 297 gegen 368 mm - laeuft der
    Build glatt durch und liefert ein einseitiges 368-mm-PDF (damals war das
    Blatt 368 mm hoch). Das Papierformat
    haengt allein an `@page`; `html,body` bestimmt nur, ob `.foot` seinen
    `margin-top:auto` gegen einen Unterrand druecken kann. Zu klein gesetzt
    faellt das Fussband einfach dort hin, wo der Text endet. Der
    MediaBox-Vergleich unten faengt deshalb bloss grobe Schnitzer in der
    @page-Regel selbst ab, nicht das Auseinanderlaufen der beiden Stellen.

    Hintergrundflaechen: `--print-to-pdf` druckt sie mit (anders als der
    interaktive Druckdialog, wo das Haekchen standardmaessig aus ist). Der
    Slate-Balken und die Karten haengen daran - geprueft, funktioniert.
#>
[CmdletBinding()]
param(
    # Zielpfad des PDFs. Relative Pfade gelten ab dem Repo-Wurzelverzeichnis.
    [string]$Out = "assets\office-dogs-onepager.pdf",
    # Zusaetzlich eine PNG-Vorschau ablegen (nur zum Draufschauen, wird nicht
    # committet). Braucht Python mit pypdfium2.
    [switch]$Preview
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $repo 'tools\onepager\onepager.html'
if ([System.IO.Path]::IsPathRooted($Out)) { $dst = $Out } else { $dst = Join-Path $repo $Out }

if (-not (Test-Path $src)) { throw "Quelle fehlt: $src" }

# ---- Browser suchen ----------------------------------------------------
$candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)
$browser = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $browser) { throw "Weder Chrome noch Edge gefunden." }
Write-Host "Browser : $browser"

# Eigenes Profil, damit ein offenes Chrome-Fenster nicht dazwischenkommt.
$profileDir = Join-Path $env:TEMP "officedogs-onepager-profile"
New-Item -ItemType Directory -Force $profileDir | Out-Null

$uri = "file:///" + ($src -replace '\\','/')
$tmp = Join-Path $env:TEMP "officedogs-onepager.pdf"
if (Test-Path $tmp) { Remove-Item $tmp -Force }

& $browser --headless=new --disable-gpu --no-first-run --no-default-browser-check `
           --user-data-dir="$profileDir" --no-pdf-header-footer `
           --print-to-pdf="$tmp" $uri | Out-Null

if (-not (Test-Path $tmp)) { throw "Chrome hat kein PDF geschrieben." }

# ---- Seitenzahl, Format, Schriften und Links aus dem PDF lesen ---------
$raw   = [System.Text.Encoding]::GetEncoding(28591).GetString([System.IO.File]::ReadAllBytes($tmp))
$pages = ([regex]::Matches($raw, '/Type\s*/Page[^s]')).Count
$fonts = ([regex]::Matches($raw, '/FontFile[23]')).Count
$links = ([regex]::Matches($raw, '/Subtype\s*/Link')).Count
$boxM  = [regex]::Match($raw, '/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)')
# Wie bei $soll unten geprueft, bevor zugegriffen wird: greift das Muster
# nicht (andere Schreibweise der Nullen, MediaBox nur im Seitenbaum vererbt),
# starb die Umrechnung sonst an einem leeren String, statt zu sagen was los
# ist -- und liess das temporaere PDF in %TEMP% liegen.
if (-not $boxM.Success) {
    Remove-Item $tmp -Force
    throw "Keine MediaBox im PDF gefunden. Chrome hat vermutlich kein vollstaendiges PDF geschrieben."
}
$box   = $boxM.Groups

# Die @page-Regel aus der Quelle lesen. Breite steht dort in mm, die Hoehe in pt
# (warum, steht im Kommentarkopf von onepager.html) - deshalb beide Einheiten.
$soll = [regex]::Match((Get-Content $src -Raw), '@page\s*\{\s*size:\s*([\d.]+)(mm|pt|px)\s+([\d.]+)(mm|pt|px)')
$inMm = { param($wert, $einheit)
    switch ($einheit) { 'mm' { $wert } 'pt' { $wert * 25.4 / 72 } 'px' { $wert * 25.4 / 96 } } }

if ($pages -ne 1) {
    Remove-Item $tmp -Force
    $hint = if ($soll.Success) { "ueber die $($soll.Groups[3].Value)$($soll.Groups[4].Value) aus der @page-Regel" } else { "ueber die Blatthoehe" }
    throw "PDF hat $pages Seiten statt 1. Der Inhalt laeuft $hint hinaus - entweder onepager.html kuerzen oder dort die Blatthoehe (@page UND html,body) anheben."
}
# Die Familien nachweisen, nicht die Schriftstroeme zaehlen. Das Blatt setzt DM
# Sans in vier Schnitten: schon zwei davon brachten die alte Pruefung
# ($fonts -lt 2) ueber die Huerde, waehrend Playfair fehlte und das Zitat in
# einer Ersatzserife stand. Chrome benennt die Subsets "AAAAAA+DMSans9pt-..."
# und "EAAAAA+PlayfairDisplay-Italic", der Praefix ist je Subset verschieden.
$fehlend = @('DMSans','PlayfairDisplay') | Where-Object { $raw -notmatch "/BaseFont\s*/[A-Z]{6}\+$_" }
if ($fehlend) {
    throw "Nicht eingebettet: $($fehlend -join ', '). DM Sans und Playfair Display muessen beide drin sein ($fonts Schriftstroeme gefunden)."
}

$mmW = [math]::Round([double]$box[1].Value * 25.4 / 72, 1)
$mmH = [math]::Round([double]$box[2].Value * 25.4 / 72, 1)

# Gegenprobe: was Chrome gedruckt hat, gegen das, was onepager.html bestellt.
if ($soll.Success) {
    $sollW = & $inMm ([double]$soll.Groups[1].Value) $soll.Groups[2].Value
    $sollH = & $inMm ([double]$soll.Groups[3].Value) $soll.Groups[4].Value
    if ([math]::Abs($mmW - $sollW) -gt 1 -or [math]::Abs($mmH - $sollH) -gt 1) {
        throw "PDF ist $mmW x $mmH mm, onepager.html bestellt $([math]::Round($sollW,1)) x $([math]::Round($sollH,1)) mm. Stimmen @page und html,body ueberein?"
    }
}

# Der weisse Strich am Blattfuss. Chrome quantisiert die Papierhoehe auf 0,24 pt;
# bleibt danach ein Bruchteil einer CSS-Zeile uebrig, malt nichts mehr hinein und
# manche Betrachter zeichnen daraus unten eine weisse Linie. Sauber ist es nur,
# wenn die Hoehe der MediaBox glatt in CSS-Pixel aufgeht - also ein Vielfaches
# von 6 pt ist. Am 11.08.2026 mit 359 mm nachgestellt: 0,44 px Rest, Linie da;
# mit 1020 pt: 0,00 px, Linie weg.
$ptH  = [double]$box[2].Value
$rest = $ptH * 4 / 3 - [math]::Floor($ptH * 4 / 3)
if ($rest -gt 0.001) {
    throw ("Blatthoehe {0} pt geht nicht glatt in CSS-Pixel auf ({1:N2} px Rest) - unten bleibt ein weisser Streifen. " -f $ptH, $rest) +
          "In onepager.html @page UND html,body auf ein Vielfaches von 6 pt setzen, z. B. $([math]::Ceiling($ptH / 6) * 6)pt."
}

$dstDir = Split-Path -Parent $dst
if ($dstDir) { New-Item -ItemType Directory -Force $dstDir | Out-Null }

# Erst loeschen, dann verschieben. `Move-Item -Force` allein reicht nicht: unter
# PowerShell 5.1 scheitert es mit "Eine Datei kann nicht erstellt werden, wenn
# sie bereits vorhanden ist", sobald das Ziel existiert und von irgendetwas
# offen gehalten wird - etwa einem PDF-Betrachter, der die letzte Fassung
# gerade anzeigt. Das Tueckische daran: das Skript lief vorher trotzdem weiter
# und man rasterte anschliessend die ALTE Datei, ohne es zu merken. Deshalb
# unten zusaetzlich die Gegenprobe auf die Dateigroesse.
$sollGroesse = (Get-Item $tmp).Length
if (Test-Path $dst) {
    try { Remove-Item $dst -Force -ErrorAction Stop }
    catch { throw "Ziel laesst sich nicht ersetzen ($dst). Ist die Datei in einem PDF-Betrachter offen? Dort schliessen und erneut bauen." }
}
Move-Item $tmp $dst
if ((Get-Item $dst).Length -ne $sollGroesse) {
    throw "Das geschriebene PDF hat nicht die erwartete Groesse - Ziel vermutlich veraltet."
}

Write-Host "Seiten  : $pages"
Write-Host "Format  : $mmW x $mmH mm"
Write-Host "Schrift : $fonts eingebettete Subsets"
Write-Host "Links   : $links klickbar"
Write-Host "Groesse : $([math]::Round((Get-Item $dst).Length/1kb)) kB"
Write-Host "Ziel    : $dst"

if ($Preview) {
    $png = [System.IO.Path]::ChangeExtension($dst, '.png')
    $py  = Join-Path $PSScriptRoot 'onepager\rasterize.py'
    if (Test-Path $py) {
        & py $py $dst $png 1.6
    } else {
        Write-Warning "rasterize.py fehlt, keine Vorschau erzeugt."
    }
}
