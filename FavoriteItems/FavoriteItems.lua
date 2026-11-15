-- FavoriteItems
-- Mark specific items as favorites (a small heart in the icon's upper left
-- corner) and get a warning when a favorite item is sold to a merchant.
--
-- Favorites are individual items, not item types: each one is stored by its
-- item GUID, so marking one Linen Cloth or one copy of a sword leaves the
-- others alone.
--
-- Works with Baganator (uses its corner-widget and region API) and falls back
-- to the default Blizzard bag and bank frames when Baganator isn't loaded.

local ADDON_NAME = ...

local HEART = "Interface\\AddOns\\FavoriteItems\\Media\\Heart"
local HEART_INLINE = "|T" .. HEART .. ":14:14|t"
local COLOR = "|cffff6fa8"

local db
local markMode = false
local merchantOpen = false

local useBaganator = Baganator ~= nil and Baganator.API ~= nil

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(COLOR .. "FavoriteItems|r: " .. msg)
end

local function ItemIDFromLink(link)
  if type(link) ~= "string" then
    return nil
  end
  local id = link:match("item:(%d+)")
  return id and tonumber(id)
end

local function GUIDAt(bag, slot)
  if not (ItemLocation and C_Item and C_Item.GetItemGUID) then
    return nil
  end
  local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
  if location and C_Item.DoesItemExist(location) then
    return C_Item.GetItemGUID(location)
  end
end

-- itemID, link, guid of whatever sits in a bag slot
local function GetBagSlotItem(bag, slot)
  local itemID, link
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then
      itemID, link = info.itemID, info.hyperlink
    end
  elseif GetContainerItemLink then
    link = GetContainerItemLink(bag, slot)
    itemID = ItemIDFromLink(link)
  end
  if itemID then
    return itemID, link, GUIDAt(bag, slot)
  end
end

local function NumBagSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then
    return C_Container.GetContainerNumSlots(bag)
  end
  return GetContainerNumSlots and GetContainerNumSlots(bag) or 0
end

