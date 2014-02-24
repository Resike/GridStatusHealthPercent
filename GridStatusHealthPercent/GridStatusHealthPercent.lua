--{{{ Libraries

local RL = AceLibrary("Roster-2.1")
local Aura = AceLibrary("SpecialEvents-Aura-2.0")
local L = AceLibrary("AceLocale-2.2"):new("GridStatusHealthPercent")

--}}}
--

GridStatusHealthPercent = GridStatus:NewModule("GridStatusHealthPercent")
GridStatusHealthPercent.menuName = L["Health Percent"]
GridStatusHealthPercent.options = false

--{{{ AceDB defaults
--
GridStatusHealthPercent.defaultDB = {
    unit_healthPercent = {
        enable = true,
        color = { r = 1, g = 1, b = 1, a = 1 },
        priority = 30,
        threshold = 80,
        range = false,
        useClassColors = false,
        shiftColors = true,
    },
}

--}}}

local options = {
    ["threshold"] = {
        type = "range",
        name = L["Health threshold"],
        desc = L["Only show percent above % damage."],
        max = 100,
        min = 0,
        step = 1,
        get = function ()
                  return GridStatusHealthPercent.db.profile.unit_healthPercent.threshold
              end,
        set = function (v)
                  GridStatusHealthPercent.db.profile.unit_healthPercent.threshold = v
                  GridStatusHealthPercent:UpdateAllUnits()
              end,
    },
    ["useClassColors"] = {
        type = "toggle",
        name = L["Use class color"],
        desc = L["Color percent based on class."],
        get = function ()
                  return GridStatusHealthPercent.db.profile.unit_healthPercent.useClassColors
              end,
        set = function (v)
                  GridStatusHealthPercent.db.profile.unit_healthPercent.useClassColors = v
                  GridStatusHealthPercent:UpdateAllUnits()
              end,
    },
    ["shiftColors"] = {
        type = "toggle",
        name = L["Shift colors"],
        desc = L["Color percent based on damage."],
        get = function ()
                  return GridStatusHealthPercent.db.profile.unit_healthPercent.shiftColors
              end,
        set = function (v)
                  GridStatusHealthPercent.db.profile.unit_healthPercent.shiftColors = v
                  GridStatusHealthPercent:UpdateAllUnits()
              end,
    }    
}

function GridStatusHealthPercent:OnInitialize()
	self.super.OnInitialize(self)
	
    self:RegisterStatus("unit_healthPercent", L["Health Percent"], options, true)
end

function GridStatusHealthPercent:OnEnable()
    self:RegisterEvent("Grid_UnitJoined")
    self:RegisterEvent("Grid_UnitChanged")
    self:RegisterEvent("UNIT_HEALTH", "UpdateUnit")
    self:RegisterEvent("UNIT_MAXHEALTH", "UpdateUnit")
    self:RegisterEvent("UNIT_AURA", "UpdateUnit")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAllUnits")
end

function GridStatusHealthPercent:Reset()
	self.super.Reset(self)
	self:UpdateAllUnits()
end

function GridStatusHealthPercent:UpdateAllUnits()
    for u in RL:IterateRoster(true) do
        self:Grid_UnitJoined(u.unitname, u.unitid)
    end
end

function GridStatusHealthPercent:UNIT_HEALTH(units)
    local unitid

    for unitid in pairs(units) do
        self:UpdateUnit(unitid)
    end
end

function GridStatusHealthPercent:Grid_UnitJoined(name, unitid)
    if unitid then
        self:UpdateUnit(unitid, true)
        self:UpdateUnit(unitid)
    end

end

function GridStatusHealthPercent:Grid_UnitChanged(name, unitid)
    self:UpdateUnit(unitid)
end

function GridStatusHealthPercent:UpdateUnit(unitid, ignoreRange)
    local cur, max = UnitHealth(unitid), UnitHealthMax(unitid)
    local name = UnitName(unitid)

    local percentSettings = self.db.profile.unit_healthPercent
    local healthText
    local priority = percentSettings.priority
    local color = percentSettings.color
    
    if not name then return end
    if not cur then return end
    if not max then return end

    healthText, colorText = self:FormatHealthText(cur,max)

    if (cur / max * 100) <= percentSettings.threshold then
        if percentSettings.useClassColors then     
            color = self.core:UnitColor(RL:GetUnitObjectFromName(name))
        elseif percentSettings.shiftColors then
            color = colorText           
        end
    
        self.core:SendStatusGained(name,
                         "unit_healthPercent",
                         percentSettings.priority,
                         (percentSettings.range and 40),
                         color,
                         healthText,
                         cur,
                         max,
                         nil)
    else
        self.core:SendStatusLost(name, "unit_healthPercent")
    end
end

function GridStatusHealthPercent:FormatHealthText(cur, max)
    local healthText
    local colorText
    
    local percent = (cur / max * 100)
    
    if percent > 60 then
        -- Green Percent
        colorText = { r = 0, g = 192, b = 0, a = 1 }
    elseif percent > 20 then
        -- Yellow Percent
        colorText = { r = 255, g = 255, b = 0, a = 1 }
    else
        -- Red Percent
        colorText = { r = 255, g = 0, b = 0, a = 1 }
    end        

    healthText = string.format("%d%%", percent)

    return healthText, colorText
end


