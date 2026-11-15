-- LunarMods: Core.lua
--
-- LunarMods keeps all of Lundqwist's mods in one list (/lm, or the LM button
-- by the minimap), where each one can be switched on or off with a tick box.
-- It knows two kinds of mods:
--
-- 1. Parts: small addon folders named LunarMods_Something (none yet; make one
--    with tools\new-part.ps1) with
--    this in their .toc file:
--
--        ## Dependencies: LunarMods
--        ## LoadOnDemand: 1
--        ## X-LunarMods-Part: 1
--
--    "LoadOnDemand" means the game does not load the part by itself. At login
--    LunarMods loads only the parts you have switched on. A part that is
--    switched off is never loaded, and ticking it loads it right away.
--
-- 2. Addons: normal addons that also work without LunarMods (FavoriteItems,
--    QuestXPTracker). They are found by "## X-LunarMods: 1" or
--    "## Author: Lundqwist" in their .toc file. Switching one on or off ticks
--    it in the game's own AddOn list, so it takes effect at the next /reload.
--    "## X-LunarMods-Open: /qxp" gives the row an Open button that runs that
--    slash command, and puts the mod in the LM button's right-click menu.
--    "## X-LunarMods-Tooltip: SomeGlobalFunction" lets the mod add lines to
--    the LM button's tooltip: SomeGlobalFunction(GameTooltip) is called.
--
-- LunarMods' "LM" minimap button is the one way in to all of them; the mods
-- have no minimap buttons of their own.
--
-- In its Lua file a part registers itself and gets a small toolbox back:
--
--     local part = LunarMods:NewPart(...)      -- "..." holds the folder name
--     function part:OnEnable()  ... end        -- switched on (login, or ticked in the list)
--     function part:OnDisable() ... end        -- switched off in the list (optional)
--     function part:OnSlash(text) ... end      -- "/lm <part> text" (optional)
--     part:RegisterEvent("PLAYER_LEVEL_UP", function(self, event, ...) ... end)
--     part:Print("hello")
--     part.db      -- a table saved between sessions, shared by all characters
--     part.chardb  -- a table saved between sessions, for this character only

local ADDON = ...

local LunarMods = {}
_G.LunarMods = LunarMods          -- the one global the parts use

LunarMods.version = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "?"
LunarMods.icon = "Interface\\AddOns\\" .. ADDON .. "\\Media\\LMIcon"

local AUTHOR = "Lundqwist"
local PART_PREFIX = "LunarMods_"
local CHAT_NAME = "|cff7fb2ffLunarMods|r"

local parts = {}       -- [folder name] = the part object, once its Lua file has run
local installed = {}   -- list of { name, title, notes, short, kind = "part"|"addon", open } for every mod found
local problems = {}    -- [folder name] = why loading failed, as text
local handlers = {}    -- [event] = { [part] = function }
local loggedIn = false

local events = CreateFrame("Frame")

-- ---------------------------------------------------------------- helpers

function LunarMods:Print(...)
    print(CHAT_NAME .. ": " .. strjoin(" ", tostringall(...)))
end

-- Runs a function and reports an error in the normal way (BugSack and the
-- like see it) instead of letting one part's mistake stop the others.
local function SafeCall(func, ...)
    local ok, err = pcall(func, ...)
    if not ok then
        geterrorhandler()(err)
    end
    return ok
end

