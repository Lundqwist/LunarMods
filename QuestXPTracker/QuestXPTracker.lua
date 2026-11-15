-- Quest XP Tracker
-- Lists every quest in the quest log, grouped by zone, with its XP reward, and shows how
-- far the XP from all *active* quests takes you toward the next level.
-- The list can be grouped by the zone the quest log puts a quest under (usually where
-- it was picked up), or by its target area: where its objectives are done, or where it
-- is turned in once it is complete. Target areas come from QuestieDB when it is
-- installed, otherwise from the game's own next-waypoint data.
-- Also provides a LibDataBroker feed (shown by Titan Panel). It has no minimap button of
-- its own: LunarMods' "LM" button opens it and shows its summary.
-- Works on Retail-style clients (WoW Forever, Midnight) through C_QuestLog
-- and falls back to the older global API otherwise.

local ADDON_NAME = ...
local ICON = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\QxpIcon"

----------------------------------------------------------------------------------------
-- Saved data (per character)
----------------------------------------------------------------------------------------
-- QuestXPTrackerDB = {
--   quests         = { [questID] = { title, level, zone, xp,      -- cache, so quests under
--                                    target, targets, turnIn } }, -- collapsed log headers stay listed
--   excluded       = { [questID] = true },                        -- "Inactive": not counted
--   collapsedZones = { [zone] = true },                           -- zone groups folded in our list
--   size           = { w, h },       -- main window (height used while the list is open)
--   groupBy        = "log" | "target",
--   listOpen, sortKey, sortAsc, point = { point, relPoint, x, y }, shown
-- }
local DB

local DEFAULTS = {
    quests         = {},
    excluded       = {},
    collapsedZones = {},
    size           = { w = 480, h = 432 },
    groupBy        = "log",
    listOpen       = true,
    sortKey        = "xp",
    sortAsc        = false,
    shown          = true,
}

----------------------------------------------------------------------------------------
-- Quest log API wrappers (Retail vs Classic)
----------------------------------------------------------------------------------------
local HAS_INFO = C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetNumQuestLogEntries and true or false
local IsOnQuest = C_QuestLog and C_QuestLog.IsOnQuest

local MAX_QUESTS = 40 -- quest log cap on WoW Forever

-- Returns the number of log entries (headers included) and the number of quests
local function NumEntries()
    local entries, quests
    if HAS_INFO then
        entries, quests = C_QuestLog.GetNumQuestLogEntries()
    else
        entries, quests = GetNumQuestLogEntries()
    end
    return entries or 0, quests
end

local function GetEntry(i)
    if HAS_INFO then
        local info = C_QuestLog.GetInfo(i)
        if not info then return nil end
        return {
            title       = info.title,
            level       = info.level,
            isHeader    = info.isHeader,
            isCollapsed = info.isCollapsed,
            questID     = info.questID,
            isHidden    = info.isHidden or info.isBounty,
        }
    end
    local title, level, _, isHeader, isCollapsed, _, _, questID = GetQuestLogTitle(i)
    if not title then return nil end
    return {
        title       = title,
        level       = level,
        isHeader    = isHeader,
        isCollapsed = isCollapsed,
        questID     = questID,
    }
end

-- The modern client (Forever / Midnight) can return "secret" values in some situations;
-- treat those as unknown instead of erroring on arithmetic.
local function Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

local function ReadXP(index, questID)
    if HAS_INFO then
        return Plain(GetQuestLogRewardXP(questID)) or 0
    end
    -- Classic: the reward functions read the currently selected quest.
    SelectQuestLogEntry(index)
    return Plain(GetQuestLogRewardXP()) or 0
end

