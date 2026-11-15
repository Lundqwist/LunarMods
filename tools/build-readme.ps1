# build-readme.ps1 - writes README.md from the CurseForge descriptions in docs\.
#
#     .\tools\build-readme.ps1
#
# README.md = LunarMods' description, then the description of every mod in the
# order below (headings moved one level down), then the notes for developers.
# Edit the files in docs\, not README.md. package.ps1 runs this first.

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$utf8 = New-Object Text.UTF8Encoding $false

function Read-Doc([string]$path) {
    [IO.File]::ReadAllText((Join-Path $root $path), [Text.Encoding]::UTF8)
}

# "# Title" -> "## Title", "## Part" -> "### Part" (not inside ``` code blocks)
function Demote([string]$text) {
    $inCode = $false
    $lines = foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^```') { $inCode = -not $inCode }
        if (-not $inCode -and $line -match '^#{1,5} ') { "#" + $line } else { $line }
    }
    $lines -join "`n"
}

# Drops the HTML comment the FavoriteItems description starts with (notes for the upload)
function Strip-Comments([string]$text) {
    [regex]::Replace($text, '(?s)<!--.*?-->\s*', '')
}

$parts = @(
    (Read-Doc 'docs\LunarMods\CURSEFORGE.md').TrimEnd(),
    "---`n`n# The mods",
    "Each description below is the one on the mod's CurseForge page.",
    (Demote (Strip-Comments (Read-Doc 'docs\FavoriteItems\CURSEFORGE.md'))).TrimEnd(),
    "---",
    (Demote (Read-Doc 'docs\QuestXPTracker\CURSEFORGE.md')).TrimEnd(),
    "---",
    (Read-Doc 'docs\DEVELOPING.md').TrimEnd()
)

[IO.File]::WriteAllText((Join-Path $root 'README.md'), (($parts -join "`n`n") + "`n"), $utf8)
"Wrote README.md"
