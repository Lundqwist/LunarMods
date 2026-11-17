# sync-link.ps1 - copy shared\LunarLink.lua into every mod that uses it.
#
#     .\tools\sync-link.ps1
#
# LunarLink.lua gives a mod its own minimap button, its options page and the
# "Link to LunarMods" button. Each mod lives in its own repository next to
# this one (E:\ProjectsCoding\FavoriteItems, E:\ProjectsCoding\QuestXPTracker)
# and carries its own copy of the file. Edit shared\LunarLink.lua, run this,
# then commit the copy in each mod's repository.

param(
    [string[]]$Mods = @('FavoriteItems', 'QuestXPTracker')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$source = Join-Path $root 'shared\LunarLink.lua'
$projects = Split-Path $root

foreach ($mod in $Mods) {
    $folder = Join-Path $projects $mod
    if (-not (Test-Path (Join-Path $folder "$mod.toc"))) {
        Write-Warning "$mod not found at $folder"
        continue
    }
    Copy-Item $source (Join-Path $folder 'LunarLink.lua') -Force
    Write-Host "Copied   LunarLink.lua -> $folder"
}
