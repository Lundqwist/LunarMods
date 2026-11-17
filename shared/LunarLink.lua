-- LunarLink.lua (link version 1)
--
-- Shared by Lundqwist's mods. The same file is copied into each mod; the
-- original lives in the LunarMods repository (shared\LunarLink.lua) and
-- tools\sync-link.ps1 copies it out. Edit it there, not in a mod.
--
-- It gives a mod three things:
--   * its own minimap button (left-click: the mod's action, right-click: its
--     options, drag: move it around the minimap)
--   * an options page in the game's settings (Options -> AddOns)
--   * a "Link to LunarMods" button on that page. A linked mod hides its own
--     minimap button and is run from LunarMods instead: the LM button's menu
--     opens it, its tooltip shows the mod's summary, and the /lm list has an
--     Options button for it. Unlinking gives the mod its own button back.
--
-- Without LunarMods (not installed, or switched off) the mod simply works on
-- its own with its own minimap button, and the link button is greyed out.
--
-- In the mod's .toc file, before the mod's own Lua file:
--
--     ## OptionalDeps: LunarMods
--     LunarLink.lua
--
-- In the mod's Lua file:
--
--     local ADDON_NAME, ns = ...
--     local link = ns.NewLunarLink({
--         name    = ADDON_NAME,
--         title   = "My Mod",
--         icon    = "Interface\\AddOns\\MyMod\\Media\\Icon",
--         db      = function() return MyModSettings end,   -- saved table, account-wide
--         open    = function() ... end,                   -- left-click / "Open" in LunarMods
--         tooltip = function(tooltip) ... end,            -- extra tooltip lines (optional)
--         hint    = "Left-click: show or hide the window", -- (optional)
--         options = function(link) ... end,               -- extra settings (optional), see AddCheckbox etc.
--         help    = { "/mm - open the window" },          -- shown at the bottom of the options page (optional)
--     })
--     -- at PLAYER_LOGIN, when the saved variables are loaded:
--     link:Init()
--
-- The saved table gets two keys: minimap = { angle, hide } and lunarLinked.

local _, ns = ...

local LINK_VERSION = 1
local LM_COLOR = "|cff7fb2ff"

local Link = {}
Link.__index = Link

-- LunarMods, when it is loaded and new enough to know about links
local function LunarModsAPI()
    local lm = _G.LunarMods
    if type(lm) == "table" and type(lm.RegisterMod) == "function" then
        return lm
    end
end

function ns.NewLunarLink(spec)
    assert(type(spec) == "table" and spec.name and spec.db, "NewLunarLink needs name and db")
    return setmetatable({
        spec = spec,
        name = spec.name,
        title = spec.title or spec.name,
        refreshers = {},
    }, Link)
end

function Link:Settings()
    local db = self.spec.db()
    db.minimap = db.minimap or {}
    return db
end

-- Linked and LunarMods is there to do the job
function Link:IsLinked()
    return LunarModsAPI() ~= nil and self:Settings().lunarLinked == true
end

function Link:Print(text)
    print(LM_COLOR .. self.title .. "|r: " .. text)
end

function Link:SetLinked(on)
    local lm = LunarModsAPI()
    if on and not lm then
        self:Print("LunarMods isn't loaded, so there is nothing to link to.")
        return
    end
    self:Settings().lunarLinked = on and true or false
    self:UpdateButton()
    self:RefreshOptions()
    if lm and lm.RefreshWindow then lm:RefreshWindow() end
    if on then
        self:Print("linked to LunarMods. Open it from the LM minimap button; its own button is hidden.")
    else
        self:Print("unlinked from LunarMods. It has its own minimap button again.")
    end
end

function Link:Open()
    if self.spec.open then self.spec.open() end
end

-- ---------------------------------------------------------------- minimap button

function Link:PlaceButton()
    local button = self.button
    local angle = math.rad(self:Settings().minimap.angle or self.spec.angle or 200)
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

