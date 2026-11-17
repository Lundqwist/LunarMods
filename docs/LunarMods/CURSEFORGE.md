<p align="center"><img src="docs/LunarMods/logo.png" alt="LunarMods" width="160"></p>

# LunarMods

**Switch all of Lundqwist's mods on and off in one list, and run the ones you link from one minimap button.**

Made for **World of Warcraft: Forever**. Type `/lm` or click the round **LM** button on the minimap.

[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/lundqwist)

![The LunarMods window](docs/LunarMods/screenshots/window.png)

## The mods

Each mod is its own addon, in its own repository with its own download. They all work without LunarMods.

| Mod | What it does |
|---|---|
| **[FavoriteItems](https://github.com/Lundqwist/FavoriteItems)** | Mark items with a heart and get warned, with a buy-back button, when you sell one. `/fav` |
| **[Quest XP Tracker](https://github.com/Lundqwist/WoW_Forever_QuestXPTracker)** | See the XP of every quest in your log, how close it gets you to your next level, and where each quest is done. `/qxp` |

## Switch mods on and off

The `/lm` window lists every one of the mods you have installed:

- **Tick or untick** a mod to switch it on or off. The mods are separate addons, so this takes effect after **Reload UI**. The window tells you when a reload is needed.
- **Open** opens the mod (the same as `/fav` or `/qxp`).
- **Options** opens the mod's own options page, where you link it to LunarMods.
- Your choices are the same for all your characters.

## Link a mod: one minimap button for all of them

On its own, every mod has its own minimap button. Its options page (right-click its minimap button, click **Options** in `/lm`, or find it under the game's Options → AddOns) has a **Link to LunarMods** button:

- **Linked**: the mod's own minimap button goes away. The **LM** button's right-click menu opens it, and its tooltip shows what the mod has to tell you (Quest XP Tracker's XP summary, the number of favorites).
- **Not linked**: the mod keeps its own minimap button, and LunarMods only switches it on and off.
- **Unlink from LunarMods**, on the same page, gives the mod its own button back. Without LunarMods, every mod simply works with its own button.

![A mod's options page with the Link to LunarMods button](docs/LunarMods/screenshots/options.png)

![The LM button's tooltip with both mods linked](docs/LunarMods/screenshots/minimap.png)

The **LM** button:

- **Hover**: every mod and whether it's on, plus the summary of each linked mod
- **Left-click**: open or close the list of mods
- **Right-click**: a menu to open any linked mod, or the list
- **Drag**: move it around the minimap (square minimaps such as SexyMap's work too)

LunarMods is also in the game's addon button by the minimap.

## Commands

| Command | What it does |
|---|---|
| `/lm` or `/lunarmods` | Open the list |
| `/lm list` | Show the mods and their state in chat |
| `/lm on <mod>`, `/lm off <mod>` | Switch a mod on or off, for example `/lm off favoriteitems` |
| `/lm link <mod>`, `/lm unlink <mod>` | Link a mod to the LM button, or give it its own minimap button again |
| `/lm minimap` | Show or hide the LM button |
| `/lm <mod> ...` | A mod's own commands, for example `/lm questxptracker group` |
| `/lm help` | The commands |

## Install

Unpack the zip into `World of Warcraft\_forever_\Interface\AddOns`, next to the mods you want from the table above.