-- "LunarMods_SellJunk" -> "selljunk", "QuestXPTracker" -> "questxptracker":
-- the name used in slash commands
local function ShortName(name)
    local short = name
    if strsub(name, 1, #PART_PREFIX) == PART_PREFIX then
        short = strsub(name, #PART_PREFIX + 1)
    end
    return strlower(short)
end

-- Strips colour codes from a title in the .toc file
local function PlainText(text)
    text = text or ""
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

-- ---------------------------------------------------------------- the part toolbox

local Part = {}
Part.__index = Part

function Part:Print(...)
    print(CHAT_NAME .. " |cffffd100" .. self.title .. "|r: " .. strjoin(" ", tostringall(...)))
end

function Part:IsEnabled()
    return self.enabled
end

-- handler: a function(self, event, ...), or the name of one of the part's
-- own methods. Left out, the method with the event's name is used.
function Part:RegisterEvent(event, handler)
    handler = handler or event
    if type(handler) == "string" then
        local method = handler
        handler = function(self, ...) return self[method](self, ...) end
    end
    if not handlers[event] then
        handlers[event] = {}
        events:RegisterEvent(event)
    end
    handlers[event][self] = handler
end

function Part:UnregisterEvent(event)
    local list = handlers[event]
    if not list then return end
    list[self] = nil
    if not next(list) then
        handlers[event] = nil
        -- LunarMods itself needs these two, whatever the parts do
        if event ~= "ADDON_LOADED" and event ~= "PLAYER_LOGIN" then
            events:UnregisterEvent(event)
        end
    end
end

function Part:UnregisterAllEvents()
    for event in pairs(handlers) do
        self:UnregisterEvent(event)
    end
end

-- Called by a part's Lua file: local part = LunarMods:NewPart(...)
function LunarMods:NewPart(name)
    assert(type(name) == "string", "LunarMods:NewPart(name): pass the addon's folder name (use ...)")
    if parts[name] then return parts[name] end

    LunarModsDB.data[name] = LunarModsDB.data[name] or {}
    LunarModsCharDB.data[name] = LunarModsCharDB.data[name] or {}

    local part = setmetatable({
        name = name,
        short = ShortName(name),
        title = C_AddOns.GetAddOnMetadata(name, "X-LunarMods-Title") or ShortName(name),
        enabled = false,
        db = LunarModsDB.data[name],
        chardb = LunarModsCharDB.data[name],
    }, Part)
    parts[name] = part
    return part
end

-- ---------------------------------------------------------------- finding mods

local function IsMine(index)
    if C_AddOns.GetAddOnMetadata(index, "X-LunarMods") then return true end
    local author = C_AddOns.GetAddOnMetadata(index, "Author")
    return author and strlower(strtrim(author)) == strlower(AUTHOR)
end

-- Looks through every installed addon for parts and for Lundqwist's own addons
local function ScanMods()
    wipe(installed)
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, title, notes = C_AddOns.GetAddOnInfo(i)
        if name ~= ADDON then
            local kind
            if C_AddOns.GetAddOnMetadata(i, "X-LunarMods-Part") then
                kind = "part"
            elseif IsMine(i) then
                kind = "addon"
            end
            if kind then
                installed[#installed + 1] = {
                    name = name,
                    kind = kind,
                    short = ShortName(name),
                    title = C_AddOns.GetAddOnMetadata(i, "X-LunarMods-Title") or PlainText(title) or name,
                    notes = notes or "",
                    open = C_AddOns.GetAddOnMetadata(i, "X-LunarMods-Open"),
                    tooltip = C_AddOns.GetAddOnMetadata(i, "X-LunarMods-Tooltip"),
                }
            end
        end
    end
    -- addons first, then parts; by title within each
    table.sort(installed, function(a, b)
        if a.kind ~= b.kind then return a.kind == "addon" end
        return a.title < b.title
    end)
end

function LunarMods:GetMods()
    return installed
end

local function FindInfo(name)
    for _, info in ipairs(installed) do
        if info.name == name then return info end
    end
end

-- The game's own on/off tick for an addon, for this character
local function GameEnabled(name)
    local state = C_AddOns.GetAddOnEnableState(name, UnitName("player"))
    return state and state > 0
end

-- Is the mod switched on in LunarMods' list? New parts start switched on;
-- an addon is on when it is ticked in the game's AddOn list.
function LunarMods:IsWanted(name)
    local info = FindInfo(name)
    if info and info.kind == "addon" then
        return GameEnabled(name)
    end
    return LunarModsDB.parts[name] ~= false
end

local function EnablePart(part)
    if part.enabled then return end
    part.enabled = true
    if part.OnEnable then SafeCall(part.OnEnable, part) end
end

-- Loads the part's addon if needed and switches it on.
-- Returns true, or false and the reason as text.
local function LoadPart(name)
    problems[name] = nil
    if not C_AddOns.IsAddOnLoaded(name) then
        -- In case it is unticked in the game's own AddOn list
        C_AddOns.EnableAddOn(name)
        local loaded, reason = C_AddOns.LoadAddOn(name)
        if not loaded then
            problems[name] = (reason and _G["ADDON_" .. reason]) or reason or "could not be loaded"
            return false, problems[name]
        end
    end

    local part = parts[name]
    if not part then
        problems[name] = "its Lua file never called LunarMods:NewPart(...)"
        return false, problems[name]
    end
    EnablePart(part)
    return true
end

-- Switches a mod on or off, now (parts) or from the next /reload (addons).
function LunarMods:SetWanted(name, wanted)
    local info = FindInfo(name)
    if info and info.kind == "addon" then
        -- No character name: the same for all characters, like the parts
        if wanted then
            C_AddOns.EnableAddOn(name)
        else
            C_AddOns.DisableAddOn(name)
        end
        return true
    end

    LunarModsDB.parts[name] = wanted and true or false

    if wanted then
        local ok, reason = LoadPart(name)
        if not ok then
            self:Print(name .. " could not be switched on: " .. reason)
        end
        return ok
    end

    local part = parts[name]
    if part and part.enabled then
        part.enabled = false
        part:UnregisterAllEvents()
        if part.OnDisable then SafeCall(part.OnDisable, part) end
    end
    return true
end

-- What the list shows for a mod:
--   "on"      loaded and running
--   "off"     not loaded
--   "stopped" switched off but still in memory until the next /reload
--   "pending" switched on, starts at the next /reload (addons only)
--   "error"   could not be loaded (second value: why)
function LunarMods:GetStatus(name)
    if problems[name] then return "error", problems[name] end
    local info = FindInfo(name)
    local loaded = C_AddOns.IsAddOnLoaded(name)
    if info and info.kind == "addon" then
        local wanted = GameEnabled(name)
        if loaded then return wanted and "on" or "stopped" end
        return wanted and "pending" or "off"
    end
    local part = parts[name]
    if part and part.enabled then return "on" end
    if loaded then return "stopped" end
    return "off"
end

-- Lets a mod add its own lines to a tooltip (X-LunarMods-Tooltip in its .toc)
function LunarMods:AddModTooltip(info, tooltip)
    local func = info.tooltip and _G[info.tooltip]
    if type(func) == "function" and C_AddOns.IsAddOnLoaded(info.name) then
        return SafeCall(func, tooltip)
    end
    return false
end

-- Runs a slash command such as "/qxp" as if it had been typed in chat
function LunarMods:RunSlash(command)
    command = strtrim(command or "")
    local slash, rest = strmatch(command, "^(%S+)%s*(.-)$")
    if not slash then return false end
    slash = strlower(slash)
    for key, handler in pairs(SlashCmdList) do
        local i = 1
        local alias = _G["SLASH_" .. key .. i]
        while alias do
            if strlower(alias) == slash then
                SafeCall(handler, rest or "")
                return true
            end
            i = i + 1
            alias = _G["SLASH_" .. key .. i]
        end
    end
    return false
end

-- ---------------------------------------------------------------- events

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == ADDON then
            -- The saved settings are available from here on
            LunarModsDB = LunarModsDB or {}
            LunarModsDB.parts = LunarModsDB.parts or {}     -- [folder name] = false when switched off
            LunarModsDB.data = LunarModsDB.data or {}       -- [folder name] = the part's own saved table
            LunarModsDB.minimap = LunarModsDB.minimap or {} -- { angle = degrees, hide = bool }
            LunarModsCharDB = LunarModsCharDB or {}
            LunarModsCharDB.data = LunarModsCharDB.data or {}
        end
    elseif event == "PLAYER_LOGIN" then
        loggedIn = true
        ScanMods()
        for _, info in ipairs(installed) do
            if info.kind == "part" and LunarMods:IsWanted(info.name) then
                LoadPart(info.name)
            end
        end
        if LunarMods.OnLogin then SafeCall(LunarMods.OnLogin, LunarMods) end
    end

    -- Pass the event on to every part that asked for it
    local list = handlers[event]
    if list then
        for part, handler in pairs(list) do
            if part.enabled then
                SafeCall(handler, part, event, ...)
            end
        end
    end
end)
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

-- ---------------------------------------------------------------- slash command

local function FindInstalled(text)
    text = strlower(text or "")
    for _, info in ipairs(installed) do
        if info.short == text or strlower(info.name) == text then
            return info
        end
    end
end

local STATUS_TEXT = {
    on = "|cff40ff40on|r",
    off = "|cff999999off|r",
    stopped = "|cffffd100off after /reload|r",
    pending = "|cffffd100on after /reload|r",
    error = "|cffff4040error|r",
}

local function PrintList()
    if #installed == 0 then
        LunarMods:Print("no mods installed.")
        return
    end
    LunarMods:Print("mods:")
    for _, info in ipairs(installed) do
        local status, why = LunarMods:GetStatus(info.name)
        print("   " .. info.short .. "  " .. STATUS_TEXT[status] .. (why and (": " .. why) or ""))
    end
end

SLASH_LUNARMODS1 = "/lm"
SLASH_LUNARMODS2 = "/lunarmods"
SlashCmdList["LUNARMODS"] = function(message)
    local command, rest = strmatch(strtrim(message or ""), "^(%S*)%s*(.-)$")
    command = strlower(command)

    if command == "" then
        LunarMods:ToggleWindow()
    elseif command == "list" then
        PrintList()
    elseif command == "minimap" then
        LunarMods:ToggleMinimapButton()
    elseif command == "on" or command == "off" then
        local info = FindInstalled(rest)
        if not info then
            LunarMods:Print("no mod called '" .. rest .. "'. Try /lm list")
            return
        end
        if LunarMods:SetWanted(info.name, command == "on") then
            local status = LunarMods:GetStatus(info.name)
            LunarMods:Print(info.title .. ": " .. STATUS_TEXT[status] .. ".")
        end
        LunarMods:RefreshWindow()
    elseif command == "help" then
        LunarMods:Print("version " .. LunarMods.version)
        print("   /lm  - open the list of mods")
        print("   /lm list  - show the mods in chat")
        print("   /lm on <mod>, /lm off <mod>  - switch a mod on or off")
        print("   /lm minimap  - show or hide the minimap button")
        print("   /lm <mod> ...  - a mod's own commands")
    else
        -- "/lm selljunk text" goes to a part's OnSlash, "/lm questxptracker group" to /qxp group
        local info = FindInstalled(command)
        local part = info and parts[info.name]
        if part and part.enabled and part.OnSlash then
            SafeCall(part.OnSlash, part, rest)
        elseif info and info.open and C_AddOns.IsAddOnLoaded(info.name) then
            LunarMods:RunSlash(info.open .. " " .. rest)
        elseif info then
            LunarMods:Print(info.title .. " is switched off or has no commands.")
        else
            LunarMods:Print("unknown command '" .. command .. "'. Try /lm help")
        end
    end
end

-- The entry in the game's addon button by the minimap
function LunarMods_OnAddonCompartmentClick()
    LunarMods:ToggleWindow()
end

-- Window.lua and Minimap.lua replace these; they exist here so the core works without them
function LunarMods:ToggleWindow() PrintList() end
function LunarMods:RefreshWindow() end
function LunarMods:ToggleMinimapButton() end

function LunarMods:IsLoggedIn()
    return loggedIn
end
