# package.ps1 - build the zip with every mod, ready to unpack into the AddOns folder.
#
#     .\tools\package.ps1
#
# Writes dist\LunarMods-<version>.zip (the version comes from LunarMods\LunarMods.toc).
# The zip holds one folder per addon (LunarMods, FavoriteItems, QuestXPTracker, and
# any LunarMods_* parts); README.md and LICENSE go inside LunarMods\.
# Unpack it into World of Warcraft\_forever_\Interface\AddOns.

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$dist = Join-Path $root 'dist'

& (Join-Path $PSScriptRoot 'build-readme.ps1')

$toc = Get-Content (Join-Path $root 'LunarMods\LunarMods.toc')
$version = $toc | Where-Object { $_ -match '^## Version:\s*(.+)$' } | ForEach-Object { $Matches[1].Trim() } | Select-Object -First 1
if (-not $version) { throw "No '## Version:' line in LunarMods\LunarMods.toc" }

# every folder here with a .toc file of the same name is an addon
$addons = Get-ChildItem $root -Directory | Where-Object { Test-Path (Join-Path $_.FullName "$($_.Name).toc") }

New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist "LunarMods-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

# Build the zip by hand so entry names use forward slashes (Compress-Archive on
# Windows PowerShell writes backslashes, which other unzip tools mis-read).
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    function Add([string]$file, [string]$entry) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    foreach ($addon in $addons) {
        foreach ($file in Get-ChildItem $addon.FullName -Recurse -File) {
            $rel = $file.FullName.Substring($addon.FullName.Length + 1) -replace '\\', '/'
            Add $file.FullName "$($addon.Name)/$rel"
        }
    }
    Add (Join-Path $root 'README.md') 'LunarMods/README.md'
    Add (Join-Path $root 'LICENSE') 'LunarMods/LICENSE'
} finally {
    $zip.Dispose()
}

"Built $zipPath"
$check = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try { $check.Entries | ForEach-Object { "  $($_.FullName)  ($($_.Length) bytes)" } } finally { $check.Dispose() }
