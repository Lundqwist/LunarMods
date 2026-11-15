# Draws the "LM" badge: the LunarMods icon and minimap button.
# Usage: .\tools\make-icon.ps1 -Size 64  -Tga LunarMods\Media\LMIcon.tga
#        .\tools\make-icon.ps1 -Size 256 -Png docs\LunarMods\logo.png
param(
    [int]$Size = 64,
    [string]$Png,
    [string]$Tga
)
Add-Type -AssemblyName System.Drawing
# .NET resolves relative paths against the process folder, not PowerShell's
if ($Png) { $Png = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Png) }
if ($Tga) { $Tga = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Tga) }

$s = $Size / 64.0   # the design is laid out on a 64x64 grid
function Argb([int]$a, [int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
function Rect([double]$x, [double]$y, [double]$w, [double]$h) { New-Object System.Drawing.RectangleF ([float]($x*$s)), ([float]($y*$s)), ([float]($w*$s)), ([float]($h*$s)) }

$bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.InterpolationMode = 'HighQualityBicubic'
$g.Clear([System.Drawing.Color]::Transparent)

# night-blue disc, the colours of the LunarMods window
$disc = Rect 2 2 60 60
$bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $disc, (Argb 255 30 48 92), (Argb 255 6 10 26), 90
$g.FillEllipse($bg, $disc)

# a pale crescent moon behind the letters, top right
$moonPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$moonPath.AddEllipse((Rect 28 6 30 30))
$cut = New-Object System.Drawing.Drawing2D.GraphicsPath
$cut.AddEllipse((Rect 22 2 30 30))
$moon = New-Object System.Drawing.Region $moonPath
$moon.Exclude($cut)
$g.FillRegion((New-Object System.Drawing.SolidBrush (Argb 110 200 215 255)), $moon)

# a soft top highlight
$shine = New-Object System.Drawing.Drawing2D.LinearGradientBrush (Rect 8 4 48 26), (Argb 50 255 255 255), (Argb 0 255 255 255), 90
$g.FillEllipse($shine, (Rect 9 5 46 24))

# rings: gold outer, thin silver inner
$ring = New-Object System.Drawing.Pen (Argb 255 201 163 107), ([float](3*$s))
$g.DrawEllipse($ring, (Rect 3 3 58 58))
$inner = New-Object System.Drawing.Pen (Argb 140 200 215 255), ([float](0.8*$s))
$g.DrawEllipse($inner, (Rect 6 6 52 52))

# the letters "LM", centred
$fam = New-Object System.Drawing.FontFamily "Georgia"
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'
$fmt.LineAlignment = 'Center'
$bold = [int][System.Drawing.FontStyle]::Bold
$text = New-Object System.Drawing.Drawing2D.GraphicsPath
$text.AddString("LM", $fam, $bold, [float](22*$s), (Rect 0 8 64 60), $fmt)

$outline = New-Object System.Drawing.Pen (Argb 255 0 0 0), ([float](4.5*$s))
$outline.LineJoin = 'Round'
$g.DrawPath($outline, $text)
$gold = New-Object System.Drawing.Drawing2D.LinearGradientBrush (Rect 0 16 64 34), (Argb 255 255 244 190), (Argb 255 214 150 40), 90
$g.FillPath($gold, $text)
$g.Dispose()

if ($Png) {
    $bmp.Save($Png, [System.Drawing.Imaging.ImageFormat]::Png)
    "wrote $Png"
}

if ($Tga) {
    # uncompressed 32-bit TGA, bottom-left origin (what WoW loads)
    $header = New-Object byte[] 18
    $header[2]  = 2
    $header[12] = $Size -band 0xFF; $header[13] = $Size -shr 8
    $header[14] = $Size -band 0xFF; $header[15] = $Size -shr 8
    $header[16] = 32
    $header[17] = 8
    $data = New-Object byte[] ($Size * $Size * 4)
    $i = 0
    for ($y = $Size - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $Size; $x++) {
            $c = $bmp.GetPixel($x, $y)
            $data[$i] = $c.B; $data[$i+1] = $c.G; $data[$i+2] = $c.R; $data[$i+3] = $c.A
            $i += 4
        }
    }
    $bytes = New-Object byte[] (18 + $data.Length)
    [Array]::Copy($header, 0, $bytes, 0, 18)
    [Array]::Copy($data, 0, $bytes, 18, $data.Length)
    [System.IO.File]::WriteAllBytes($Tga, $bytes)
    "wrote $Tga"
}
$bmp.Dispose()