-- Objectives of a quest in the log: { text = "Linen Cloth: 3/6", type = "item", finished = bool }
local function ReadObjectives(index, questID)
    local list = {}
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questID)
        if ok and objs then
            for _, o in ipairs(objs) do
                local t = Plain(o.text)
                if t and t ~= "" then
                    list[#list + 1] = { text = t, type = Plain(o.type), finished = Plain(o.finished) }
                end
            end
            return list
        end
    end
    if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for j = 1, (GetNumQuestLeaderBoards(index) or 0) do
            local t, kind, finished = GetQuestLogLeaderBoard(j, index)
            if t and t ~= "" then list[#list + 1] = { text = t, type = kind, finished = finished } end
        end
    end
    return list
end

local function QuestTitleByID(questID)
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local t = C_QuestLog.GetTitleForQuestID(questID)
        if t and t ~= "" then return t end
    end
    if QuestUtils_GetQuestName then
        local t = QuestUtils_GetQuestName(questID)
        if t and t ~= "" then return t end
    end
    return "Quest #" .. questID
end

----------------------------------------------------------------------------------------
-- Target area: where a quest is actually done
----------------------------------------------------------------------------------------
-- A quest picked up in Orgrimmar that asks for an item dropped in the Barrens sits under
-- "Orgrimmar" in the quest log; its target area is "The Barrens". With QuestieDB the
-- spawn points of every unfinished objective (mobs to kill, objects to use, mobs and
-- objects that drop the items, places to explore) are counted per zone, and the zone
-- with the most of them wins. A complete quest's target is where it is turned in.
-- Without QuestieDB the game's next waypoint for the quest is used, if it has one.

local function QDB()
    local lib = _G.LibQuestieDB
    if lib and lib.Quest and lib.Npc and lib.Object and lib.Item then return lib end
end

-- One field of a QuestieDB entity, or nil (never an error)
local function Field(entity, field, id)
    local f = entity and entity[field]
    if type(f) ~= "function" or not id then return nil end
    local ok, v = pcall(f, id)
    if ok then return v end
end

local function AreaName(areaID)
    if type(areaID) ~= "number" or areaID <= 0 then return nil end
    if C_Map and C_Map.GetAreaInfo then
        local ok, name = pcall(C_Map.GetAreaInfo, areaID)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
end

local function MapName(uiMapID)
    if not uiMapID or not (C_Map and C_Map.GetMapInfo) then return nil end
    local info = C_Map.GetMapInfo(uiMapID)
    return info and info.name ~= "" and info.name or nil
end

-- spawns = { [areaID] = { {x, y}, ... } }: adds to counts[areaID]
local function CountSpawns(counts, spawns)
    if type(spawns) ~= "table" then return end
    for areaID, coords in pairs(spawns) do
        if type(areaID) == "number" then
            local n = (type(coords) == "table" and #coords > 0) and #coords or 1
            counts[areaID] = (counts[areaID] or 0) + n
        end
    end
end

-- Adds one objective's spawn counts to the score, weighted so every objective counts
-- the same however many spawn points it has
local function AddObjective(score, counts)
    local total = 0
    for _, n in pairs(counts) do total = total + n end
    if total == 0 then return false end
    for areaID, n in pairs(counts) do
        score[areaID] = (score[areaID] or 0) + n / total
    end
    return true
end

local MAX_SOURCES = 25 -- mobs or objects per item looked at; plenty to find the zone

local function SpawnsOf(entity, ids)
    local counts = {}
    if type(ids) == "table" then
        for i, id in ipairs(ids) do
            if i > MAX_SOURCES then break end
            CountSpawns(counts, Field(entity, "spawns", id))
        end
    end
    return counts
end

local function Merge(into, from)
    for k, n in pairs(from) do into[k] = (into[k] or 0) + n end
    return into
end

-- True when a finished objective in the quest log mentions this name
local function IsFinished(name, objectives)
    if not name or name == "" then return false end
    for _, o in ipairs(objectives) do
        if o.finished and o.text:find(name, 1, true) then return true end
    end
    return false
end

local function QuestIsComplete(questID, objectives)
    if C_QuestLog and C_QuestLog.IsComplete then
        local ok, done = pcall(C_QuestLog.IsComplete, questID)
        if ok and done ~= nil then return Plain(done) and true or false end
    end
    if #objectives == 0 then return false end
    for _, o in ipairs(objectives) do
        if not o.finished then return false end
    end
    return true
end

-- Returns the area score { [areaID] = weight } from QuestieDB, or nil
local function QuestieScore(lib, questID, complete, objectives)
    if not Field(lib.Quest, "name", questID) then return nil end
    local score, any = {}, false

    if complete then
        local finisher = Field(lib.Quest, "finishedBy", questID)
        if type(finisher) == "table" then
            local counts = Merge(SpawnsOf(lib.Npc, finisher[1]), SpawnsOf(lib.Object, finisher[2]))
            any = AddObjective(score, counts) or any
        end
        return any and score or nil
    end

    local objs = Field(lib.Quest, "objectives", questID)
    if type(objs) == "table" then
        -- [1] creatures, [2] objects, [3] items, [5] kill credit
        for _, o in ipairs(objs[1] or {}) do
            if not IsFinished(o[2] or Field(lib.Npc, "name", o[1]), objectives) then
                any = AddObjective(score, SpawnsOf(lib.Npc, { o[1] })) or any
            end
        end
        for _, o in ipairs(objs[2] or {}) do
            if not IsFinished(o[2] or Field(lib.Object, "name", o[1]), objectives) then
                any = AddObjective(score, SpawnsOf(lib.Object, { o[1] })) or any
            end
        end
        for _, o in ipairs(objs[3] or {}) do
            if not IsFinished(o[2] or Field(lib.Item, "name", o[1]), objectives) then
                local counts = Merge(SpawnsOf(lib.Npc, Field(lib.Item, "npcDrops", o[1])),
                                     SpawnsOf(lib.Object, Field(lib.Item, "objectDrops", o[1])))
                any = AddObjective(score, counts) or any
            end
        end
        for _, o in ipairs(objs[5] or {}) do
            if not IsFinished(o[3] or Field(lib.Npc, "name", o[2]), objectives) then
                any = AddObjective(score, SpawnsOf(lib.Npc, o[1])) or any
            end
        end
    end
    -- "Explore X" objectives
    local trigger = Field(lib.Quest, "triggerEnd", questID)
    if type(trigger) == "table" and not IsFinished(trigger[1], objectives) then
        local counts = {}
        CountSpawns(counts, trigger[2])
        any = AddObjective(score, counts) or any
    end
    return any and score or nil
end

-- cache[questID] = { key = progress signature, target, targets, turnIn }
local targetCache = {}

-- Works out a quest's target area. Returns the main area's name (or nil), the other
-- areas with objectives (a list of names) and whether it's the turn-in place.
local function FindTarget(questID, objectives)
    local complete = QuestIsComplete(questID, objectives)
    local sig = { complete and "c" or "o" }
    for _, o in ipairs(objectives) do sig[#sig + 1] = o.finished and "1" or "0" end
    local key = table.concat(sig)
    local cached = targetCache[questID]
    if cached and cached.key == key then
        return cached.target, cached.targets, cached.turnIn
    end

    local target, targets = nil, {}
    local lib = QDB()
    local score = lib and QuestieScore(lib, questID, complete, objectives)
    if score then
        local list = {}
        for areaID, w in pairs(score) do
            local name = AreaName(areaID)
            if name then list[#list + 1] = { name = name, w = w } end
        end
        -- areas can share a name (a zone and its instance); add those together
        local byName, merged = {}, {}
        for _, a in ipairs(list) do
            local m = byName[a.name]
            if m then m.w = m.w + a.w else byName[a.name] = a; merged[#merged + 1] = a end
        end
        table.sort(merged, function(a, b)
            if a.w ~= b.w then return a.w > b.w end
            return a.name < b.name
        end)
        if merged[1] then
            target = merged[1].name
            for i = 2, #merged do
                if merged[i].w >= merged[1].w * 0.2 then targets[#targets + 1] = merged[i].name end
            end
        end
    end
    if not target and C_QuestLog and C_QuestLog.GetNextWaypoint then
        local ok, mapID = pcall(C_QuestLog.GetNextWaypoint, questID)
        if ok then target = MapName(Plain(mapID)) end
    end

    targetCache[questID] = { key = key, target = target, targets = targets, turnIn = complete }
    return target, targets, complete
end

----------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------
local function Fmt(n)
    n = math.floor((n or 0) + 0.5)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(n) end
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

local function IsActive(questID)
    return not DB.excluded[questID]
end

local function QuestLink(questID, q)
    q = q or {}
    if GetQuestLink then
        local ok, link
        if HAS_INFO then
            ok, link = pcall(GetQuestLink, questID)
        elseif q.index then
            ok, link = pcall(GetQuestLink, q.index)
        end
        if ok and link then return link end
    end
    return string.format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", questID, q.level or 0, q.title or QuestTitleByID(questID))
end

local function InsertChatLink(link)
    if not link then return end
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
    if ChatFrame_OpenChat then ChatFrame_OpenChat(link) end
end

local function WantsLink()
    return (IsModifiedClick and IsModifiedClick("CHATLINK")) or IsShiftKeyDown()
end

local function OpenQuest(questID, q)
    q = q or {}
    if HAS_INFO and QuestMapFrame_OpenToQuestDetails then
        QuestMapFrame_OpenToQuestDetails(questID)
        return
    end
    if QuestLogFrame and ShowUIPanel then
        ShowUIPanel(QuestLogFrame)
        if q.index and QuestLog_SetSelection then
            QuestLog_SetSelection(q.index)
            if QuestLog_Update then QuestLog_Update() end
        end
    elseif ToggleQuestLog then
        ToggleQuestLog()
    end
end

local function DifficultyColor(level)
    if GetQuestDifficultyColor and level and level > 0 then
        local c = GetQuestDifficultyColor(level)
        if c then return c.r, c.g, c.b end
    end
    return 1, 0.82, 0
end

local function SetQuestTooltip(owner, questID, q, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "quest:" .. questID .. ":" .. ((q and q.level) or 0))
    if not ok then
        GameTooltip:ClearLines()
        GameTooltip:AddLine((q and q.title) or QuestTitleByID(questID))
    end
end

----------------------------------------------------------------------------------------
-- Wowhead links. Addons can't open a web browser, so this shows the URL selected in a
-- box: Ctrl+C copies it (and closes the box), then paste it into your browser.
----------------------------------------------------------------------------------------
local WOWHEAD = "https://www.wowhead.com/forever/"

local urlBox = CreateFrame("Frame", "QuestXPTrackerURLFrame", UIParent, "BackdropTemplate")
urlBox:SetSize(420, 92)
urlBox:SetPoint("CENTER", 0, 120)
urlBox:SetFrameStrata("DIALOG")
urlBox:SetClampedToScreen(true)
urlBox:EnableMouse(true)
urlBox:SetMovable(true)
urlBox:RegisterForDrag("LeftButton")
urlBox:SetScript("OnDragStart", urlBox.StartMoving)
urlBox:SetScript("OnDragStop", urlBox.StopMovingOrSizing)
urlBox:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
urlBox:Hide()
tinsert(UISpecialFrames, "QuestXPTrackerURLFrame")

urlBox.title = urlBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
urlBox.title:SetPoint("TOPLEFT", 16, -14)
urlBox.title:SetPoint("TOPRIGHT", -36, -14)
urlBox.title:SetJustifyH("LEFT")
urlBox.title:SetWordWrap(false)

local urlClose = CreateFrame("Button", nil, urlBox, "UIPanelCloseButton")
urlClose:SetPoint("TOPRIGHT", -4, -4)

urlBox.edit = CreateFrame("EditBox", nil, urlBox, "InputBoxTemplate")
urlBox.edit:SetPoint("TOPLEFT", 22, -38)
urlBox.edit:SetPoint("TOPRIGHT", -18, -38)
urlBox.edit:SetHeight(22)
urlBox.edit:SetAutoFocus(false)

urlBox.hint = urlBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
urlBox.hint:SetPoint("BOTTOM", 0, 14)
urlBox.hint:SetText("Press Ctrl+C to copy, then paste it into your web browser.")

local function SelectURL()
    urlBox.edit:SetText(urlBox.url or "")
    urlBox.edit:SetFocus()
    urlBox.edit:HighlightText()
end

-- keep the text read-only: any typing puts the URL back
urlBox.edit:SetScript("OnTextChanged", function(self, userInput)
    if userInput and self:GetText() ~= urlBox.url then SelectURL() end
end)
urlBox.edit:SetScript("OnMouseUp", SelectURL)
urlBox.edit:SetScript("OnEscapePressed", function() urlBox:Hide() end)
urlBox.edit:SetScript("OnEnterPressed", function() urlBox:Hide() end)
urlBox.edit:SetScript("OnKeyDown", function(_, key)
    if key == "C" and IsControlKeyDown() then
        C_Timer.After(0.1, function()
            urlBox:Hide()
            print("|cffffd200Quest XP Tracker:|r Wowhead link copied.")
        end)
    end
end)
urlBox:SetScript("OnShow", SelectURL)
urlBox:SetScript("OnHide", function() urlBox.edit:ClearFocus() end)

local function ShowWowhead(kind, id, name)
    if not id then return end
    urlBox.url = WOWHEAD .. kind .. "=" .. id
    urlBox.title:SetText("Wowhead: " .. (name or (kind .. " " .. id)))
    if urlBox:IsShown() then SelectURL() else urlBox:Show() end
end

local function SmallButton(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 18)
    b:SetText(text)
    b:SetNormalFontObject("GameFontNormalSmall")
    b:SetHighlightFontObject("GameFontHighlightSmall")
    b:SetDisabledFontObject("GameFontDisableSmall")
    return b
end

local function SetBounds(f, minW, minH, maxW, maxH)
    if f.SetResizeBounds then
        f:SetResizeBounds(minW, minH, maxW, maxH)
    else
        if f.SetMinResize then f:SetMinResize(minW, minH) end
        if f.SetMaxResize then f:SetMaxResize(maxW, maxH) end
    end
end

-- Size grip in the bottom-right corner
local function AddResizeGrip(f, onDone)
    f:SetResizable(true)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(f:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        f.isSizing = true
        f:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        f.isSizing = false
        if onDone then onDone(f) end
    end)
    return grip
end

local function NewScrollList(parent, name)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(100, 100)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(w)
    end)
    return scroll, content
end

----------------------------------------------------------------------------------------
-- Quest use data (filled while scanning the quest log, not saved)
----------------------------------------------------------------------------------------
-- questUse[questID] = { objectives = { { text = "Item: 1/5", type = "item", finished }, ... } }
local questUse = {}
-- quest count reported by the game at the last scan (nil until the first scan)
local logQuestCount

----------------------------------------------------------------------------------------
-- Totals (shared by the window, the LunarMods tooltip and the Titan / LDB feed)
----------------------------------------------------------------------------------------
local function GetSummary()
    local s = { total = 0, count = 0, active = 0 }
    for id, q in pairs(DB.quests) do
        s.count = s.count + 1
        if IsActive(id) then
            s.active = s.active + 1
            s.total = s.total + (q.xp or 0)
        end
    end
    s.level = Plain(UnitLevel("player")) or 0
    s.cur = Plain(UnitXP("player")) or 0
    s.max = Plain(UnitXPMax("player")) or 0
    local maxLevel = GetMaxPlayerLevel and GetMaxPlayerLevel()
    s.atMax = (s.max == 0) or (maxLevel and s.level >= maxLevel) or false
    s.needed = math.max(s.max - s.cur, 0)
    s.inLog = logQuestCount or s.count
    return s
end

local function QuestCountText(n)
    local color = (n >= MAX_QUESTS) and "ff4040" or (n >= MAX_QUESTS - 5) and "ffd200" or "20ff20"
    return string.format("|cff%s%d|r/%d", color, n, MAX_QUESTS)
end

local function AddSummaryLines(tt, s)
    tt:AddDoubleLine("Quest log", QuestCountText(s.inLog), 1, 1, 1, 1, 1, 1)
    if s.atMax then
        tt:AddDoubleLine("Level", s.level .. " (max)", 1, 1, 1, 1, 1, 1)
    else
        tt:AddDoubleLine("Level " .. s.level, Fmt(s.cur) .. " / " .. Fmt(s.max), 1, 1, 1, 1, 1, 1)
        tt:AddDoubleLine("Needed to level", Fmt(s.needed), 1, 1, 1, 1, 1, 1)
    end
    tt:AddDoubleLine(string.format("Active quests (%d/%d)", s.active, s.count), Fmt(s.total) .. " XP", 1, 1, 1, 0.2, 1, 0.3)
    if not s.atMax then
        if s.total >= s.needed then
            tt:AddLine(string.format("Enough to level! %s XP over.", Fmt(s.total - s.needed)), 0.2, 1, 0.3)
        else
            tt:AddLine(string.format("Short by %s XP after turning in.", Fmt(s.needed - s.total)), 1, 0.5, 0.25)
        end
    end
end

----------------------------------------------------------------------------------------
-- Main window
----------------------------------------------------------------------------------------
local ROW_H      = 18
local INDENT     = 18
local TOP_H      = 150   -- everything above the quest list
local CLOSED_H   = 138   -- window height with the list folded
local BOTTOM_PAD = 30    -- room under the list for the size grip
local MAIN_MIN_W, MAIN_MIN_H = 420, TOP_H + ROW_H * 5 + BOTTOM_PAD
local BTN_W, XP_W = 56, 64

local frame, bar, projBar, barText, lineNeeded, lineQuests, lineResult
local dropBtn, dropIcon, dropText, colHeader, scroll, content, emptyText, mainGrip
local rows = {}
local Refresh -- forward declaration

local function SavePosition()
    local p, _, rp, x, y = frame:GetPoint()
    if DB and p then DB.point = { p, rp, x, y } end
end

frame = CreateFrame("Frame", "QuestXPTrackerFrame", UIParent, "BackdropTemplate")
frame:SetSize(480, CLOSED_H)
frame:SetPoint("CENTER")
frame:SetFrameStrata("MEDIUM")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SavePosition()
end)
frame:SetScript("OnHide", function() if DB then DB.shown = false end end)
frame:SetScript("OnShow", function() if DB then DB.shown = true end; if Refresh then Refresh() end end)
frame:Hide()
tinsert(UISpecialFrames, "QuestXPTrackerFrame") -- Escape closes it

local titleIcon = frame:CreateTexture(nil, "OVERLAY")
titleIcon:SetSize(20, 20)
titleIcon:SetPoint("TOPLEFT", 10, -6)
titleIcon:SetTexture(ICON)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", titleIcon, "RIGHT", 6, 0)
title:SetText("Quest XP Tracker")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)

-- Switches the grouping between the quest log's zones and the target areas
local groupBtn = SmallButton(frame, "By target area", 100)
groupBtn:SetPoint("RIGHT", close, "LEFT", -2, 0)
groupBtn:SetScript("OnClick", function()
    DB.groupBy = (DB.groupBy == "target") and "log" or "target"
    Refresh()
end)
groupBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Group the quests by")
    GameTooltip:AddLine("Quest log zone: where the quest log lists it, usually where you picked it up.", 1, 1, 1, true)
    GameTooltip:AddLine("Target area: where the objectives are done, or where it's turned in once complete.", 1, 1, 1, true)
    if not _G.LibQuestieDB then
        GameTooltip:AddLine("Install Questie (QuestieDB) for the most accurate target areas.", 1, 0.5, 0.25, true)
    end
    GameTooltip:AddLine("Click to switch.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
groupBtn:SetScript("OnLeave", GameTooltip_Hide)

-- "Quests 12/40" in the title bar
local logCount = CreateFrame("Frame", nil, frame)
logCount:SetSize(110, 20)
logCount:SetPoint("RIGHT", groupBtn, "LEFT", -8, 0)
logCount:EnableMouse(true)
logCount.text = logCount:CreateFontString(nil, "OVERLAY", "GameFontNormal")
logCount.text:SetPoint("RIGHT")
logCount:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Quests in your log, out of the maximum " .. MAX_QUESTS)
    GameTooltip:Show()
end)
logCount:SetScript("OnLeave", GameTooltip_Hide)

-- XP bar: projected (current + active quest XP) behind, current XP in front
projBar = CreateFrame("StatusBar", nil, frame)
projBar:SetPoint("TOPLEFT", 12, -34)
projBar:SetPoint("TOPRIGHT", -12, -34)
projBar:SetHeight(20)
projBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
projBar:SetStatusBarColor(0.1, 0.85, 0.2, 0.55)
local barBg = projBar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints()
barBg:SetColorTexture(0, 0, 0, 0.6)

bar = CreateFrame("StatusBar", nil, projBar)
bar:SetAllPoints(projBar)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.58, 0.0, 0.85, 1)
bar:SetFrameLevel(projBar:GetFrameLevel() + 1)

local barBorder = CreateFrame("Frame", nil, bar, "BackdropTemplate")
barBorder:SetPoint("TOPLEFT", -3, 3)
barBorder:SetPoint("BOTTOMRIGHT", 3, -3)
barBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
barBorder:SetBackdropBorderColor(0.7, 0.7, 0.7, 1)

barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
barText:SetPoint("CENTER")

projBar:EnableMouse(true)
projBar:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Experience")
    GameTooltip:AddLine("Purple: XP you have this level.", 0.75, 0.4, 1)
    GameTooltip:AddLine("Green: XP you get from turning in all active quests.", 0.2, 1, 0.3)
    GameTooltip:Show()
end)
projBar:SetScript("OnLeave", GameTooltip_Hide)

local function InfoLine(y)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 14, y)
    fs:SetPoint("TOPRIGHT", -14, y)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end
lineNeeded = InfoLine(-62)
lineQuests = InfoLine(-76)
lineResult = InfoLine(-90)

-- Dropdown header
dropBtn = CreateFrame("Button", nil, frame)
dropBtn:SetPoint("TOPLEFT", 10, -108)
dropBtn:SetPoint("TOPRIGHT", -150, -108)
dropBtn:SetHeight(20)
dropIcon = dropBtn:CreateTexture(nil, "ARTWORK")
dropIcon:SetSize(14, 14)
dropIcon:SetPoint("LEFT", 2, 0)
dropText = dropBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dropText:SetPoint("LEFT", dropIcon, "RIGHT", 6, 0)
local dropHl = dropBtn:CreateTexture(nil, "HIGHLIGHT")
dropHl:SetAllPoints()
dropHl:SetColorTexture(1, 1, 1, 0.06)
dropBtn:SetScript("OnClick", function()
    DB.listOpen = not DB.listOpen
    Refresh()
end)

local allOn = SmallButton(frame, "All active", 64)
allOn:SetPoint("TOPRIGHT", -78, -109)
allOn:SetScript("OnClick", function()
    wipe(DB.excluded)
    Refresh()
end)
local allOff = SmallButton(frame, "None", 60)
allOff:SetPoint("TOPRIGHT", -14, -109)
allOff:SetScript("OnClick", function()
    for id in pairs(DB.quests) do DB.excluded[id] = true end
    Refresh()
end)

-- Column headers (click to sort); laid out from the right so they follow the width
colHeader = CreateFrame("Frame", nil, frame)
colHeader:SetPoint("TOPLEFT", 12, -132)
colHeader:SetPoint("TOPRIGHT", -30, -132)
colHeader:SetHeight(16)

local headerButtons = {}
local function HeaderButton(key, label, justify)
    local b = CreateFrame("Button", nil, colHeader)
    b:SetHeight(16)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH(justify or "LEFT")
    b.label, b.fs, b.key = label, fs, key
    b:SetScript("OnClick", function(self)
        if DB.sortKey == self.key then
            DB.sortAsc = not DB.sortAsc
        else
            DB.sortKey = self.key
            DB.sortAsc = (self.key ~= "xp")
        end
        Refresh()
    end)
    headerButtons[#headerButtons + 1] = b
    return b
end
local hCounted = HeaderButton("active", "Counted", "CENTER")
hCounted:SetPoint("TOPRIGHT", -2, 0)
hCounted:SetWidth(BTN_W)
local hXP = HeaderButton("xp", "XP", "RIGHT")
hXP:SetPoint("TOPRIGHT", hCounted, "TOPLEFT", -6, 0)
hXP:SetWidth(XP_W)
local hTitle = HeaderButton("title", "Zone / Quest")
hTitle:SetPoint("TOPLEFT", 4, 0)
hTitle:SetPoint("TOPRIGHT", hXP, "TOPLEFT", -4, 0)

-- Scrolling list (fills the rest of the window)
scroll, content = NewScrollList(frame, "QuestXPTrackerScroll")
scroll:SetPoint("TOPLEFT", 12, -TOP_H)
scroll:SetPoint("BOTTOMRIGHT", -30, BOTTOM_PAD)

emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyText:SetPoint("TOP", 0, -20)
emptyText:SetText("Your quest log is empty.")

mainGrip = AddResizeGrip(frame, function(f)
    DB.size.w, DB.size.h = f:GetWidth(), f:GetHeight()
    SavePosition()
    Refresh()
end)
SetBounds(frame, MAIN_MIN_W, MAIN_MIN_H, 1000, 1000)

----------------------------------------------------------------------------------------
-- Quest list rows: one frame type used for both zone headers and quests
----------------------------------------------------------------------------------------
local function Row_OnEnter(self)
    local e = self.entry
    if not e then return end
    if e.kind == "zone" then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(e.zone)
        GameTooltip:AddDoubleLine("Quests", e.count, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Active", e.active, 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Active XP", Fmt(e.xp), 1, 1, 1, 0.2, 1, 0.3)
        if e.here then GameTooltip:AddLine("You are in this zone.", 0.2, 1, 0.3) end
        GameTooltip:AddLine("Click to fold or unfold.", 0.6, 0.6, 0.6)
    else
        local q = e.q
        SetQuestTooltip(self, e.id, q)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("XP reward", Fmt(q.xp), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine("Quest log zone", q.zone or "?", 1, 1, 1, 1, 1, 1)
        if q.target then
            GameTooltip:AddDoubleLine(q.turnIn and "Turn in at" or "Target area", q.target, 1, 1, 1, 0.2, 1, 0.3)
            if q.targets and #q.targets > 0 then
                GameTooltip:AddDoubleLine("Also objectives in", table.concat(q.targets, ", "), 1, 1, 1, 1, 1, 1)
            end
        else
            GameTooltip:AddDoubleLine("Target area", "unknown", 1, 1, 1, 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine("Shift-click: link in chat. Click: open in quest log.", 0.6, 0.6, 0.6)
        GameTooltip:AddLine("Right-click: Wowhead link.", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function Row_OnClick(self, button)
    local e = self.entry
    if not e then return end
    if button == "RightButton" then
        if e.kind == "quest" then ShowWowhead("quest", e.id, e.q.title) end
        return
    end
    if e.kind == "zone" then
        DB.collapsedZones[e.zone] = (not DB.collapsedZones[e.zone]) or nil
        Refresh()
        return
    end
    if WantsLink() then
        InsertChatLink(QuestLink(e.id, e.q))
    else
        OpenQuest(e.id, e.q)
    end
end

local function Toggle_OnClick(btn)
    local e = btn:GetParent().entry
    if not e then return end
    if e.kind == "zone" then
        -- all active -> make the whole zone inactive; otherwise make it all active
        local makeInactive = (e.active == e.count)
        for _, qe in ipairs(e.quests) do
            DB.excluded[qe.id] = makeInactive or nil
        end
    else
        DB.excluded[e.id] = (not DB.excluded[e.id]) or nil
    end
    Refresh()
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", content, "RIGHT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.12)

    row.fold = row:CreateTexture(nil, "ARTWORK")
    row.fold:SetSize(12, 12)
    row.fold:SetPoint("LEFT", 4, 0)

    row.toggle = SmallButton(row, "Active", BTN_W)
    row.toggle:SetHeight(ROW_H - 2)
    row.toggle:SetPoint("RIGHT", -2, 0)
    row.toggle:SetScript("OnClick", Toggle_OnClick)

    row.xp = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.xp:SetPoint("RIGHT", row.toggle, "LEFT", -6, 0)
    row.xp:SetWidth(XP_W)
    row.xp:SetJustifyH("RIGHT")

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)

    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", Row_OnClick)
    rows[i] = row
    return row
end

local function SetRowTitle(row, x)
    row.title:ClearAllPoints()
    row.title:SetPoint("LEFT", x, 0)
    row.title:SetPoint("RIGHT", row.xp, "LEFT", -4, 0)
end

local function FillZoneRow(row, e)
    row.bg:SetColorTexture(0.35, 0.2, 0.55, 0.35)
    row.fold:Show()
    row.fold:SetTexture(DB.collapsedZones[e.zone] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    SetRowTitle(row, 20)
    row.title:SetFontObject("GameFontNormal")
    local here = e.here and "  |cff20ff20(you are here)|r" or ""
    row.title:SetText(string.format("%s  |cffaaaaaa(%d/%d)|r%s", e.zone, e.active, e.count, here))
    row.title:SetTextColor(1, 0.82, 0)
    row.xp:SetText("|cff20ff20" .. Fmt(e.xp) .. "|r")
    row.title:SetAlpha(1); row.xp:SetAlpha(1)
    if e.active == e.count then
        row.toggle:SetText("Active")
    elseif e.active == 0 then
        row.toggle:SetText("Inactive")
    else
        row.toggle:SetText("Mixed")
    end
end

local function FillQuestRow(row, e, stripe)
    row.bg:SetColorTexture(1, 1, 1, stripe and 0.04 or 0)
    row.fold:Hide()
    SetRowTitle(row, 4 + INDENT)
    local r, g, b = DifficultyColor(e.q.level)
    local lvl = (e.q.level and e.q.level > 0) and ("[" .. e.q.level .. "] ") or ""
    row.title:SetFontObject("GameFontNormalSmall")
    -- the other zone, in grey, when it differs from the group the quest is under
    local other = ""
    local q = e.q
    if DB.groupBy == "target" then
        if q.zone and q.zone ~= e.group then other = "  |cff9d9d9d(from " .. q.zone .. ")|r" end
    elseif q.target and q.target ~= e.group then
        other = "  |cff9d9d9d> " .. q.target .. "|r"
    end
    if q.turnIn then other = "  |cff20ff20(done)|r" .. other end
    row.title:SetText(lvl .. (q.title or "?") .. other)
    row.title:SetTextColor(r, g, b)
    row.xp:SetText(Fmt(e.q.xp))
    local alpha = e.active and 1 or 0.4
    row.title:SetAlpha(alpha); row.xp:SetAlpha(alpha)
    row.toggle:SetText(e.active and "Active" or "Inactive")
end

----------------------------------------------------------------------------------------
-- Building the grouped quest list
----------------------------------------------------------------------------------------
local function Compare(va, vb, asc, tieA, tieB)
    if va == vb then return tieA < tieB end
    if asc then return va < vb else return va > vb end
end

-- The group a quest is listed under: its quest log zone, or its target area
local function GroupOf(q)
    if DB.groupBy == "target" and q.target then return q.target end
    return q.zone or (UNKNOWN or "Unknown")
end

local function BuildEntries()
    local zones, byZone = {}, {}
    local current = GetRealZoneText and GetRealZoneText() or nil
    for id, q in pairs(DB.quests) do
        local zname = GroupOf(q)
        local z = byZone[zname]
        if not z then
            z = { kind = "zone", zone = zname, count = 0, active = 0, xp = 0, quests = {}, here = (zname == current) }
            byZone[zname] = z
            zones[#zones + 1] = z
        end
        local active = IsActive(id)
        z.count = z.count + 1
        if active then
            z.active = z.active + 1
            z.xp = z.xp + (q.xp or 0)
        end
        z.quests[#z.quests + 1] = { kind = "quest", id = id, q = q, active = active, group = zname }
    end

    local key, asc = DB.sortKey, DB.sortAsc
    table.sort(zones, function(a, b)
        -- grouped by target area, the zone you are in comes first
        if DB.groupBy == "target" and a.here ~= b.here then return a.here end
        if key == "xp" then return Compare(a.xp, b.xp, asc, a.zone, b.zone) end
        if key == "active" then return Compare(a.active, b.active, asc, a.zone, b.zone) end
        return Compare(a.zone, b.zone, asc, a.zone, b.zone)
    end)

    local list = {}
    for _, z in ipairs(zones) do
        table.sort(z.quests, function(a, b)
            local ta, tb = a.q.title or "", b.q.title or ""
            if key == "xp" then return Compare(a.q.xp or 0, b.q.xp or 0, asc, ta, tb) end
            if key == "active" then return Compare(a.active and 1 or 0, b.active and 1 or 0, asc, ta, tb) end
            return Compare(ta, tb, asc, ta, tb)
        end)
        list[#list + 1] = z
        if not DB.collapsedZones[z.zone] then
            for _, e in ipairs(z.quests) do list[#list + 1] = e end
        end
    end
    return list
end

local function ToggleWindow()
    frame:SetShown(not frame:IsShown())
end

local function ShowBrokerTooltip(tt)
    tt:AddLine("Quest XP Tracker")
    AddSummaryLines(tt, GetSummary())
    tt:AddLine(" ")
    tt:AddLine("Left-click: show / hide the window", 0.6, 0.6, 0.6)
    tt:AddLine("Right-click: fold / unfold the quest list", 0.6, 0.6, 0.6)
end

local function BrokerClick(button)
    if button == "RightButton" then
        DB.listOpen = not DB.listOpen
        if not frame:IsShown() then frame:Show() end
        Refresh()
    else
        ToggleWindow()
    end
end

----------------------------------------------------------------------------------------
-- Ways in: /qxp, the Titan / LDB feed below, and LunarMods' "LM" minimap button
-- (its tooltip and menu). No minimap button or addon compartment entry of our own.
----------------------------------------------------------------------------------------
-- Named in the .toc as X-LunarMods-Tooltip: LunarMods adds these lines to its button's tooltip
function QuestXPTracker_LunarModsTooltip(tt)
    if not DB then return end
    AddSummaryLines(tt, GetSummary())
end

----------------------------------------------------------------------------------------
-- LibDataBroker feed: Titan Panel (and other broker displays) pick this up
----------------------------------------------------------------------------------------
local broker
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
if LDB then
    broker = LDB:NewDataObject(ADDON_NAME, {
        type  = "data source",
        label = "Qxp",
        text  = "0 XP",
        icon  = ICON,
        OnClick = function(_, button) BrokerClick(button) end,
        OnTooltipShow = function(tt) ShowBrokerTooltip(tt) end,
    })
end

local function UpdateBroker(s)
    if not broker then return end
    if s.atMax then
        broker.text = Fmt(s.total) .. " XP"
    elseif s.total >= s.needed and s.needed > 0 then
        broker.text = "|cff20ff20" .. Fmt(s.total) .. "|r / " .. Fmt(s.needed) .. " XP"
    else
        broker.text = Fmt(s.total) .. " / " .. Fmt(s.needed) .. " XP"
    end
end

----------------------------------------------------------------------------------------
-- Refresh (main window)
----------------------------------------------------------------------------------------
Refresh = function()
    if not DB then return end
    local s = GetSummary()
    UpdateBroker(s)
    if not frame:IsShown() then return end

    -- size: the height is fixed while the list is folded
    if not frame.isSizing then
        frame:SetWidth(DB.size.w)
        frame:SetHeight(DB.listOpen and DB.size.h or CLOSED_H)
    end
    mainGrip:SetShown(DB.listOpen)
    logCount.text:SetText("|cffffffffQuests|r " .. QuestCountText(s.inLog))
    groupBtn:SetText(DB.groupBy == "target" and "By target area" or "By quest log")

    -- XP bar
    if s.atMax then
        bar:SetMinMaxValues(0, 1); bar:SetValue(1)
        projBar:SetMinMaxValues(0, 1); projBar:SetValue(1)
        barText:SetText("Level " .. s.level .. " (max level)")
        lineNeeded:SetText("")
        lineQuests:SetText("Active quests: " .. Fmt(s.total) .. " XP")
        lineResult:SetText("")
    else
        bar:SetMinMaxValues(0, s.max); bar:SetValue(s.cur)
        projBar:SetMinMaxValues(0, s.max); projBar:SetValue(math.min(s.cur + s.total, s.max))
        barText:SetText(string.format("Level %d:  %s / %s XP  (%d%%)", s.level, Fmt(s.cur), Fmt(s.max), math.floor(s.cur / s.max * 100)))
        lineNeeded:SetText(string.format("XP needed for level %d:  |cffffffff%s|r  (level %d needs %s XP in total)",
            s.level + 1, Fmt(s.needed), s.level, Fmt(s.max)))
        lineQuests:SetText(string.format("XP from active quests:  |cff20ff20%s|r  (%d%% of this level)",
            Fmt(s.total), math.floor(s.total / s.max * 100)))
        if s.total >= s.needed then
            lineResult:SetText(string.format("|cff20ff20Enough to level up!|r  %s XP over into level %d",
                Fmt(s.total - s.needed), s.level + 1))
        else
            lineResult:SetText(string.format("|cffff8040Still short after turning them all in:|r  %s XP", Fmt(s.needed - s.total)))
        end
    end

    -- dropdown header
    dropIcon:SetTexture(DB.listOpen and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
    dropText:SetText(string.format("Quests in log: %d  (%d active)", s.count, s.active))

    colHeader:SetShown(DB.listOpen)
    scroll:SetShown(DB.listOpen)
    allOn:SetShown(DB.listOpen)
    allOff:SetShown(DB.listOpen)

    for _, b in ipairs(headerButtons) do
        local label = b.label
        if b.key == DB.sortKey then
            b.fs:SetTextColor(1, 1, 1)
            label = label .. (DB.sortAsc and " ^" or " v")
        else
            b.fs:SetTextColor(1, 0.82, 0)
        end
        b.fs:SetText(label)
    end

    if not DB.listOpen then return end

    -- rows
    local list = BuildEntries()
    local stripe = false
    for i, e in ipairs(list) do
        local row = GetRow(i)
        row.entry = e
        if e.kind == "zone" then
            FillZoneRow(row, e)
            stripe = false
        else
            stripe = not stripe
            FillQuestRow(row, e, stripe)
        end
        row:Show()
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
        rows[i].entry = nil
    end
    emptyText:SetShown(#list == 0)
    content:SetHeight(math.max(#list * ROW_H, scroll:GetHeight()))
end

----------------------------------------------------------------------------------------
-- Quest log scanning
----------------------------------------------------------------------------------------
local scanAfterCombat = false
local function ScanQuestLog()
    if not DB then return end
    if InCombatLockdown and InCombatLockdown() then
        scanAfterCombat = true   -- rescan on PLAYER_REGEN_ENABLED
        Refresh()
        return
    end
    local n, numQuests = NumEntries()
    logQuestCount = Plain(numQuests)
    if n == 0 then
        -- Can be a not-yet-loaded log at login; only clear the cache when the game
        -- can confirm we're on none of the cached quests.
        if IsOnQuest then
            for id in pairs(DB.quests) do
                if not IsOnQuest(id) then DB.quests[id] = nil; DB.excluded[id] = nil end
            end
        end
        wipe(questUse)
        Refresh()
        return
    end

    local prevSel = (not HAS_INFO and GetQuestLogSelection) and GetQuestLogSelection() or nil
    local seen, zone, sawCollapsed = {}, UNKNOWN or "Unknown", false

    for i = 1, n do
        local e = GetEntry(i)
        if e then
            if e.isHeader then
                zone = e.title or zone
                if e.isCollapsed then sawCollapsed = true end
            elseif e.questID and e.questID > 0 and e.title and not e.isHidden then
                local q = DB.quests[e.questID] or {}
                q.title = e.title
                q.level = e.level
                q.zone  = zone
                q.xp    = ReadXP(i, e.questID)
                q.index = i
                DB.quests[e.questID] = q
                seen[e.questID] = true
                local objectives = ReadObjectives(i, e.questID)
                questUse[e.questID] = { objectives = objectives }
                q.target, q.targets, q.turnIn = FindTarget(e.questID, objectives)
            end
        end
    end

    if prevSel and prevSel > 0 and SelectQuestLogEntry then
        SelectQuestLogEntry(prevSel)
    end

    -- Forget quests that are no longer in the log. Quests hidden under a collapsed
    -- header are kept (with their last known XP) until they're turned in or abandoned.
    for id, q in pairs(DB.quests) do
        if not seen[id] then
            q.index = nil
            local keep
            if IsOnQuest then keep = IsOnQuest(id) else keep = sawCollapsed end
            if not keep then
                DB.quests[id] = nil
                DB.excluded[id] = nil
                questUse[id] = nil
            end
        end
    end
    for id in pairs(questUse) do
        if not DB.quests[id] then questUse[id] = nil end
    end
    for id in pairs(targetCache) do
        if not DB.quests[id] then targetCache[id] = nil end
    end

    Refresh()
end

local scanPending = false
local function QueueScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(0.3, function()
        scanPending = false
        ScanQuestLog()
    end)
end

----------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------
local events = CreateFrame("Frame")

local function SafeRegister(ev)
    pcall(events.RegisterEvent, events, ev)
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                CopyDefaults(dst[k], v)
            else
                dst[k] = v
            end
        end
    end
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        QuestXPTrackerDB = QuestXPTrackerDB or {}
        DB = QuestXPTrackerDB
        CopyDefaults(DB, DEFAULTS)
        if DB.sortKey == "zone" then DB.sortKey = "title" end -- column removed in 1.1
        DB.size.w = math.max(DB.size.w, MAIN_MIN_W)
        DB.size.h = math.max(DB.size.h, MAIN_MIN_H)
        DB.itemSize, DB.itemsShown = nil, nil -- quest items window removed in 1.5
        DB.minimap = nil                      -- own minimap button removed in 1.5 (LunarMods has one)
        if DB.point then
            frame:ClearAllPoints()
            frame:SetPoint(DB.point[1], UIParent, DB.point[2], DB.point[3], DB.point[4])
        end
        frame:SetWidth(DB.size.w)
        events:UnregisterEvent("ADDON_LOADED")
        SafeRegister("PLAYER_ENTERING_WORLD")
        SafeRegister("QUEST_LOG_UPDATE")
        SafeRegister("QUEST_ACCEPTED")
        SafeRegister("QUEST_REMOVED")
        SafeRegister("QUEST_TURNED_IN")
        SafeRegister("PLAYER_LEVEL_UP")
        SafeRegister("PLAYER_XP_UPDATE")
        SafeRegister("PLAYER_REGEN_ENABLED")
        SafeRegister("ZONE_CHANGED_NEW_AREA")
        return
    end

    if event == "ZONE_CHANGED_NEW_AREA" then
        Refresh() -- moves the "you are here" mark
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if scanAfterCombat then
            scanAfterCombat = false
            QueueScan()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if DB.shown then frame:Show() end
        QueueScan()
    elseif (event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED") and arg1 then
        DB.quests[arg1] = nil
        DB.excluded[arg1] = nil
        questUse[arg1] = nil
        QueueScan()
    elseif event == "PLAYER_XP_UPDATE" then
        Refresh()
    else
        QueueScan()
    end
end)

----------------------------------------------------------------------------------------
-- Slash commands
----------------------------------------------------------------------------------------
SLASH_QUESTXPTRACKER1 = "/qxp"
SLASH_QUESTXPTRACKER2 = "/questxp"
SlashCmdList.QUESTXPTRACKER = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "reset" then
        DB.point = nil
        DB.size.w, DB.size.h = DEFAULTS.size.w, DEFAULTS.size.h
        frame:ClearAllPoints()
        frame:SetPoint("CENTER")
        frame:Show()
        Refresh()
        print("|cffffd200Quest XP Tracker:|r window position and size reset.")
    elseif msg == "scan" then
        wipe(targetCache)
        ScanQuestLog()
    elseif msg == "group" or msg == "target" or msg == "log" then
        if msg == "group" then
            DB.groupBy = (DB.groupBy == "target") and "log" or "target"
        else
            DB.groupBy = msg
        end
        if not frame:IsShown() then frame:Show() end
        Refresh()
        print("|cffffd200Quest XP Tracker:|r quests grouped by " .. (DB.groupBy == "target" and "target area." or "quest log zone."))
    else
        ToggleWindow()
        if frame:IsShown() then QueueScan() end
    end
end
