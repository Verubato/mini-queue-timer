local _, addon = ...
---@type MiniFramework
local mini = addon.Framework
local frame
local updateInterval = 0.25
local emptyStreak = 0
-- 8 * 0.25s = 2 seconds
local stopAfterEmptyTicks = 8
-- The LFG categories this client has, resolved on first use.
local lfgCategories
local draggable
local queueText
local estimatedText
local db
local ticker
local testMode = false
local testModeStart = 0
local dbDefaults = {
	Version = 2,
	Point = "BOTTOM",
	RelativeTo = "UIParent",
	RelativePoint = "BOTTOM",
	X = 0,
	Y = 200,
	QueueFormat = "Time in queue: %02d:%02d",
	EstimatedFormat = "Estimated: %02d:%02d",
	FontPath = "Fonts\\FRIZQT__.TTF",
	FontSize = 18,
	FontFlags = "OUTLINE",
	FontColor = {
		R = 1,
		G = 1,
		B = 1,
		A = 1,
	},
	PaddingX = 12,
	PaddingY = 8,
}
addon.dbDefaults = dbDefaults

local function GetAndUpdatedDb()
	db = mini:GetSavedVars(dbDefaults)

	while db.Version ~= dbDefaults.Version do
		if not db.Version or db.Version == 1 then
			db.Format = nil
			db.FontColor = {
				R = 1,
				G = 1,
				B = 1,
				A = 1,
			}
			db.Version = 2
		end
	end

	return db
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

local function Format(seconds, format)
	if not seconds or seconds < 0 then
		return "Unknown"
	end

	seconds = math.floor(seconds or 0)

	local m = math.floor(seconds / 60)
	local s = seconds % 60

	return string.format(format, m, s)
end

local function GetLongestPvPQueueElapsedSeconds()
	local maxSecs = nil
	local estimated = nil
	local isQueued = false
	local maxQueues = MAX_BATTLEFIELD_QUEUES or (GetMaxBattlefieldID and GetMaxBattlefieldID()) or 3

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

---The LFG categories this client exposes. Which constants exist is fixed for the session, so
---the list is worked out once instead of on every tick.
local function GetLfgCategories()
	if lfgCategories then
		return lfgCategories
	end

	lfgCategories = {}

	local names = {
		LE_LFG_CATEGORY_LFD,
		LE_LFG_CATEGORY_LFR,
		LE_LFG_CATEGORY_RF,
		LE_LFG_CATEGORY_SCENARIO,
		LE_LFG_CATEGORY_BATTLEFIELD,
	}

	for i = 1, 5 do
		if type(names[i]) == "number" then
			lfgCategories[#lfgCategories + 1] = names[i]
		end
	end

	return lfgCategories
end

local function GetLongestPvEQueueElapsedSeconds()
	if type(GetLFGMode) ~= "function" or type(GetLFGQueueStats) ~= "function" then
		return nil
	end

	local categories = GetLfgCategories()

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

			-- 16 and 17 are myWait and queuedTime.
			local estWait, queueStarted = select(16, GetLFGQueueStats(category))

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
		r = (type(c.R) == "number") and c.R or r
		g = (type(c.G) == "number") and c.G or g
		b = (type(c.B) == "number") and c.B or b
		a = (type(c.A) == "number") and c.A or a
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
	if testMode then
		local elapsed = GetTime() - testModeStart
		queueText:SetText(Format(elapsed, db.QueueFormat))
		estimatedText:SetText(Format(300, db.EstimatedFormat))
		queueText:Show()
		estimatedText:Show()
		draggable:EnableMouse(true)
		ResizeDraggableToText()
		return
	end

	if IsInInstance() then
		queueText:SetText("")
		queueText:Hide()
		estimatedText:SetText("")
		estimatedText:Hide()
		draggable:EnableMouse(false)
		StopTicker()
		emptyStreak = 0
		return
	end

	local pvpSecs, pvpEstimated, pvpQueued = GetLongestPvPQueueElapsedSeconds()
	local pveSecs, pveEstimated, pveQueued = GetLongestPvEQueueElapsedSeconds()
	local isQueued = pvpQueued or pveQueued

	if pvpSecs and pvpSecs >= (pveSecs or 0) then
		queueText:SetText(Format(pvpSecs, db.QueueFormat))
		estimatedText:SetText(Format(pvpEstimated, db.EstimatedFormat))

		queueText:Show()
		estimatedText:Show()
		draggable:EnableMouse(true)

		ResizeDraggableToText()
		emptyStreak = 0
		return
	end

	if pveSecs and pveSecs > 0 then
		queueText:SetText(Format(pveSecs, db.QueueFormat))
		estimatedText:SetText(Format(pveEstimated, db.EstimatedFormat))

		queueText:Show()
		estimatedText:Show()
		draggable:EnableMouse(true)

		ResizeDraggableToText()
		emptyStreak = 0
		return
	end

	-- No queue data yet or not queued
	queueText:SetText("")
	queueText:Hide()

	estimatedText:SetText("")
	estimatedText:Hide()
	draggable:EnableMouse(false)

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

function addon:Refresh()
	-- Fonts only move when the config does, and this is the path a config change takes.
	ApplyFontStyle()
	UpdateDisplay()
end

local function OnAddonLoaded()
	db = GetAndUpdatedDb()
	addon.db = db

	addon.IsTestMode = function() return testMode end
	addon.SetTestMode = function(active)
		testMode = active
		if active then
			testModeStart = GetTime()
			UpdateDisplay()
			EnsureTicker()
		else
			StopTicker()
			queueText:SetText("")
			queueText:Hide()
			estimatedText:SetText("")
			estimatedText:Hide()
			draggable:EnableMouse(false)
		end
	end

	draggable = CreateFrame("Frame", nil, UIParent)

	mini:MakeMovable(draggable, db)
	mini:ApplyPosition(draggable, db, dbDefaults)

	-- only accepts the mouse while a queue timer is actually on screen
	draggable:EnableMouse(false)

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

mini:WaitForAddonLoad(OnAddonLoaded)
