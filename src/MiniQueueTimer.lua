local addonName, _ = ...
local loader
local frame
local updateInterval = 0.25
local elapsedSinceUpdate = 0
local draggable
local text
local db
local dbDefaults = {
	Point = "BOTTOM",
	RelativeTo = "UIParent",
	RelativePoint = "BOTTOM",
	X = 0,
	Y = 200,
	Format = "%02d:%02d",
	FontPath = "Fonts\\FRIZQT__.TTF",
	FontSize = 18,
	FontFlags = "OUTLINE",
	FontColor = { 1, 1, 1, 1 },
	PaddingX = 12,
	PaddingY = 8,
}

local function CopyTable(src, dst)
	if type(dst) ~= "table" then
		dst = {}
	end

	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyTable(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end

	return dst
end

local function ApplyPosition()
	local point = db.Point or dbDefaults.Point
	local relativePoint = db.RelativePoint or dbDefaults.RelativePoint
	local relativeTo = (db.RelativeTo and _G["RelativeTo"]) or UIParent
	local x = (type(db.X) == "number") and db.X or dbDefaults.X
	local y = (type(db.Y) == "number") and db.Y or dbDefaults.Y

	draggable:ClearAllPoints()
	draggable:SetPoint(point, relativeTo, relativePoint, x, y)
end

local function SavePosition()
	local point, relativeTo, relativePoint, x, y = draggable:GetPoint(1)

	db.Point = point
	db.RelativeTo = relativeTo
	db.RelativePoint = relativePoint
	db.X = x
	db.Y = y
end

local function ResizeDraggableToText()
	local w = text:GetStringWidth() or 0
	local h = text:GetStringHeight() or 0

	if w < 1 then
		w = 1
	end
	if h < 1 then
		h = 1
	end

	draggable:SetSize(w + (db.PaddingX or 0) * 2, h + (db.PaddingY or 0) * 2)
end

local function FormatTime(seconds)
	seconds = math.floor(seconds or 0)

	local m = math.floor(seconds / 60)
	local s = seconds % 60

	return string.format(db.Format or "%02d:%02d", m, s)
end

local function GetLongestPvPQueueElapsedSeconds()
	local maxSecs = nil
	local maxQueues = MAX_BATTLEFIELD_QUEUES or 3

	for i = 1, maxQueues do
		local status = GetBattlefieldStatus(i)
		if status == "queued" or status == "confirm" then
			local ms = GetBattlefieldTimeWaited(i)

			if type(ms) == "number" and ms > 0 then
				local secs = ms / 1000

				if (not maxSecs) or secs > maxSecs then
					maxSecs = secs
				end
			end
		end
	end

	return maxSecs
end

local function GetLongestPvEQueueElapsedSeconds()
	if type(GetLFGMode) ~= "function" or type(GetLFGQueueStats) ~= "function" then
		return nil
	end

	local categories = {}

	if type(LE_LFG_CATEGORY_LFD) == "number" then
		categories[#categories + 1] = LE_LFG_CATEGORY_LFD
	end
	if type(LE_LFG_CATEGORY_LFR) == "number" then
		categories[#categories + 1] = LE_LFG_CATEGORY_LFR
	end
	if type(LE_LFG_CATEGORY_RF) == "number" then
		categories[#categories + 1] = LE_LFG_CATEGORY_RF
	end
	if type(LE_LFG_CATEGORY_SCENARIO) == "number" then
		categories[#categories + 1] = LE_LFG_CATEGORY_SCENARIO
	end

	if #categories == 0 then
		return nil
	end

	local maxSecs = nil

	for _, category in ipairs(categories) do
		local mode = GetLFGMode(category)
		if mode == "queued" or mode == "proposal" or mode == "confirm" then
			local stats = { GetLFGQueueStats(category) }
			local queueStarted = #stats >= 17 and stats[17]

			if queueStarted then
				local timeInQueue = GetTime() - queueStarted

				if (not maxSecs) or timeInQueue > maxSecs then
					maxSecs = timeInQueue
				end
			end
		end
	end

	return maxSecs
end

local function ApplyFontStyle()
	text:SetFont(db.FontPath or "Fonts\\FRIZQT__.TTF", db.FontSize or 18, db.FontFlags or "OUTLINE")

	local c = db.FontColor
	local r, g, b, a = 1, 1, 1, 1

	if type(c) == "table" then
		r = (type(c[1]) == "number") and c[1] or r
		g = (type(c[2]) == "number") and c[2] or g
		b = (type(c[3]) == "number") and c[3] or b
		a = (type(c[4]) == "number") and c[4] or a
	end

	text:SetTextColor(r, g, b, a)
end

local function UpdateDisplay()
	if IsInInstance() then
		text:SetText("")
		text:Hide()
		return
	end

	local pvpSecs = GetLongestPvPQueueElapsedSeconds()
	local pveSecs = GetLongestPvEQueueElapsedSeconds()
	local secs = math.max(pvpSecs or 0, pveSecs or 0)

	if secs and secs > 0 then
		text:SetText("Time in Queue: " .. FormatTime(secs))
		text:Show()

		ResizeDraggableToText()
	else
		text:SetText("")
		text:Hide()
	end
end

local function Init()
	MiniQueueTimeDB = MiniQueueTimeDB or {}
	db = CopyTable(dbDefaults, MiniQueueTimeDB)

	draggable = CreateFrame("Frame", nil, UIParent)
	draggable:SetClampedToScreen(true)
	draggable:EnableMouse(true)
	draggable:SetMovable(true)
	draggable:RegisterForDrag("LeftButton")

	ApplyPosition()

	draggable:SetScript("OnDragStart", function(self)
		self:StartMoving()
	end)

	draggable:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)

	text = draggable:CreateFontString(nil, "OVERLAY")
	text:SetPoint("CENTER", draggable, "CENTER", 0, 0)
	text:Hide()

	-- must apply font before setting the text
	ApplyFontStyle()

	text:SetText("")

	frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")

	-- pvp queue events
	frame:RegisterEvent("PVPQUEUE_ANYWHERE_SHOW")
	frame:RegisterEvent("PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE")
	frame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")

	-- pve queue events
	frame:RegisterEvent("LFG_UPDATE")
	frame:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
	frame:RegisterEvent("LFG_PROPOSAL_SHOW")
	frame:RegisterEvent("LFG_PROPOSAL_FAILED")
	frame:RegisterEvent("LFG_PROPOSAL_SUCCEEDED")
	frame:RegisterEvent("LFG_ROLE_UPDATE")

	frame:SetScript("OnEvent", function()
		UpdateDisplay()
	end)

	frame:SetScript("OnUpdate", function(_, delta)
		if IsInInstance() then
			return
		end

		elapsedSinceUpdate = elapsedSinceUpdate + delta

		if elapsedSinceUpdate >= updateInterval then
			elapsedSinceUpdate = 0
			UpdateDisplay()
		end
	end)
end

loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		Init()
		loader:SetScript("OnEvent", nil)
	end
end)
