local addonName, _ = ...
local loader
local frame
local updateInterval = 0.25
local emptyStreak = 0
-- 8 * 0.25s = 2 seconds
local stopAfterEmptyTicks = 8
local draggable
local queueText
local estimatedText
local db
local ticker
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
	local relativeTo = (db.RelativeTo and _G[db.RelativeTo]) or UIParent
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
	local w = math.max(queueText:GetStringWidth() or 0, estimatedText:GetStringWidth() or 0)
	local h = (queueText:GetStringHeight() or 0) + (estimatedText:GetStringHeight() or 0)

	if w < 1 then
		w = 1
	end
	if h < 1 then
		h = 1
	end

	draggable:SetSize(w + (db.PaddingX or 0) * 2, h + (db.PaddingY or 0) * 2)
end

local function FormatTime(seconds)
	if not seconds or seconds < 0 then
		return "Unknown"
	end

	seconds = math.floor(seconds or 0)

	local m = math.floor(seconds / 60)
	local s = seconds % 60

	return string.format(db.Format or "%02d:%02d", m, s)
end

local function GetLongestPvPQueueElapsedSeconds()
	local maxSecs = nil
	local estimated = nil
	local isQueued = false
	local maxQueues = MAX_BATTLEFIELD_QUEUES or 3

	for i = 1, maxQueues do
		local status = GetBattlefieldStatus(i)
		if status == "queued" or status == "confirm" then
			isQueued = true

			local ms = GetBattlefieldTimeWaited(i)
			local est = GetBattlefieldEstimatedWaitTime(i)

			if type(ms) == "number" and ms > 0 then
				local secs = ms / 1000
				if (not maxSecs) or secs > maxSecs then
					maxSecs = secs
					estimated = (type(est) == "number") and (est / 1000) or nil
				end
			end
		end
	end

	return maxSecs, estimated, isQueued
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
	local estimated = nil
	local isQueued = false

	for _, category in ipairs(categories) do
		local mode = GetLFGMode(category)
		if mode == "queued" or mode == "proposal" or mode == "confirm" then
			isQueued = true

			local stats = { GetLFGQueueStats(category) }
			local estWait = #stats >= 16 and stats[16]
			local queueStarted = #stats >= 17 and stats[17]

			if type(queueStarted) == "number" then
				local timeInQueue = GetTime() - queueStarted
				if (not maxSecs) or timeInQueue > maxSecs then
					maxSecs = timeInQueue
					estimated = estWait
				end
			end
		end
	end

	return maxSecs, estimated, isQueued
end

local function ApplyFontStyle()
	queueText:SetFont(db.FontPath or "Fonts\\FRIZQT__.TTF", db.FontSize or 18, db.FontFlags or "OUTLINE")
	estimatedText:SetFont(db.FontPath or "Fonts\\FRIZQT__.TTF", db.FontSize or 18, db.FontFlags or "OUTLINE")

	local c = db.FontColor
	local r, g, b, a = 1, 1, 1, 1

	if type(c) == "table" then
		r = (type(c[1]) == "number") and c[1] or r
		g = (type(c[2]) == "number") and c[2] or g
		b = (type(c[3]) == "number") and c[3] or b
		a = (type(c[4]) == "number") and c[4] or a
	end

	queueText:SetTextColor(r, g, b, a)
	estimatedText:SetTextColor(r, g, b, a)
end

local function StopTicker()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

local function UpdateDisplay()
	if IsInInstance() then
		queueText:SetText("")
		queueText:Hide()
		estimatedText:SetText("")
		estimatedText:Hide()
		StopTicker()
		emptyStreak = 0
		return
	end

	local pvpSecs, pvpEstimated, pvpQueued = GetLongestPvPQueueElapsedSeconds()
	local pveSecs, pveEstimated, pveQueued = GetLongestPvEQueueElapsedSeconds()
	local isQueued = pvpQueued or pveQueued

	if pvpSecs and pvpSecs >= (pveSecs or 0) then
		queueText:SetText("Time in Queue: " .. FormatTime(pvpSecs))
		estimatedText:SetText("Estimated time: " .. FormatTime(pvpEstimated))

		queueText:Show()
		estimatedText:Show()

		ResizeDraggableToText()
		emptyStreak = 0
		return
	end

	if pveSecs and pveSecs > 0 then
		queueText:SetText("Time in Queue: " .. FormatTime(pveSecs))
		estimatedText:SetText("Estimated time: " .. FormatTime(pveEstimated))

		queueText:Show()
		estimatedText:Show()

		ResizeDraggableToText()
		emptyStreak = 0
		return
	end

	-- No queue data yet or not queued
	queueText:SetText("")
	queueText:Hide()

	estimatedText:SetText("")
	estimatedText:Hide()

	if isQueued then
		emptyStreak = 0
		return
	end

	emptyStreak = emptyStreak + 1

	if emptyStreak >= stopAfterEmptyTicks then
		StopTicker()
		emptyStreak = 0
	end
end

local function EnsureTicker()
	if ticker then
		return
	end

	ticker = C_Timer.NewTicker(updateInterval, UpdateDisplay)
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

	queueText = draggable:CreateFontString(nil, "OVERLAY")
	queueText:SetPoint("CENTER", draggable, "CENTER", 0, 0)
	queueText:Hide()

	estimatedText = draggable:CreateFontString(nil, "OVERLAY")
	estimatedText:SetPoint("TOP", queueText, "BOTTOM", 0, queueText:GetStringHeight())
	estimatedText:Hide()

	-- must apply font before setting the text
	ApplyFontStyle()

	queueText:SetText("")
	estimatedText:SetText("")

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
		EnsureTicker()
		UpdateDisplay()
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
