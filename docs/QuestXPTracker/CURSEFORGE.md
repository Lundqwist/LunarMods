<p align="center"><img src="https://raw.githubusercontent.com/Lundqwist/WoW_Forever_QuestXPTracker/main/Media/logo.png" alt="Quest XP Tracker" width="180"></p>

# Quest XP Tracker

**Track the XP of every quest in your log, see how close it gets you to your next level, and group your quests by the zone where they are actually done.**

Made for **WoW Forever**. Type `/qxp`, use the **Qxp** plugin on Titan Panel, or open it from the **LM** minimap button of LunarMods.

![Quest XP Tracker in game](https://raw.githubusercontent.com/Lundqwist/WoW_Forever_QuestXPTracker/main/Media/IngameImage.png)

---

## How far do my quests take me?

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

## Every quest, grouped by zone

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

## Where is the quest actually done?

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

## Look it up on Wowhead

**Right-click** any quest to get its Wowhead (Forever) link in a small box, already selected:

```
https://www.wowhead.com/forever/quest=783
```

Press **Ctrl+C** to copy it (the box closes by itself), then paste it into your browser. Addons can't open a web browser themselves, so this is the quickest way there.

## Titan Panel and the LM button

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

## Make it your size

Drag the grip in the **bottom-right corner** to resize the window. The columns follow the width and the list follows the height. Size, position, grouping, folded zones and your Active/Inactive choices are saved for each character.

## Commands

| Command | What it does |
|---|---|
| `/qxp` or `/questxp` | Show or hide the window |
| `/qxp group` | Switch between grouping by quest log zone and by target area |
| `/qxp target`, `/qxp log` | Group by target area, or by quest log zone |
| `/qxp scan` | Rescan the quest log and work out the target areas again |
| `/qxp reset` | Move the window back to the centre and reset its size |

## Part of LunarMods

Quest XP Tracker works on its own. With **LunarMods** installed it shows up in LunarMods' list (`/lm`), where it can be switched on or off, and in the LM minimap button's tooltip and right-click menu.

## Good to know

- XP rewards are the values the game reports for your current level. Quests far below your level give less.
- Target areas are a best guess from where the mobs, objects and drops are found. A mob that lives in several zones counts for all of them, so a quest can show more than one area in its tooltip.
- The quest list pauses while you're in combat and catches up as soon as combat ends.
- At max level the bar shows your level and the total quest XP only.
- Version 1.5 removed the quest items window and the Qxp minimap button (LunarMods' LM button replaces it).

## Source and bugs

The addon is open source under the MIT license: [github.com/Lundqwist/WoW_Forever_QuestXPTracker](https://github.com/Lundqwist/WoW_Forever_QuestXPTracker). Bug reports and ideas are welcome under Issues. If you get an error, please include the text from BugSack or BugGrabber.
