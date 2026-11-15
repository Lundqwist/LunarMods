# install.ps1 - make the game see LunarMods and every mod in this folder.
#
#     .\tools\install.ps1            link every addon folder into the game's AddOns folder
#     .\tools\install.ps1 -Remove    take the links away again
#
# It makes "junctions": the game's AddOns folder gets an entry that points at
# the folder here, so there is only one copy and an edit shows up in the game
# after /reload. Nothing is copied, and -Remove deletes only the links.
#
# A real folder with the same name in AddOns (an older copy installed by hand
# or from CurseForge) is moved to AddOns-backup-<date> next to AddOns, never
# deleted. Saved settings live in the WTF folder and are not touched.
# Old MoonFrame links (the name before LunarMods) are removed.

param(
    [string]$AddOns = 'D:\Blizzard\World of Warcraft\_forever_\Interface\AddOns',
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $AddOns)) { throw "AddOns folder not found: $AddOns (pass -AddOns <path>)" }

$root = Split-Path $PSScriptRoot
# every folder here with a .toc file of the same name is an addon
$folders = Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).toc") }

# links left over from the MoonFrame days
foreach ($old in Get-ChildItem $AddOns -Directory -Filter 'MoonFrame*') {
    if ($old.LinkType -eq 'Junction') {
        [IO.Directory]::Delete($old.FullName)
        Write-Host "Removed  $($old.Name) (old MoonFrame link)"
    }
}

# links whose folder here was deleted (a part you removed)
foreach ($link in Get-ChildItem $AddOns -Directory | Where-Object { $_.LinkType -eq 'Junction' }) {
    $target = @($link.Target)[0]
    if ($target -and $target.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -and -not (Test-Path $target)) {
        [IO.Directory]::Delete($link.FullName)
        Write-Host "Removed  $($link.Name) (its folder is gone)"
    }
}

$backup = Join-Path (Split-Path $AddOns) ("AddOns-backup-" + (Get-Date -Format 'yyyy-MM-dd'))

foreach ($folder in $folders) {
    $link = Join-Path $AddOns $folder.Name
    $existing = Get-Item $link -ErrorAction SilentlyContinue

    if ($existing -and $existing.LinkType -ne 'Junction') {
        if ($Remove) {
            Write-Warning "$($folder.Name): a real folder, not a link. Left alone."
            continue
        }
        New-Item -ItemType Directory -Force $backup | Out-Null
        $target = Join-Path $backup $folder.Name
        if (Test-Path $target) { $target += "-" + (Get-Date -Format 'HHmmss') }
        Move-Item $existing.FullName $target
        Write-Host "Moved    $($folder.Name) (old copy) to $target"
        $existing = $null
    }
    if ($existing) {
        # Deletes the link only, never what it points at
        [IO.Directory]::Delete($link)
    }
    if ($Remove) {
        if ($existing) { Write-Host "Removed  $($folder.Name)" }
        continue
    }
    New-Item -ItemType Junction -Path $link -Target $folder.FullName | Out-Null
    Write-Host "Linked   $($folder.Name)"
}
