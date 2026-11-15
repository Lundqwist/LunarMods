<p align="center"><img src="docs/LunarMods/logo.png" alt="LunarMods" width="160"></p>

# LunarMods

**All of Lundqwist's mods for World of Warcraft: Forever in one list. Tick the ones you want, untick the ones you don't.**

Type `/lm` or click the round **LM** button on the minimap. A window lists every mod with a tick box:

```
LunarMods v0.2.0
Tick the mods you want. Unticked mods are not loaded.

[x] FavoriteItems  Addon                          On
    Mark items as favorites with a heart...    [Open]
[x] Quest XP Tracker  Addon                       On
    Track the XP of every quest in your log... [Open]
                                           [Reload UI]
```

- **Tick or untick** a mod to switch it on or off.
- **Open** opens a mod's own window (the same as typing `/fav` or `/qxp`).
- FavoriteItems and Quest XP Tracker are normal addons that also work without LunarMods. Ticking or unticking one changes it in the game's own AddOn list, so it takes effect after **Reload UI**. The window tells you when a reload is needed.
- Your choices are the same for all your characters.

## What's included

| Mod | Kind | What it does |
|---|---|---|
| **FavoriteItems** | Addon | Mark items with a heart, get warned and buy them back when you sell one. `/fav` |
| **Quest XP Tracker** | Addon | The XP of every quest in your log, how close it gets you to the next level, quests grouped by where they're done. `/qxp` |

## One minimap button for all of them

The mods have no minimap buttons of their own: the round **LM** button is the way in to all of them.

```
LunarMods

FavoriteItems                               on

Quest XP Tracker                            on
Quest log                                37/40
Level 23                  12,345 / 40,000
Needed to level                     27,655
Active quests (11/12)            31,200 XP
Enough to level! 3,545 XP over.
```

