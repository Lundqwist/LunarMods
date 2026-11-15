-- LunarMods: Window.lua
-- The window opened with /lm or the minimap button: one row per mod, with a
-- tick box that switches it on or off, and an Open button for mods that have
-- a window of their own.

local LunarMods = _G.LunarMods

local ROW_HEIGHT = 46
local WIDTH, HEIGHT = 460, 400

local window      -- created the first time it is opened
local rows = {}

local STATUS = {
    on = { "On", 0.25, 1, 0.25 },
    off = { "Off", 0.6, 0.6, 0.6 },
    stopped = { "Off after /reload", 1, 0.82, 0 },
    pending = { "On after /reload", 1, 0.82, 0 },
    error = { "Error", 1, 0.25, 0.25 },
}

local KIND = {
    addon = "|cff7fb2ffAddon|r",
    part = "|cffc9a36bPart|r",
}

local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.03 or 0)

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(26, 26)
    row.check:SetPoint("LEFT", 2, 0)
    row.check:SetScript("OnClick", function(self)
        LunarMods:SetWanted(row.name, self:GetChecked() and true or false)
        LunarMods:RefreshWindow()
    end)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("TOPRIGHT", -6, -7)
    row.status:SetJustifyH("RIGHT")

    row.open = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.open:SetSize(56, 18)
    row.open:SetPoint("BOTTOMRIGHT", -4, 5)
    row.open:SetText("Open")
    row.open:SetNormalFontObject("GameFontNormalSmall")
    row.open:SetHighlightFontObject("GameFontHighlightSmall")
    row.open:SetDisabledFontObject("GameFontDisableSmall")
    row.open:SetScript("OnClick", function()
        if row.openCommand then LunarMods:RunSlash(row.openCommand) end
    end)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", row.check, "TOPRIGHT", 4, 4)
    row.title:SetPoint("RIGHT", row.status, "LEFT", -8, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)

    row.notes = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.notes:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
    row.notes:SetPoint("RIGHT", row.open, "LEFT", -8, 0)
    row.notes:SetJustifyH("LEFT")
    row.notes:SetWordWrap(false)

    -- The whole text of the notes, and why loading failed, on mouse-over
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.titleText)
        if self.notesText ~= "" then
            GameTooltip:AddLine(self.notesText, 1, 1, 1, true)
        end
        if self.why then
            GameTooltip:AddLine(self.why, 1, 0.25, 0.25, true)
        end
        if self.kind == "addon" then
            GameTooltip:AddLine("A separate addon: switching it on or off takes effect after a reload.", 0.6, 0.6, 0.6, true)
        else
            GameTooltip:AddLine("A LunarMods part: ticking it starts it right away.", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:AddLine("/lm on " .. self.short .. "   /lm off " .. self.short, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return row
end

local function CreateWindow()
    window = CreateFrame("Frame", "LunarModsWindow", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    window:SetBackdropColor(0.03, 0.06, 0.14, 0.95)
    window:SetBackdropBorderColor(0.79, 0.64, 0.42)

    -- Drag it anywhere; Esc closes it
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    tinsert(UISpecialFrames, "LunarModsWindow")

    local icon = window:CreateTexture(nil, "OVERLAY")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", 12, -10)
    icon:SetTexture(LunarMods.icon)

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    title:SetText("LunarMods")

    local version = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
    version:SetText("v" .. LunarMods.version)

    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 16, -44)
    hint:SetPoint("RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Tick the mods you want. Unticked mods are not loaded.")

    -- The list scrolls when there are more mods than fit
    local scroll = CreateFrame("ScrollFrame", "LunarModsWindowScroll", window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -64)
    scroll:SetPoint("BOTTOMRIGHT", -32, 48)

    window.list = CreateFrame("Frame", nil, scroll)
    window.list:SetSize(WIDTH - 44, 1)
    scroll:SetScrollChild(window.list)

    window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    window.empty:SetPoint("CENTER", scroll)
    window.empty:SetText("No mods found.")

    local reload = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    reload:SetSize(110, 24)
    reload:SetPoint("BOTTOMRIGHT", -14, 14)
    reload:SetText("Reload UI")
    reload:SetScript("OnClick", ReloadUI)
    window.reload = reload

    window.footer = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.footer:SetPoint("BOTTOMLEFT", 16, 20)
    window.footer:SetPoint("RIGHT", reload, "LEFT", -10, 0)
    window.footer:SetJustifyH("LEFT")

    window:SetScript("OnShow", function() LunarMods:RefreshWindow() end)
    window:Hide()
end

function LunarMods:RefreshWindow()
    if not window or not window:IsShown() then return end

    local list = self:GetMods()
    local needsReload = false

    for index, info in ipairs(list) do
        local row = rows[index] or CreateRow(window.list, index)
        rows[index] = row

        local status, why = self:GetStatus(info.name)
        local label = STATUS[status]

        row.name, row.short, row.kind = info.name, info.short, info.kind
        row.titleText, row.notesText, row.why = info.title, info.notes, why
        row.title:SetText(info.title .. "  " .. KIND[info.kind])
        row.notes:SetText(info.notes)
        row.status:SetText(label[1])
        row.status:SetTextColor(label[2], label[3], label[4])
        row.check:SetChecked(self:IsWanted(info.name))

        row.openCommand = info.open
        row.open:SetShown(info.open ~= nil)
        row.open:SetEnabled(info.open ~= nil and C_AddOns.IsAddOnLoaded(info.name))
        row:Show()

        if status == "stopped" or status == "pending" then needsReload = true end
    end
    for index = #list + 1, #rows do
        rows[index]:Hide()
    end

    window.list:SetHeight(math.max(1, #list * ROW_HEIGHT))
    window.empty:SetShown(#list == 0)
    window.footer:SetText(needsReload and "Reload the UI to finish switching mods on or off." or "")
end

function LunarMods:ToggleWindow()
    if not window then CreateWindow() end
    window:SetShown(not window:IsShown())
end
