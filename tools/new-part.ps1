# new-part.ps1 - start a new LunarMods part from the template.
#
#     .\tools\new-part.ps1 -Name SellJunk -Notes "Sells grey items when you open a vendor."
#
# Creates the folder LunarMods_SellJunk with a .toc file and SellJunk.lua.
# Run .\tools\install.ps1 afterwards so the game sees it, then /reload.

param(
    # One word, letters and digits only: it becomes the folder name LunarMods_<Name>
    [Parameter(Mandatory)] [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')] [string]$Name,
    # The name shown in the /lm list (default: the same as Name)
    [string]$Title = $Name,
    # One line about what the part does
    [string]$Notes = 'A LunarMods part.'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot
$template = Join-Path $root 'templates\LunarMods_Template'
$folder = Join-Path $root "LunarMods_$Name"

if (Test-Path $folder) { throw "LunarMods_$Name already exists." }
New-Item -ItemType Directory $folder | Out-Null

function Fill([string]$from, [string]$to) {
    $text = [IO.File]::ReadAllText((Join-Path $template $from))
    $text = $text.Replace('__NAME__', $Name).Replace('__TITLE__', $Title).Replace('__NOTES__', $Notes).Replace('__SHORT__', $Name.ToLower())
    # UTF-8 without a byte order mark, which is what the game reads
    [IO.File]::WriteAllText((Join-Path $folder $to), $text, (New-Object Text.UTF8Encoding $false))
}

Fill 'LunarMods_Template.toc' "LunarMods_$Name.toc"
Fill 'Template.lua' "$Name.lua"

Write-Host "Created LunarMods_$Name. Next: .\tools\install.ps1, then /reload in the game."
