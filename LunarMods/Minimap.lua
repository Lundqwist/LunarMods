-- LunarMods: Minimap.lua
-- The round "LM" button on the edge of the minimap.
-- The minimap button for all of Lundqwist's mods that are linked to LunarMods
-- (unlinked mods have their own buttons).
-- Left-click: open the list of mods. Right-click: a menu to open any linked mod.
-- Hover: every mod's state, plus the lines a linked mod adds (Quest XP Tracker's XP summary).
-- Drag: move it around the minimap.
-- /lm minimap hides or shows it. Its place is saved in LunarModsDB.minimap.

local LunarMods = _G.LunarMods

local button = CreateFrame("Button", "LunarModsMinimapButton", Minimap)
button:SetSize(31, 31)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
button:Hide()

-- Newer clients draw the minimap border a little differently
local modern = AddonCompartmentFrame ~= nil
local background = button:CreateTexture(nil, "BACKGROUND")
background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
local icon = button:CreateTexture(nil, "ARTWORK")
icon:SetTexture(LunarMods.icon)
local border = button:CreateTexture(nil, "OVERLAY")
border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
border:SetPoint("TOPLEFT")
if modern then
    background:SetSize(24, 24); background:SetPoint("CENTER")
    icon:SetSize(22, 22);       icon:SetPoint("CENTER")
    border:SetSize(50, 50)
else
    background:SetSize(20, 20); background:SetPoint("TOPLEFT", 7, -5)
    icon:SetSize(21, 21);       icon:SetPoint("TOPLEFT", 5, -5)
    border:SetSize(53, 53)
end

local function Settings()
    return LunarModsDB and LunarModsDB.minimap or {}
end

local function Place()
    local angle = math.rad(Settings().angle or 225)
    local x, y = math.cos(angle), math.sin(angle)
    local w = (Minimap:GetWidth() / 2) + 5
    local h = (Minimap:GetHeight() / 2) + 5
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    button:ClearAllPoints()
    if shape == "SQUARE" then
        -- a square minimap (SexyMap and the like): run along the edge
        x = math.max(-w, math.min(x * w * 1.42, w))
        y = math.max(-h, math.min(y * h * 1.42, h))
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    else
        button:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
    end
end

local function DragUpdate()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    Settings().angle = math.deg(math.atan2(py - my, px - mx)) % 360
    Place()
end

button:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", DragUpdate)
    GameTooltip:Hide()
end)
button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

-- ---------------------------------------------------------------- right-click menu
-- One line per mod that has a window (X-LunarMods-Open), then "All mods...".

local menu = CreateFrame("Frame", "LunarModsMinimapMenu", UIParent, "BackdropTemplate")
menu:SetFrameStrata("DIALOG")
menu:SetClampedToScreen(true)
menu:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
menu:SetBackdropColor(0.03, 0.06, 0.14, 0.95)
menu:SetBackdropBorderColor(0.79, 0.64, 0.42)
menu:Hide()
tinsert(UISpecialFrames, "LunarModsMinimapMenu")

local MENU_ROW, MENU_WIDTH = 20, 180
local menuRows = {}

local function MenuRow(index)
    local row = menuRows[index]
    if row then return row end
    row = CreateFrame("Button", nil, menu)
    row:SetHeight(MENU_ROW)
    row:SetPoint("TOPLEFT", 6, -6 - (index - 1) * MENU_ROW)
    row:SetPoint("RIGHT", -6, 0)
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.15)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("LEFT", 6, 0)
    row.text:SetPoint("RIGHT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row:SetScript("OnClick", function(self)
        menu:Hide()
        self.action()
    end)
    menuRows[index] = row
    return row
end

local function ShowMenu()
    local entries = {}
    for _, info in ipairs(LunarMods:GetMods()) do
        if LunarMods:IsLinked(info.name) and LunarMods:CanOpen(info) then
            entries[#entries + 1] = { text = info.title, action = function() LunarMods:OpenMod(info) end }
        end
    end
    entries[#entries + 1] = { text = "|cff7fb2ffAll mods...|r", action = function() LunarMods:ToggleWindow() end }

    for index, entry in ipairs(entries) do
        local row = MenuRow(index)
        row.text:SetText(entry.text)
        row.action = entry.action
        row:Show()
    end
    for index = #entries + 1, #menuRows do menuRows[index]:Hide() end

    menu:SetSize(MENU_WIDTH, #entries * MENU_ROW + 12)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", button, "BOTTOMLEFT", 8, 8)
    menu:Show()
end

-- Closes the menu when you click anywhere else
-- (pcall: an older client without this event just keeps the menu until Esc or a choice)
menu:SetScript("OnShow", function(self)
    pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN")
end)
menu:SetScript("OnHide", function(self)
    pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN")
end)
menu:SetScript("OnEvent", function(self)
    if not self:IsMouseOver() and not button:IsMouseOver() then self:Hide() end
end)

-- ---------------------------------------------------------------- click and tooltip

button:SetScript("OnClick", function(_, mouse)
    GameTooltip:Hide()
    if mouse == "RightButton" then
        if menu:IsShown() then menu:Hide() else ShowMenu() end
    else
        menu:Hide()
        LunarMods:ToggleWindow()
    end
end)

button:SetScript("OnEnter", function(self)
    if menu:IsShown() then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("LunarMods")
    -- every mod: its name and state, plus its own lines when it is linked
    for _, info in ipairs(LunarMods:GetMods()) do
        local status = LunarMods:GetStatus(info.name)
        local linked = LunarMods:IsLinked(info.name)
        local state = status == "on" and "|cff40ff40on|r" or "|cff999999" .. status .. "|r"
        if status == "on" and not linked then state = "|cff999999own button|r  " .. state end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(info.title, state, 1, 0.82, 0)
        if status == "on" and linked then LunarMods:AddModTooltip(info, GameTooltip) end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click: switch mods on or off", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Right-click: open a mod", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
button:SetScript("OnLeave", function() GameTooltip:Hide() end)

function LunarMods:ToggleMinimapButton()
    local settings = Settings()
    settings.hide = not settings.hide
    button:SetShown(not settings.hide)
    self:Print("minimap button " .. (settings.hide and "hidden. /lm minimap brings it back." or "shown."))
end

-- Called by Core.lua at login, when the saved settings are there
function LunarMods:OnLogin()
    Place()
    button:SetShown(not Settings().hide)
end

-- The minimap can change size (SexyMap, zooming the UI); keep the button on its edge
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function()
    if LunarModsDB then Place() end
end)