- **Hover**: every mod and whether it's on, plus what a mod has to tell you (Quest XP Tracker's XP summary)
- **Left-click**: open or close the list of mods
- **Right-click**: a menu to open any mod (FavoriteItems, Quest XP Tracker) or the list
- **Drag**: move it around the minimap (works with square minimaps such as SexyMap's too)
- `/lm minimap`: hide or show it

LunarMods is also in the game's addon button by the minimap.

## Commands

| Command | What it does |
|---|---|
| `/lm` or `/lunarmods` | Open the list |
| `/lm list` | Show the mods and their state in chat |
| `/lm on <mod>`, `/lm off <mod>` | Switch a mod on or off, for example `/lm off favoriteitems` or `/lm on questxptracker` |
| `/lm minimap` | Show or hide the minimap button |
| `/lm <mod> ...` | A mod's own commands, for example `/lm questxptracker group` |
| `/lm help` | The commands |

## Install

Unpack the zip into `World of Warcraft\_forever_\Interface\AddOns`. It holds one folder per mod (`LunarMods`, `FavoriteItems`, `QuestXPTracker`). Delete the folders of mods you never want, or just untick them in `/lm`.

---

# The mods

Each description below is the one on the mod's CurseForge page.

## FavoriteItems

**Never sell your favorite things by accident again.**

Mark the items you care about with a little heart. If one of them ends up sold to a vendor anyway, FavoriteItems tells you right away and lets you buy it back with one click.

![With Baganator](https://raw.githubusercontent.com/Lundqwist/FavoriteItems/main/screenshots/baganator.png)

*With Baganator: hearts on favorite items, and the Favorites button in the bag window's bottom row.*

![Default bags](https://raw.githubusercontent.com/Lundqwist/FavoriteItems/main/screenshots/default-bags.png)

*With the default bags: the Favorites button under the combined backpack.*

### Features

- **Favorites button** on the lower side of your bags and bank.
- **Click to mark**: press the button, then click items to mark or unmark them. A heart appears in the icon's upper left corner. Press **Done** or close your bags when you're finished.
- **Specific items, not item types**: mark one copy of an item and the other copies stay unmarked.
- **Sold warning**: sell a favorite and a warning pops up with a **Buy back** button, plus a raid-warning message and sound. It catches every way of selling: right-click, dragging onto the vendor, and junk sellers.
- **Bought back = still a favorite**: buy it back before you leave the vendor and the heart comes back.
- **Tooltip line** showing "Favorite" on marked items.
- **Slash commands**: `/fav` starts or stops marking (and opens your bags), `/fav list` lists your favorites.

### Compatibility

- Made for **World of Warcraft: Forever**.
- Works with **Baganator**: the heart is a Baganator corner widget, so you can move it under Baganator's settings → Icons.
- Without Baganator it uses the default bags and bank.
- Favorites are shared by all characters on your account.

### Source

GitHub: https://github.com/Lundqwist/FavoriteItems

---

<p align="center"><img src="https://raw.githubusercontent.com/Lundqwist/WoW_Forever_QuestXPTracker/main/Media/logo.png" alt="Quest XP Tracker" width="180"></p>

## Quest XP Tracker

**Track the XP of every quest in your log, see how close it gets you to your next level, and group your quests by the zone where they are actually done.**

Made for **WoW Forever**. Type `/qxp`, use the **Qxp** plugin on Titan Panel, or open it from the **LM** minimap button of LunarMods.

![Quest XP Tracker in game](https://raw.githubusercontent.com/Lundqwist/WoW_Forever_QuestXPTracker/main/Media/IngameImage.png)

---

### How far do my quests take me?

The XP bar at the top shows the XP you have this level in **purple**. On top of it, in **green**, is where you'll be once you turn in every active quest. Underneath, the addon does the maths for you:

```
Level 23:  12,345 / 40,000 XP  (30%)
XP needed for level 24:  27,655  (level 23 needs 40,000 XP in total)
XP from active quests:  31,200  (78% of this level)
Enough to level up!  3,545 XP over into level 24
```

Not enough yet? It tells you exactly how much is missing:

```
Still short after turning them all in:  8,420 XP
```

![Main window](https://raw.githubusercontent.com/Lundqwist/WoW_Forever_QuestXPTracker/main/Media/MainWindow.png)

### Every quest, grouped by zone

Open the dropdown list to see every quest in your log, grouped under its zone. Each zone shows how many of its quests are active and how much XP they're worth together.

```
[-] Elwynn Forest  (3/4)                     1,240   [ Mixed  ]
       [7] Kobold Candles                       450   [ Active ]
       [8] Gold Dust Exchange                   420   [ Active ]
       [9] Princess Must Die!                   370   [ Active ]
       [10] The Fargodeep Mine                  290   [Inactive]
[+] Westfall  (5/5)                          4,860   [ Active ]
```

- **Quest names** are coloured by difficulty, the same way the game colours them.
- **Hover** a quest for its tooltip. **Click** it to open it in the quest log, **shift-click** to link it in chat.
- **Active / Inactive**: switch off quests you're not going to do (an elite quest, a dungeon you'll skip). They're greyed out and no longer count towards the total.
- The **zone button** switches a whole zone at once. **All active** and **None** switch every quest.
- **Click a zone** to fold it, **click a column header** to sort by name, XP or Active.

The title bar also shows how full your log is, from green to yellow to red:

```
Quests 37/40
```

### Where is the quest actually done?

The quest log files a quest under the zone where you picked it up. A quest from Orgrimmar that sends you to collect an item in the Barrens sits under *Orgrimmar*, even though you'll never set foot there for it.

The **By quest log / By target area** button in the title bar switches the grouping. Grouped **by target area**, every quest sits under the zone where its objectives are done:

```
[-] The Barrens  (4/4)  (you are here)       3,120   [ Active ]
       [14] Plainstrider Menace  (from Orgrimmar)     560   [ Active ]
       [15] Raptor Thieves                             610   [ Active ]
       [16] Lost in Battle  (done)  (from Orgrimmar)  700   [ Active ]
[+] Durotar  (2/2)                             980   [ Active ]
```

- **Unfinished quests** go under the zone with most of their objectives: the mobs to kill, the objects to use, the mobs and objects that drop the items you need, and the places to explore. Objectives you have finished no longer count, so a quest moves on when its last objective is somewhere else.
- **Finished quests** are marked **(done)** and go under the zone where you turn them in.
- The zone you are in is marked **(you are here)** and comes first.
- Grouped by quest log, a quest done somewhere else shows its target in grey: `> The Barrens`.
- **Hover** a quest to see both its quest log zone and its target area, plus any other zones where it has objectives.

The target areas come from **[Questie](https://www.curseforge.com/wow/addons/questie)**'s database (QuestieDB) when it is installed. Without it, the addon uses the game's own next waypoint for the quest when the game has one, and otherwise keeps the quest under its quest log zone.

### Look it up on Wowhead

**Right-click** any quest to get its Wowhead (Forever) link in a small box, already selected:

```
https://www.wowhead.com/forever/quest=783
```

Press **Ctrl+C** to copy it (the box closes by itself), then paste it into your browser. Addons can't open a web browser themselves, so this is the quickest way there.

### Titan Panel and the LM button

<img src="https://raw.githubusercontent.com/Lundqwist/WoW_Forever_QuestXPTracker/main/Media/logo.png" alt="Qxp icon" width="48" align="left">

Quest XP Tracker has no minimap button of its own. The **Qxp** Titan Panel plugin, and LunarMods' **LM** minimap button, show this summary when you hover them:

```
Quest XP Tracker
Quest log                      37/40
Level 23              12,345 / 40,000
Needed to level               27,655
Active quests (11/12)      31,200 XP
Enough to level! 3,545 XP over.
```

On Titan Panel the plugin's text shows the XP from active quests / the XP you need, for example **31,200 / 27,655 XP**. It turns green once your quests are enough to level.

On the Titan plugin:

- **Left-click**: show or hide the window
- **Right-click**: fold or unfold the quest list

Any other LibDataBroker display shows the plugin too. On the LM button, **right-click** and pick **Quest XP Tracker** to open the window.

### Make it your size

Drag the grip in the **bottom-right corner** to resize the window. The columns follow the width and the list follows the height. Size, position, grouping, folded zones and your Active/Inactive choices are saved for each character.

### Commands

| Command | What it does |
|---|---|
| `/qxp` or `/questxp` | Show or hide the window |
| `/qxp group` | Switch between grouping by quest log zone and by target area |
| `/qxp target`, `/qxp log` | Group by target area, or by quest log zone |
| `/qxp scan` | Rescan the quest log and work out the target areas again |
| `/qxp reset` | Move the window back to the centre and reset its size |

### Part of LunarMods

Quest XP Tracker works on its own. With **LunarMods** installed it shows up in LunarMods' list (`/lm`), where it can be switched on or off, and in the LM minimap button's tooltip and right-click menu.

### Good to know

- XP rewards are the values the game reports for your current level. Quests far below your level give less.
- Target areas are a best guess from where the mobs, objects and drops are found. A mob that lives in several zones counts for all of them, so a quest can show more than one area in its tooltip.
- The quest list pauses while you're in combat and catches up as soon as combat ends.
- At max level the bar shows your level and the total quest XP only.
- Version 1.5 removed the quest items window and the Qxp minimap button (LunarMods' LM button replaces it).

### Source and bugs

The addon is open source under the MIT license: [github.com/Lundqwist/WoW_Forever_QuestXPTracker](https://github.com/Lundqwist/WoW_Forever_QuestXPTracker). Bug reports and ideas are welcome under Issues. If you get an error, please include the text from BugSack or BugGrabber.

---

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
