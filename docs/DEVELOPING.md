# For developers

## Folder layout

```
LunarMods\                    this folder
├── LunarMods\                the core: the list, the minimap button, loading parts
├── FavoriteItems\            an addon (works without LunarMods too)
├── QuestXPTracker\           an addon (works without LunarMods too)
├── docs\                     CurseForge descriptions, logos and screenshots; README.md is built from them
├── templates\                the template for new parts
└── tools\                    install, package, new part, icons
```

## How LunarMods finds mods

A **part** is an addon folder with three extra lines in its `.toc` file:

```
## Dependencies: LunarMods
## LoadOnDemand: 1
## X-LunarMods-Part: 1
```

`LoadOnDemand` tells the game not to load the part by itself. At login LunarMods loads the parts that are ticked in its list; ticking one later loads it right away. Unticking stops it; it leaves memory at the next `/reload`.

An **addon** is listed when its `.toc` file has `## X-LunarMods: 1` or `## Author: Lundqwist`. `## X-LunarMods-Open: /qxp` adds an Open button that runs that command, and an entry in the LM button's right-click menu. `## X-LunarMods-Tooltip: QuestXPTracker_LunarModsTooltip` names a global function LunarMods calls with `GameTooltip` to add the mod's own lines to the LM button's tooltip. The mods have no minimap buttons of their own. Addons are switched on or off through the game's own AddOn list (for all characters), so a change takes effect at the next reload.

## Make a new part

```powershell
.\tools\new-part.ps1 -Name SellJunk -Notes "Sells grey items when you open a vendor."
.\tools\install.ps1
```

That creates `LunarMods_SellJunk` from the template and links it into the game. Type `/reload` and it is in the `/lm` list. Then write the part in `LunarMods_SellJunk\SellJunk.lua`:

```lua
local part = LunarMods:NewPart(...)      -- "..." holds the folder name

function part:OnEnable()                 -- switched on: at login or when ticked
    self:RegisterEvent("MERCHANT_SHOW")
end

function part:MERCHANT_SHOW()            -- an event calls the method with its name
    self:Print("a vendor!")
end

function part:OnDisable() end            -- optional: hide frames, stop timers
function part:OnSlash(message) end       -- optional: /lm selljunk <message>
```

What a part gets from LunarMods:

| | |
|---|---|
| `part:OnEnable()`, `part:OnDisable()` | Called when the part is switched on or off |
| `part:RegisterEvent(event [, handler])` | Listen to a game event. Removed automatically when the part is switched off |
| `part:UnregisterEvent(event)` | Stop listening |
| `part:OnSlash(message)` | Receives `/lm <part> message` |
| `part:Print(...)` | A chat line with the part's name in front |
| `part.db` | A table saved between sessions, shared by all characters |
| `part.chardb` | The same, for this character only |
| `part:IsEnabled()` | Whether the part is switched on |

An error in one part is reported in the normal way and does not stop the other parts.

## Tools

```powershell
.\tools\install.ps1            # link every mod folder into the game (an older real copy is moved to AddOns-backup-<date>)
.\tools\install.ps1 -Remove    # take the links away again
.\tools\package.ps1            # build README.md and dist\LunarMods-<version>.zip
.\tools\build-readme.ps1       # only rebuild README.md from docs\
.\tools\make-icon.ps1 -Size 64 -Tga LunarMods\Media\LMIcon.tga    # the LM icon
.\tools\make-qxp-logo.ps1 -Size 64 -Tga QuestXPTracker\Media\QxpIcon.tga
```

The game's folder is `World of Warcraft\_forever_\Interface\AddOns`; pass `-AddOns <path>` to `install.ps1` if yours is somewhere else.

## License

[MIT](LICENSE) © 2026 Bjarne Lundqwist
