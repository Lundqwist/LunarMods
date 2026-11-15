-- LunarMods part: __TITLE__
-- __NOTES__

-- "..." holds this addon's folder name. NewPart registers the part with
-- LunarMods and gives back its toolbox (see LunarMods/Core.lua).
local part = LunarMods:NewPart(...)

-- Runs when the part is switched on: at login, or when ticked in /lm.
-- Create frames and register events here.
function part:OnEnable()
    -- self:RegisterEvent("PLAYER_REGEN_DISABLED")   -- calls part:PLAYER_REGEN_DISABLED(event, ...)
    self:Print("switched on.")
end

-- Optional. Runs when the part is unticked in /lm: hide frames and stop
-- timers here. Events are removed by LunarMods. Without this function the
-- part still stops getting events, and is gone completely after a /reload.
function part:OnDisable()
end

-- Optional. "/lm __SHORT__ some text" ends up here with message = "some text".
function part:OnSlash(message)
    self:Print("you typed: " .. message)
end

-- Saved between sessions:
--   self.db      shared by all your characters
--   self.chardb  for this character only