function Link:ShowButtonTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:AddLine(self.title)
    if self.spec.tooltip then
        local ok, err = pcall(self.spec.tooltip, GameTooltip)
        if not ok then geterrorhandler()(err) end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(self.spec.hint or "Left-click: open", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Right-click: options", 0.6, 0.6, 0.6)
    GameTooltip:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

function Link:CreateButton()
    local button = CreateFrame("Button", self.name .. "MinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight
    button:Hide()

    -- newer clients draw the minimap border a little differently
    local modern = AddonCompartmentFrame ~= nil
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(self.spec.icon or 134400)
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

    local link = self
    local function DragUpdate()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        link:Settings().minimap.angle = math.deg(math.atan2(py - my, px - mx)) % 360
        link:PlaceButton()
    end
    button:SetScript("OnDragStart", function(b)
        b:SetScript("OnUpdate", DragUpdate)
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStop", function(b)
        b:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnClick", function(b, mouse)
        GameTooltip:Hide()
        if mouse == "RightButton" then
            link:OpenOptions()
        else
            link:Open()
        end
        -- the tooltip may show new numbers after the click
        if b:IsMouseOver() then link:ShowButtonTooltip(b) end
    end)
    button:SetScript("OnEnter", function(b) link:ShowButtonTooltip(b) end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    self.button = button

    -- the minimap can change size (SexyMap, UI scale); keep the button on its edge
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:SetScript("OnEvent", function() link:UpdateButton() end)
end

function Link:UpdateButton()
    if not self.button then return end
    local show = not self:IsLinked() and not self:Settings().minimap.hide
    self.button:SetShown(show)
    if show then self:PlaceButton() end
end

function Link:SetButtonHidden(hide)
    self:Settings().minimap.hide = hide and true or false
    self:UpdateButton()
    self:RefreshOptions()
end

-- ---------------------------------------------------------------- options page
-- Widgets are stacked from the top; self.y is where the next one goes.

local LEFT, WIDTH = 16, 580

function Link:Place(widget, height, gap, indent)
    self.y = self.y - (gap or 8)
    widget:SetPoint("TOPLEFT", self.panel, "TOPLEFT", LEFT + (indent or 0), self.y)
    self.y = self.y - height
    return widget
end

function Link:OnRefresh(func)
    self.refreshers[#self.refreshers + 1] = func
end

-- A line of text; text can be a function, asked again each time the page is shown
function Link:AddText(text, font, r, g, b)
    local fs = self.panel:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetWidth(WIDTH)
    fs:SetJustifyH("LEFT")
    if r then fs:SetTextColor(r, g, b) end
    if type(text) == "function" then
        fs:SetHeight(28)        -- room for two lines of changing text
        self:OnRefresh(function() fs:SetText(text()) end)
        fs:SetJustifyV("TOP")
        self:Place(fs, 28, 4)
    else
        fs:SetText(text)
        self:Place(fs, fs:GetStringHeight(), 4)
    end
    return fs
end

function Link:AddHeader(text)
    local fs = self.panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    self:Place(fs, 14, 18)
    local line = self.panel:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetSize(WIDTH, 1)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    self.y = self.y - 4
    return fs
end

-- get() returns the current value, set(value) changes it; enabled() is optional
function Link:AddCheckbox(label, get, set, enabled)
    local cb = CreateFrame("CheckButton", nil, self.panel, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.label:SetText(label)
    cb:SetScript("OnClick", function(box)
        set(box:GetChecked() and true or false)
        self:RefreshOptions()
    end)
    self:OnRefresh(function()
        cb:SetChecked(get() and true or false)
        local on = not enabled or enabled()
        cb:SetEnabled(on)
        cb.label:SetAlpha(on and 1 or 0.5)
    end)
    self:Place(cb, 26, 4, -4)
    return cb
end

-- A button; give it the previous button as "after" to put it on the same line
function Link:AddButton(text, width, onClick, after)
    local b = CreateFrame("Button", nil, self.panel, "UIPanelButtonTemplate")
    b:SetSize(width or 160, 24)
    b:SetText(text)
    b:SetScript("OnClick", function() onClick(); self:RefreshOptions() end)
    if after then
        b:SetPoint("LEFT", after, "RIGHT", 8, 0)
    else
        self:Place(b, 24, 8)
    end
    return b
end

function Link:LinkStatusText()
    local lm = _G.LunarMods
    if not lm then
        return "|cff999999LunarMods isn't loaded.|r Install or switch on LunarMods to manage all of Lundqwist's mods from one list and one minimap button."
    elseif not LunarModsAPI() then
        return "|cffff8040This LunarMods is too old to link mods.|r Update LunarMods."
    elseif self:IsLinked() then
        return "|cff40ff40Linked.|r LunarMods' LM minimap button opens " .. self.title .. " and shows its summary, and /lm lists it with an Options button. Its own minimap button is hidden."
    end
    return "|cffffd100Not linked.|r " .. self.title .. " has its own minimap button. Link it to run it from LunarMods' LM button instead."
end

function Link:BuildOptions()
    local panel = CreateFrame("Frame")
    panel.name = self.title
    self.panel = panel
    self.y = -12

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetTexture(self.spec.icon or 134400)
    self:Place(icon, 32, 4)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    local version = C_AddOns.GetAddOnMetadata(self.name, "Version")
    title:SetText(self.title .. (version and ("  |cff999999v" .. version .. "|r") or ""))

    local notes = C_AddOns.GetAddOnMetadata(self.name, "Notes")
    if notes then self:AddText(notes, "GameFontHighlight") end

    self:AddHeader("Minimap button")
    self:AddCheckbox("Show the minimap button",
        function() return not self:Settings().minimap.hide end,
        function(on) self:SetButtonHidden(not on) end,
        function() return not self:IsLinked() end)
    self:AddText(function()
        if self:IsLinked() then return "Hidden while linked to LunarMods: use the LM button instead." end
        return "Left-click it to open " .. self.title .. ", right-click it for these options, drag it to move it."
    end, "GameFontDisableSmall")

    if self.spec.options then
        local ok, err = pcall(self.spec.options, self)
        if not ok then geterrorhandler()(err) end
    end

    self:AddHeader("LunarMods")
    self:AddText(function() return self:LinkStatusText() end, "GameFontHighlightSmall")
    local linkButton = self:AddButton("Link to LunarMods", 180, function()
        self:SetLinked(not self:IsLinked())
    end)
    local openLM = self:AddButton("Open LunarMods", 140, function()
        local lm = LunarModsAPI()
        if lm then
            if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
            lm:ToggleWindow()
        end
    end, linkButton)
    self:OnRefresh(function()
        local lm = LunarModsAPI()
        linkButton:SetText(self:IsLinked() and "Unlink from LunarMods" or "Link to LunarMods")
        linkButton:SetEnabled(lm ~= nil)
        openLM:SetEnabled(lm ~= nil)
    end)

    if self.spec.help then
        self:AddHeader("Commands")
        for _, line in ipairs(self.spec.help) do
            self:AddText(line, "GameFontHighlightSmall")
        end
    end

    panel:SetScript("OnShow", function() self:RefreshOptions() end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        self.category = Settings.RegisterCanvasLayoutCategory(panel, self.title)
        Settings.RegisterAddOnCategory(self.category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function Link:RefreshOptions()
    if not self.panel then return end
    for _, func in ipairs(self.refreshers) do
        local ok, err = pcall(func)
        if not ok then geterrorhandler()(err) end
    end
end

function Link:OpenOptions()
    if not self.panel then return end
    if Settings and Settings.OpenToCategory and self.category then
        Settings.OpenToCategory(self.category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- the old options window needs two calls the first time
        InterfaceOptionsFrame_OpenToCategory(self.panel)
        InterfaceOptionsFrame_OpenToCategory(self.panel)
    end
    self:RefreshOptions()
end

-- ---------------------------------------------------------------- start

function Link:Init()
    if self.ready then return end
    self.ready = true
    self:Settings()
    self:CreateButton()
    self:BuildOptions()
    self:UpdateButton()

    local lm = LunarModsAPI()
    if lm then
        lm:RegisterMod(self.name, {
            version = LINK_VERSION,
            IsLinked = function() return self:Settings().lunarLinked == true end,
            SetLinked = function(on) self:SetLinked(on) end,
            OpenOptions = function() self:OpenOptions() end,
            Open = self.spec.open and function() self:Open() end or nil,
            Tooltip = self.spec.tooltip,
        })
    end
end
