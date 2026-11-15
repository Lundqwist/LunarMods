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