-- All items in the character's carried bags: list of {guid, id, link}
local function ScanBags()
  local list = {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, NumBagSlots(bag) do
      local itemID, link, guid = GetBagSlotItem(bag, slot)
      if guid then
        table.insert(list, { guid = guid, id = itemID, link = link })
      end
    end
  end
  return list
end

-------------------------------------------------------------------------------
-- Favorites storage (FavoriteItemsDB.guids[guid] = { id = itemID, link = link })
-------------------------------------------------------------------------------

local function IsFavorite(guid)
  return guid ~= nil and db ~= nil and db.guids[guid] ~= nil
end

local RefreshAllHearts -- defined further down

local function SetFavorite(guid, itemID, link, on)
  if not guid or not db then
    return
  end
  if on then
    db.guids[guid] = { id = itemID, link = link }
  else
    db.guids[guid] = nil
  end
  RefreshAllHearts()
end

local function ToggleFavorite(guid, itemID, link)
  if not itemID then
    return
  end
  if not guid then
    Print("Only items this character is carrying (or has in the open bank) can be marked.")
    return
  end
  local on = not IsFavorite(guid)
  SetFavorite(guid, itemID, link, on)
  local name = link or ("item " .. itemID)
  if on then
    Print(HEART_INLINE .. " " .. name .. " is now a favorite.")
  else
    Print(name .. " is no longer a favorite.")
  end
end

-- Small public API for other addons / macros.
FavoriteItems = {
  IsFavorite = IsFavorite,
}

-------------------------------------------------------------------------------
-- Finding bag windows and item buttons
-------------------------------------------------------------------------------

local baganatorViews = {}   -- list of top-level Baganator bag/bank frames
local knownViews = {}

local OnContainerHidden -- defined further down
local CreateBankToggle  -- defined further down

local function FindBaganatorViews()
  if not useBaganator then
    return
  end
  for name, obj in pairs(_G) do
    if type(name) == "string" and type(obj) == "table" and not knownViews[obj]
      and name:find("^Baganator_") and (name:find("BackpackViewFrame") or name:find("BankViewFrame"))
      and obj.GetObjectType and obj.GetParent and obj:GetParent() == UIParent then
      knownViews[obj] = true
      local isBank = name:find("BankViewFrame") ~= nil
      table.insert(baganatorViews, obj)
      obj:HookScript("OnHide", OnContainerHidden)
      if isBank then
        CreateBankToggle(obj)
      end
    end
  end
end

-- Default bag and bank frames. On Forever the modern ones (the combined
-- backpack, ContainerFrameContainer's frames) can be created late, so this is
-- asked again each time.
local function BlizzardContainers()
  local list, seen = {}, {}
  local function add(f)
    if f and not seen[f] then
      seen[f] = true
      table.insert(list, f)
    end
  end
  add(ContainerFrameCombinedBags)
  if ContainerFrameContainer and ContainerFrameContainer.ContainerFrames then
    for _, f in ipairs(ContainerFrameContainer.ContainerFrames) do
      add(f)
    end
  end
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    add(_G["ContainerFrame" .. i])
  end
  add(BankFrame)
  return list
end

-- Bag and slot for a default Blizzard item button, or nil if it isn't one.
local function BlizzardBagSlot(button)
  local name = button.GetName and button:GetName()
  if name and name:match("^BankFrameItem%d+$") then
    return BANK_CONTAINER or -1, button:GetID()
  end
  if button.GetBagID and button.GetID then
    local ok, bag = pcall(button.GetBagID, button)
    if ok and bag then
      return bag, button:GetID()
    end
  end
  if name and name:match("^ContainerFrame%d+Item%d+$") then
    return button:GetParent():GetID(), button:GetID()
  end
end

-- itemID, link, guid for an item button (guid is nil for other characters'
-- items shown from Baganator's cache)
local function GetButtonItem(button)
  local info = button.BGR
  if info then
    if not info.itemID then
      return nil
    end
    local guid = info.guid
    if not guid and info.itemLocation and C_Item.DoesItemExist(info.itemLocation) then
      guid = C_Item.GetItemGUID(info.itemLocation)
    end
    return info.itemID, info.itemLink, guid
  end
  local bag, slot = BlizzardBagSlot(button)
  if bag and slot then
    return GetBagSlotItem(bag, slot)
  end
end

local function CollectBaganatorButtons(frame, out)
  for _, child in ipairs({ frame:GetChildren() }) do
    if child:IsVisible() then
      if child.BGR ~= nil then
        table.insert(out, child)
      else
        CollectBaganatorButtons(child, out)
      end
    end
  end
end

local function CollectBlizzardButtons(frame, out)
  -- Modern bag frames list their own item buttons. The combined backpack
  -- returns (index, button); other frames may return just the button.
  if frame.EnumerateValidItems then
    local ok = pcall(function()
      for first, second in frame:EnumerateValidItems() do
        local button = second or first
        if type(button) == "table" and button.IsVisible and button:IsVisible() then
          table.insert(out, button)
        end
      end
    end)
    if ok then
      return
    end
  end
  for _, child in ipairs({ frame:GetChildren() }) do
    if child:IsVisible() then
      local objectType = child:GetObjectType()
      if (objectType == "Button" or objectType == "ItemButton") and BlizzardBagSlot(child) then
        table.insert(out, child)
      else
        CollectBlizzardButtons(child, out)
      end
    end
  end
end

local function VisibleContainers()
  local list = {}
  if useBaganator then
    for _, view in ipairs(baganatorViews) do
      if view:IsVisible() then
        table.insert(list, view)
      end
    end
  else
    for _, f in ipairs(BlizzardContainers()) do
      if f:IsVisible() then
        table.insert(list, f)
      end
    end
  end
  return list
end

local function CollectItemButtons()
  local buttons = {}
  for _, container in ipairs(VisibleContainers()) do
    if useBaganator then
      CollectBaganatorButtons(container, buttons)
    else
      CollectBlizzardButtons(container, buttons)
    end
  end
  return buttons
end

-------------------------------------------------------------------------------
-- Hearts
-------------------------------------------------------------------------------

-- Default Blizzard bags: our own heart texture on each item button.
local function UpdateBlizzardHearts()
  if useBaganator then
    return
  end
  for _, button in ipairs(CollectItemButtons()) do
    local _, _, guid = GetButtonItem(button)
    local fav = IsFavorite(guid)
    if fav and not button.FavoriteItemsHeart then
      local holder = CreateFrame("Frame", nil, button)
      holder:SetAllPoints(button)
      holder:SetFrameLevel(button:GetFrameLevel() + 5)
      local tex = holder:CreateTexture(nil, "OVERLAY")
      tex:SetTexture(HEART)
      tex:SetSize(14, 14)
      tex:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
      button.FavoriteItemsHeart = holder
    end
    if button.FavoriteItemsHeart then
      -- Pooled buttons can change frame level; keep the heart above them.
      button.FavoriteItemsHeart:SetFrameLevel(button:GetFrameLevel() + 5)
      button.FavoriteItemsHeart:SetShown(fav)
    end
  end
end

local heartsQueued = false
function RefreshAllHearts()
  if useBaganator then
    Baganator.API.RequestItemButtonsRefresh()
  elseif not heartsQueued then
    heartsQueued = true
    -- A short delay: the default bags fill in their buttons after OnShow.
    C_Timer.After(0.02, function()
      heartsQueued = false
      UpdateBlizzardHearts()
    end)
  end
end

-- Default bags: redraw the hearts whenever a bag frame shows or updates.
-- Forever doesn't always run UpdateItems after a bag opens, so OnShow and the
-- bag-open functions are hooked too, with a second, later redraw.
local hookedFrames = {}
local hookedFunctions = {}

local function RefreshSoonAndLater()
  RefreshAllHearts()
  C_Timer.After(0.25, RefreshAllHearts)
end

local function InstallBlizzardHooks()
  for _, f in ipairs(BlizzardContainers()) do
    if not hookedFrames[f] then
      hookedFrames[f] = true
      f:HookScript("OnShow", RefreshSoonAndLater)
      f:HookScript("OnHide", OnContainerHidden)
      if type(f.UpdateItems) == "function" then
        hooksecurefunc(f, "UpdateItems", RefreshAllHearts)
      end
    end
  end
  for _, name in ipairs({ "ContainerFrame_Update", "OpenAllBags", "ToggleAllBags", "OpenBackpack", "ToggleBackpack", "OpenBag", "ToggleBag" }) do
    if not hookedFunctions[name] and type(_G[name]) == "function" then
      hookedFunctions[name] = true
      hooksecurefunc(name, function()
        C_Timer.After(0, function()
          InstallBlizzardHooks() -- frames created on first open
          RefreshSoonAndLater()
        end)
      end)
    end
  end
end

if useBaganator then
  Baganator.API.RegisterCornerWidget(
    "Favorite (heart)",
    "favoriteitems_heart",
    function(corner, details)
      -- Must return true/false; nil would mean "data not ready yet".
      if not details or not details.itemID then
        return false
      end
      local guid = details.guid
      if not guid and details.itemLocation and C_Item.DoesItemExist(details.itemLocation) then
        guid = C_Item.GetItemGUID(details.itemLocation)
      end
      return IsFavorite(guid)
    end,
    function(itemButton)
      local frame = CreateFrame("Frame", nil, itemButton)
      frame:SetSize(14, 14)
      local tex = frame:CreateTexture(nil, "OVERLAY")
      tex:SetAllPoints()
      tex:SetTexture(HEART)
      frame.padding = 0
      return frame
    end,
    { corner = "top_left", priority = 1 },
    true
  )
end

-------------------------------------------------------------------------------
-- Mark mode: clickable layers on top of the item buttons
-------------------------------------------------------------------------------

local catchers = {}      -- item button -> catcher
local toggles = {}       -- all "Favorites" buttons
local ticker

local function ShowCatcherTooltip(catcher)
  local _, link, guid = GetButtonItem(catcher.itemButton)
  if not link then
    return
  end
  GameTooltip:SetOwner(catcher, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink(link)
  GameTooltip:AddLine(" ")
  if not guid then
    GameTooltip:AddLine("Can't be marked from here", 0.6, 0.6, 0.6)
  elseif IsFavorite(guid) then
    GameTooltip:AddLine(HEART_INLINE .. " Click to remove from favorites", 1, 0.44, 0.66)
  else
    GameTooltip:AddLine(HEART_INLINE .. " Click to mark this item as favorite", 1, 0.44, 0.66)
  end
  GameTooltip:Show()
end

local function GetCatcher(button)
  local catcher = catchers[button]
  if catcher then
    return catcher
  end
  catcher = CreateFrame("Button", nil, button)
  catcher.itemButton = button
  catcher:SetAllPoints(button)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local tint = catcher:CreateTexture(nil, "ARTWORK")
  tint:SetAllPoints()
  tint:SetColorTexture(1, 0.4, 0.7, 0.12)

  catcher:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

  catcher:SetScript("OnClick", function(self)
    local itemID, link, guid = GetButtonItem(self.itemButton)
    if itemID then
      ToggleFavorite(guid, itemID, link)
      if GameTooltip:IsOwned(self) then
        ShowCatcherTooltip(self)
      end
    end
  end)
  catcher:SetScript("OnEnter", ShowCatcherTooltip)
  catcher:SetScript("OnLeave", function() GameTooltip:Hide() end)

  catchers[button] = catcher
  return catcher
end

local function RefreshCatchers()
  local active = {}
  for _, button in ipairs(CollectItemButtons()) do
    local catcher = GetCatcher(button)
    catcher:SetFrameLevel(button:GetFrameLevel() + 20)
    catcher:Show()
    active[button] = true
  end
  for button, catcher in pairs(catchers) do
    if not active[button] then
      catcher:Hide()
    end
  end
end

local function UpdateToggles()
  for _, b in ipairs(toggles) do
    if markMode then
      b:SetText("|cff7fff7fDone|r")
      b:LockHighlight()
    else
      b:SetText(HEART_INLINE .. " Favorites")
      b:UnlockHighlight()
    end
  end
end

local function ExitMarkMode()
  if not markMode then
    return
  end
  markMode = false
  if ticker then
    ticker:Cancel()
    ticker = nil
  end
  for _, catcher in pairs(catchers) do
    catcher:Hide()
  end
  GameTooltip:Hide()
  UpdateToggles()
end

local function EnterMarkMode()
  if markMode then
    return
  end
  if InCombatLockdown() then
    Print("Can't mark favorites in combat.")
    return
  end
  FindBaganatorViews()
  if #VisibleContainers() == 0 then
    Print("Open your bags or bank first.")
    return
  end
  markMode = true
  RefreshCatchers()
  -- Bag contents and layouts change while open (looting, sorting, tabs), so
  -- keep the click layers in sync.
  ticker = C_Timer.NewTicker(0.25, function()
    if #VisibleContainers() == 0 then
      ExitMarkMode()
    else
      RefreshCatchers()
    end
  end)
  UpdateToggles()
  Print("Click items to mark or unmark them as favorites. Click " .. COLOR .. "Done|r when finished.")
end

local function ToggleMarkMode()
  if markMode then
    ExitMarkMode()
  else
    EnterMarkMode()
  end
end

function OnContainerHidden()
  C_Timer.After(0, function()
    if markMode and #VisibleContainers() == 0 then
      ExitMarkMode()
    end
  end)
end

-------------------------------------------------------------------------------
-- The "Favorites" buttons on the windows' lower side
-------------------------------------------------------------------------------

local function MakeToggle(parent)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(96, 22)
  b:SetScript("OnClick", ToggleMarkMode)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Favorite items")
    GameTooltip:AddLine("Click, then click items to mark or unmark them as favorites.", 1, 1, 1, true)
    GameTooltip:AddLine("You'll be warned if you sell a favorite.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  table.insert(toggles, b)
  UpdateToggles()
  return b
end

function CreateBankToggle(view)
  local b = MakeToggle(view)
  b:SetPoint("TOPLEFT", view, "BOTTOMLEFT", 4, -2)
end

if useBaganator then
  -- Baganator places registered regions in the backpack's bottom button row.
  Baganator.API.RegisterRegion("FavoriteItems", "favoriteitems", "backpack", "bottom_left", MakeToggle(UIParent))
end

local function CreateBlizzardToggles()
  if ContainerFrameCombinedBags then
    local b = MakeToggle(ContainerFrameCombinedBags)
    b:SetPoint("TOPRIGHT", ContainerFrameCombinedBags, "BOTTOMRIGHT", -4, -2)
  end
  if ContainerFrame1 then
    local b = MakeToggle(ContainerFrame1)
    b:SetPoint("TOPRIGHT", ContainerFrame1, "BOTTOMRIGHT", -4, -2)
  end
  if BankFrame then
    local b = MakeToggle(BankFrame)
    b:SetPoint("TOPLEFT", BankFrame, "BOTTOMLEFT", 4, -2)
  end
end

-------------------------------------------------------------------------------
-- Sold-favorite warning
-------------------------------------------------------------------------------

local pendingSold = {}   -- warnings in the popup: list of { id, link, count }
local warning

local function FindBuybackIndex(itemID)
  for i = GetNumBuybackItems(), 1, -1 do
    if ItemIDFromLink(GetBuybackItemLink(i)) == itemID then
      return i
    end
  end
end

local buybackQueue = {}
local function BuybackNext()
  if not merchantOpen then
    wipe(buybackQueue)
    return
  end
  local itemID = table.remove(buybackQueue, 1)
  if not itemID then
    return
  end
  local index = FindBuybackIndex(itemID)
  if index then
    BuybackItem(index)
  end
  -- One at a time: the buyback list shifts after each purchase.
  if #buybackQueue > 0 then
    C_Timer.After(0.5, BuybackNext)
  end
end

local function CreateWarning()
  local f = CreateFrame("Frame", "FavoriteItemsSoldWarning", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  f:SetSize(380, 160)
  f:SetPoint("TOP", UIParent, "TOP", 0, -150)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
  end

  f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  f.title:SetPoint("TOP", 0, -20)
  f.title:SetText(HEART_INLINE .. "  You sold a favorite item!  " .. HEART_INLINE)

  f.body = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  f.body:SetPoint("TOP", f.title, "BOTTOM", 0, -12)
  f.body:SetWidth(330)
  f.body:SetJustifyH("CENTER")

  f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  f.hint:SetPoint("TOP", f.body, "BOTTOM", 0, -8)
  f.hint:SetWidth(330)

  f.buyback = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.buyback:SetSize(120, 24)
  f.buyback:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -6, 18)
  f.buyback:SetText("Buy back")
  f.buyback:SetScript("OnClick", function()
    wipe(buybackQueue)
    for _, entry in ipairs(pendingSold) do
      for _ = 1, entry.count do
        table.insert(buybackQueue, entry.id)
      end
    end
    BuybackNext()
    f:Hide()
  end)

  f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.ok:SetSize(120, 24)
  f.ok:SetPoint("BOTTOMLEFT", f, "BOTTOM", 6, 18)
  f.ok:SetText("Keep it sold")
  f.ok:SetScript("OnClick", function() f:Hide() end)

  f:SetScript("OnHide", function() wipe(pendingSold) end)
  table.insert(UISpecialFrames, "FavoriteItemsSoldWarning")
  f:Hide()
  return f
end

local function UpdateWarning()
  warning = warning or CreateWarning()
  local lines = {}
  for _, entry in ipairs(pendingSold) do
    local name = entry.link or ("item " .. entry.id)
    if entry.count > 1 then
      name = name .. " x" .. entry.count
    end
    table.insert(lines, name)
  end
  warning.body:SetText(table.concat(lines, "\n"))
  if merchantOpen then
    warning.buyback:Enable()
    warning.hint:SetText("You can still buy it back from this merchant's Buyback tab.")
  else
    warning.buyback:Disable()
    warning.hint:SetText("The merchant window is closed, so it can't be bought back here.")
  end
  warning:SetHeight(110 + warning.body:GetStringHeight() + warning.hint:GetStringHeight())
  warning:Show()
end

local function WarnSold(itemID, link)
  local name = link or ("item " .. itemID)
  Print("|cffff4040Warning:|r you sold your favorite item " .. name .. "!")
  if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] then
    RaidNotice_AddMessage(RaidWarningFrame, HEART_INLINE .. " Favorite item sold: " .. name, ChatTypeInfo["RAID_WARNING"])
  end
  PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")

  for _, entry in ipairs(pendingSold) do
    if entry.id == itemID then
      entry.count = entry.count + 1
      UpdateWarning()
      return
    end
  end
  table.insert(pendingSold, { id = itemID, link = link, count = 1 })
  UpdateWarning()
end

-- Selling is detected while a merchant is open by combining two things:
--  * a favorite item (by GUID) disappears from the bags, and
--  * an item with the same item ID shows up in the merchant's buyback list.
-- Every way of selling (right click, dragging to the merchant, Baganator's
-- junk seller) ends up like that. The two can arrive in either order, so
-- both are kept until they can be matched.
local sale = nil  -- state for the current merchant visit

local function BuybackCounts()
  local counts = {}
  for i = 1, GetNumBuybackItems() do
    local id = ItemIDFromLink(GetBuybackItemLink(i))
    if id then
      counts[id] = (counts[id] or 0) + 1
    end
  end
  return counts
end

local function StartSaleTracking()
  sale = {
    buyback = BuybackCounts(),
    bagGUIDs = {},     -- guid -> itemID, everything in the bags last time
    missing = {},      -- favorite guid -> info, gone from bags, not matched yet
    increases = {},    -- itemID -> new buyback entries not matched yet
    sold = {},         -- itemID -> list of favorite infos sold this visit
  }
  for _, item in ipairs(ScanBags()) do
    sale.bagGUIDs[item.guid] = item.id
  end
end

local function CheckSales()
  if not merchantOpen or not sale or not db then
    return
  end

  -- Buyback list changes
  local counts = BuybackCounts()
  local decreased = {}
  for id, count in pairs(counts) do
    local before = sale.buyback[id] or 0
    if count > before then
      sale.increases[id] = (sale.increases[id] or 0) + (count - before)
    end
  end
  for id, before in pairs(sale.buyback) do
    local now = counts[id] or 0
    if now < before then
      decreased[id] = before - now
    end
  end
  sale.buyback = counts

  -- Bag changes
  local bagGUIDs, newItems = {}, {}
  for _, item in ipairs(ScanBags()) do
    bagGUIDs[item.guid] = item.id
    if not sale.bagGUIDs[item.guid] then
      table.insert(newItems, item)
    end
  end
  for guid in pairs(sale.bagGUIDs) do
    if not bagGUIDs[guid] and db.guids[guid] then
      sale.missing[guid] = db.guids[guid]
    end
  end
  sale.bagGUIDs = bagGUIDs

  -- Equipping a favorite at the merchant isn't selling it.
  if next(sale.missing) then
    for slot = 1, 19 do
      local location = ItemLocation:CreateFromEquipmentSlot(slot)
      if C_Item.DoesItemExist(location) then
        local guid = C_Item.GetItemGUID(location)
        if guid then
          sale.missing[guid] = nil
        end
      end
    end
  end

  -- A favorite that left the bags + the same item in the buyback list = sold
  for guid, info in pairs(sale.missing) do
    local id = info.id
    if (sale.increases[id] or 0) > 0 then
      sale.increases[id] = sale.increases[id] - 1
      sale.missing[guid] = nil
      db.guids[guid] = nil
      sale.sold[id] = sale.sold[id] or {}
      table.insert(sale.sold[id], info)
      WarnSold(id, info.link)
    end
  end

  -- A sold favorite bought back (with the button or the Buyback tab): the
  -- returning item may get a new GUID, so mark it as a favorite again.
  for _, item in ipairs(newItems) do
    local soldList = sale.sold[item.id]
    if soldList and #soldList > 0 and (decreased[item.id] or 0) > 0 then
      decreased[item.id] = decreased[item.id] - 1
      local info = table.remove(soldList)
      db.guids[item.guid] = { id = item.id, link = item.link or info.link }
      RefreshAllHearts()
    end
  end
end

-------------------------------------------------------------------------------
-- Tooltip line
-------------------------------------------------------------------------------

local function HookTooltips()
  if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then
    return
  end
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
    if tooltip == GameTooltip and data and IsFavorite(data.guid) then
      tooltip:AddLine(HEART_INLINE .. " Favorite", 1, 0.44, 0.66)
    end
  end)
end

-------------------------------------------------------------------------------
-- Upgrade from 1.0.0, which stored favorites per item ID: mark the matching
-- items currently in the bags, then drop the old list.
-------------------------------------------------------------------------------

local function MigrateItemIDFavorites()
  if not db.items then
    return
  end
  for _, item in ipairs(ScanBags()) do
    if db.items[item.id] then
      db.guids[item.guid] = { id = item.id, link = item.link }
    end
  end
  db.items = nil
  RefreshAllHearts()
end

-------------------------------------------------------------------------------
-- Slash command
-------------------------------------------------------------------------------

SLASH_FAVORITEITEMS1 = "/fav"
SLASH_FAVORITEITEMS2 = "/favorites"
SlashCmdList.FAVORITEITEMS = function(msg)
  msg = strtrim((msg or ""):lower())
  if msg == "list" then
    local n = 0
    for guid, info in pairs(db.guids) do
      n = n + 1
      Print(HEART_INLINE .. " " .. (info.link or ("item " .. tostring(info.id))))
    end
    if n == 0 then
      Print("No favorites yet.")
    end
  elseif msg == "debug" then
    local favorites = 0
    for _ in pairs(db.guids) do
      favorites = favorites + 1
    end
    local buttons, withItem, withGUID, hearts = 0, 0, 0, 0
    for _, button in ipairs(CollectItemButtons()) do
      buttons = buttons + 1
      local itemID, _, guid = GetButtonItem(button)
      if itemID then withItem = withItem + 1 end
      if guid then withGUID = withGUID + 1 end
      if IsFavorite(guid) then hearts = hearts + 1 end
    end
    Print(("Mode: %s. Open windows: %d. Item buttons: %d (%d with an item, %d with a GUID). Favorites saved: %d, shown here: %d.")
      :format(useBaganator and "Baganator" or "default bags", #VisibleContainers(), buttons, withItem, withGUID, favorites, hearts))
  elseif msg == "help" then
    Print("/fav - start or stop marking favorites (opens your bags)")
    Print("/fav list - list all favorites")
    Print("/fav debug - what the addon finds in the open bag windows")
  else
    if markMode then
      ExitMarkMode()
    else
      if #VisibleContainers() == 0 then
        OpenAllBags()
        C_Timer.After(0.1, EnterMarkMode)
      else
        EnterMarkMode()
      end
    end
  end
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_CLOSED")
events:RegisterEvent("MERCHANT_UPDATE")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("PLAYERBANKSLOTS_CHANGED")

events:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    FavoriteItemsDB = FavoriteItemsDB or {}
    FavoriteItemsDB.guids = FavoriteItemsDB.guids or {}
    db = FavoriteItemsDB
  elseif event == "PLAYER_LOGIN" then
    HookTooltips()
    -- Bag contents aren't always ready right at login.
    C_Timer.After(3, MigrateItemIDFavorites)
    if useBaganator then
      FindBaganatorViews()
      -- Baganator may build some views late; look again shortly after login.
      C_Timer.After(2, FindBaganatorViews)
    else
      CreateBlizzardToggles()
      InstallBlizzardHooks()
    end
  elseif event == "PLAYER_REGEN_DISABLED" then
    ExitMarkMode()
  elseif event == "MERCHANT_SHOW" then
    merchantOpen = true
    StartSaleTracking()
  elseif event == "MERCHANT_CLOSED" then
    merchantOpen = false
    sale = nil
    if warning and warning:IsShown() then
      UpdateWarning()
    end
  elseif event == "MERCHANT_UPDATE" then
    CheckSales()
  elseif event == "BAG_UPDATE_DELAYED" then
    CheckSales()
    -- Baganator refreshes its own corner widgets when items move.
    if not useBaganator then
      RefreshAllHearts()
    end
  elseif event == "BANKFRAME_OPENED" then
    if useBaganator then
      FindBaganatorViews()
    else
      RefreshAllHearts()
    end
  elseif event == "PLAYERBANKSLOTS_CHANGED" then
    if not useBaganator then
      RefreshAllHearts()
    end
  end
end)
