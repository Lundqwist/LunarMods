# install.ps1 - make the game see this mod.
#
#     .\install.ps1            link this folder into the game's AddOns folder
#     .\install.ps1 -Remove    take the link away again
#
# It makes a "junction": the game's AddOns folder gets an entry that points at
# this folder, so there is only one copy and an edit shows up in the game after
# /reload. A real folder with the same name in AddOns (an older copy) is moved
# to AddOns-backup-<date> next to AddOns, never deleted. Saved settings live in
# the WTF folder and are not touched.
# (The original of this script is shared\install-mod.ps1 in the LunarMods repository.)

param(
    [string]$AddOns = 'D:\Blizzard\World of Warcraft\_forever_\Interface\AddOns',
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $AddOns)) { throw "AddOns folder not found: $AddOns (pass -AddOns <path>)" }

$folder = $PSScriptRoot
$name = (Get-ChildItem $folder -Filter *.toc | Select-Object -First 1).BaseName
if (-not $name) { throw "No .toc file in $folder" }
$link = Join-Path $AddOns $name
$existing = Get-Item $link -ErrorAction SilentlyContinue

if ($existing -and $existing.LinkType -ne 'Junction') {
    if ($Remove) { Write-Warning "$name is a real folder, not a link. Left alone."; return }
    $backup = Join-Path (Split-Path $AddOns) ("AddOns-backup-" + (Get-Date -Format 'yyyy-MM-dd'))
    New-Item -ItemType Directory -Force $backup | Out-Null
    $target = Join-Path $backup $name
    if (Test-Path $target) { $target += "-" + (Get-Date -Format 'HHmmss') }
    Move-Item $existing.FullName $target
    Write-Host "Moved    $name (old copy) to $target"
    $existing = $null
}
if ($existing) {
    # deletes the link only, never what it points at
    [IO.Directory]::Delete($link)
}
if ($Remove) {
    if ($existing) { Write-Host "Removed  $name" }
    return
}
New-Item -ItemType Junction -Path $link -Target $folder | Out-Null
Write-Host "Linked   $name -> $folder. Type /reload in the game."
