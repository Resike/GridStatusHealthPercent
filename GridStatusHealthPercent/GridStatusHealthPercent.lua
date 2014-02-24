-- ----------------------------------------------------------------------------
-- GridStatusHealthPercent by Szandos
-- ----------------------------------------------------------------------------

local L = GridStatusHealthPercentLocale
local GridRoster = Grid:GetModule("GridRoster")
local GridStatusHealthPercent = Grid:GetModule("GridStatus"):NewModule("GridStatusHealthPercent")

-- Fix configuration
GridStatusHealthPercent.menuName = L["Health Percent"]

GridStatusHealthPercent.defaultDB = {
	unit_healthPercent = {
		enable = true,
		color = {r = 1, g = 1, b = 1, a = 1},
		priority = 30,
		threshold = 80,
		range = false,
		useClassColors = false,
		shiftColors = true
	}
}

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
		set = function (_, v)
			GridStatusHealthPercent.db.profile.unit_healthPercent.threshold = v
			GridStatusHealthPercent:UpdateAllUnits()
		end
	},
	["useClassColors"] = {
		type = "toggle",
		name = L["Use class color"],
		desc = L["Color percent based on class."],
		get = function ()
			return GridStatusHealthPercent.db.profile.unit_healthPercent.useClassColors
		end,
		set = function (_, v)
			GridStatusHealthPercent.db.profile.unit_healthPercent.useClassColors = v
			GridStatusHealthPercent:UpdateAllUnits()
		end
	},
	["shiftColors"] = {
		type = "toggle",
		name = L["Shift colors"],
		desc = L["Color percent based on damage."],
		get = function ()
			return GridStatusHealthPercent.db.profile.unit_healthPercent.shiftColors
		end,
		set = function (_, v)
			GridStatusHealthPercent.db.profile.unit_healthPercent.shiftColors = v
			GridStatusHealthPercent:UpdateAllUnits()
		end
	}
}

-- Register the status
function GridStatusHealthPercent:OnInitialize()
	self.super.OnInitialize(self)
	self:RegisterStatus("unit_healthPercent", L["Health Percent"], options, true)
end

-- Hook into relevant events
function GridStatusHealthPercent:OnEnable()
	if not self.db.profile.unit_healthPercent.enable then
		return
	end
	self:RegisterMessage("Grid_UnitJoined")
	self:RegisterEvent("UNIT_AURA", "UpdateUnit")
	self:RegisterEvent("UNIT_HEALTH", "UpdateUnit")
	self:RegisterEvent("UNIT_MAXHEALTH", "UpdateUnit")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateAllUnits")
	self:RegisterEvent("PARTY_MEMBERS_CHANGED", "UpdateAllUnits")
	self:RegisterEvent("RAID_ROSTER_UPDATE", "UpdateAllUnits")
end

-- Unhook events
function GridStatusHealthPercent:OnDisable()
	self:UnregisterMessage("Grid_UnitJoined")
	self:UnregisterEvent("UNIT_HEALTH", "UpdateUnit")
	self:UnregisterEvent("UNIT_MAXHEALTH", "UpdateUnit")
	self:UnregisterEvent("UNIT_AURA", "UpdateUnit")
	self:UnregisterEvent("PLAYER_ENTERING_WORLD", "UpdateAllUnits")
	self:UnregisterEvent("PARTY_MEMBERS_CHANGED", "UpdateAllUnits")
	self:UnregisterEvent("RAID_ROSTER_UPDATE", "UpdateAllUnits")
end

function GridStatusHealthPercent:OnStatusEnable(status)
	self.db.profile.unit_healthPercent.enable = true
	self:UpdateAllUnits()
end

function GridStatusHealthPercent:OnStatusDisable(status)
	self.db.profile.unit_healthPercent.enable = false
	self.core:SendStatusLostAllUnits(status)
	self:OnDisable()
end

function GridStatusHealthPercent:Reset()
	self.super.Reset(self)
	self:UpdateAllUnits()
end

function GridStatusHealthPercent:UpdateAllUnits()
	for guid, unitid in GridRoster:IterateRoster() do
		self:Grid_UnitJoined("UpdateAllUnits", guid, unitid)
	end
end

function GridStatusHealthPercent:Grid_UnitJoined(event, guid, unitid)
	if unitid then
		self:UpdateUnit(event, unitid)
	end
end

function GridStatusHealthPercent:UpdateUnit(event, unitid, ignoreRange)
	if not self.db.profile.unit_healthPercent.enable then
		return
	end
	local guid = UnitGUID(unitid)
	if not GridRoster:IsGUIDInRaid(guid) then
		return
	end
	local cur, max = UnitHealth(unitid), UnitHealthMax(unitid)
	local percentSettings = self.db.profile.unit_healthPercent
	local priority = percentSettings.priority
	local color = percentSettings.color
	local healthText, colorText = self:FormatHealthText(cur, max)
	if (cur / max * 100) <= percentSettings.threshold then
		if percentSettings.useClassColors then
			color = self.core:UnitColor(guid)
		elseif percentSettings.shiftColors then
			color = colorText
		end	
		self.core:SendStatusGained(guid, "unit_healthPercent", percentSettings.priority, (percentSettings.range and 40), color, healthText, cur, max, nil)
	else
		self.core:SendStatusLost(guid, "unit_healthPercent")
	end
end

function GridStatusHealthPercent:FormatHealthText(cur, max)
	local healthText, colorText
	local percent = (cur / max * 100)
	local percentSettings = self.db.profile.unit_healthPercent
	if percentSettings.shiftColors and not percentSettings.useClassColors then
		if percent > 60 then
			-- Green Percent
			colorText = {r = 0, g = 192, b = 0, a = 1}
		elseif percent > 20 then
			-- Yellow Percent
			colorText = {r = 255, g = 255, b = 0, a = 1}
		else
			-- Red Percent
			colorText = {r = 255, g = 0, b = 0, a = 1}
		end
	end
	if percent >= 0 and percent <= 100 then
		healthText = string.format("%d%%", percent)
	elseif percent > 100 then
		healthText = string.format("%d%%", 100)
	elseif percent < 0 then
		healthText = string.format("%d%%", 0)
	end
	return healthText, colorText
end