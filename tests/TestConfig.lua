-- Config.lua's controls are direct children of the panel, so a test finds one the same way a
-- player would: by the text it shows. This does not check the panel's pixel layout as a whole,
-- only the specific anchor values a fleet-standard change touched.

local fw = require("TestFramework")
local harness = require("AddonHarness")
local WowMock = require("WowMock")

local function FindChildText(parent, text)
	for _, child in ipairs(parent.__children or {}) do
		if child.GetText and child:GetText() == text then
			return child
		end
	end
end

---A stand-in for a pooled dropdown row: just the label field DecorateFontRow reads and
---writes, the way a real row carries its label as `.fontString`.
---@param stockFont table?
---@return table
local function NewRow(stockFont)
	local fontObject = stockFont
	local text = {}

	function text:GetFontObject()
		return fontObject
	end

	function text:SetFontObject(object)
		fontObject = object
	end

	return { fontString = text }
end

---A modern dropdown only exposes its per-row decorator through the initializer AddInitializer
---captures, so a test replays the generator against a description that records them by value.
---@param dd table
---@return table<any, fun(button:table)>
local function MenuInitializers(dd)
	local initializers = {}
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function(_, _, _, _, value)
		local radio = {}

		function radio:AddInitializer(fn)
			initializers[value] = fn
		end

		return radio
	end

	dd.__menuGenerator(dd, description)

	return initializers
end

---The font dropdown is the only one wired with DecorateItem, so the row it captures an
---initializer for a real font path picks it out among every dropdown on the panel.
---@param value string
---@return fun(button:table)?
local function FindFontRowInitializer(value)
	for _, frame in ipairs(WowMock.Frames) do
		if frame.__menuGenerator then
			local initializer = MenuInitializers(frame)[value]

			if initializer then
				return initializer
			end
		end
	end
end

---The same search as FindFontRowInitializer, but handing back the dropdown frame itself so a
---test can replay its menu generator more than once.
---@return table?
local function FindFontDropdown()
	for _, frame in ipairs(WowMock.Frames) do
		if frame.__menuGenerator and MenuInitializers(frame)["Fonts\\ARIALN.TTF"] then
			return frame
		end
	end
end

---MenuInitializers keys rows by their value, so two rows sharing a file would collapse to one
---key even when the list underneath still carries both. A row count catches that duplication.
---@param dd table
---@return number
local function CountFontRows(dd)
	local count = 0
	local description = {}

	setmetatable(description, {
		__index = function()
			return function() end
		end,
	})

	description.CreateRadio = function()
		count = count + 1

		return nil
	end

	dd.__menuGenerator(dd, description)

	return count
end

---The client does nothing with a prompt in the mock, so a test stands in for it.
---@param open fun()
---@return table
local function CaptureConfirm(open)
	local seen = {}
	local real = StaticPopup_Show

	StaticPopup_Show = function(which, _, _, data)
		seen.Which, seen.Data = which, data
	end

	local ok, err = pcall(open)

	StaticPopup_Show = real

	if not ok then
		error(err, 0)
	end

	return seen
end

fw.describe("MiniQueueTimer - config panel", function()
	local context, panel

	fw.before_each(function()
		context = harness.Run("MiniQueueTimer")
		panel = context.Addon.ConfigPanel
	end)

	fw.it("exposes the panel for tests", function()
		fw.not_nil(panel, "fixture: the config panel is built and exposed for tests")
	end)

	fw.it("labels the font colour caption in British spelling, clear of the slider above it", function()
		local colorLabel = FindChildText(panel, "Font Colour")

		fw.not_nil(colorLabel, "the caption reads Font Colour")
		fw.is_nil(FindChildText(panel, "Font Color"), "the American spelling is gone")

		local _, _, _, _, y = colorLabel:GetPoint()

		-- The slider's min/max numbers sit below its own frame, so a single gap would still
		-- crowd them; this stays doubled so the caption clears them.
		fw.eq(y, -24, "the caption sits two gaps below the slider, not one")
	end)

	fw.it("replaces the hand-rolled reset button with the framework's", function()
		fw.is_nil(FindChildText(panel, "Reset Defaults"), "the old button is gone")
		fw.not_nil(FindChildText(panel, "Reset to Defaults"), "the framework's reset button is in its place")
	end)

	fw.it("asks before applying a reset, then restores the defaults through the addon", function()
		context.Addon.db.FontSize = 40

		local resetBtn = FindChildText(panel, "Reset to Defaults")
		fw.not_nil(resetBtn, "fixture: the reset button is on the panel")

		local seen = CaptureConfirm(function()
			resetBtn:Click()
		end)

		fw.not_nil(seen.Which, "fixture: the confirmation dialog is showing")
		fw.eq(context.Addon.db.FontSize, 40, "the click only opened the confirmation")

		StaticPopupDialogs[seen.Which].OnAccept(nil, seen.Data)

		fw.eq(context.Addon.db.FontSize, context.Addon.dbDefaults.FontSize, "accepting applied the defaults")
	end)

	fw.it("sends the display back to its default position when settings are reset", function()
		local displayFrame = _G["MiniQueueTimerFrame"]
		local defaults = context.Addon.dbDefaults
		local db = context.Addon.db

		fw.not_nil(displayFrame, "fixture: the display frame is exposed for tests")

		displayFrame:ClearAllPoints()
		displayFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 350, -75)
		db.Point = "TOPLEFT"
		db.RelativePoint = "TOPLEFT"
		db.RelativeTo = "UIParent"
		db.X = 350
		db.Y = -75

		local resetBtn = FindChildText(panel, "Reset to Defaults")
		local seen = CaptureConfirm(function()
			resetBtn:Click()
		end)

		StaticPopupDialogs[seen.Which].OnAccept(nil, seen.Data)

		local point, _, relativePoint, x, y = displayFrame:GetPoint(1)

		fw.eq(x, defaults.X, "reset put the display back at its default x")
		fw.eq(y, defaults.Y, "reset put the display back at its default y")
		fw.eq(point, defaults.Point, "reset put the display back on its default anchor point")
		fw.eq(relativePoint, defaults.RelativePoint, "reset put the display back on its default relative point")
	end)

	fw.it("left-aligns the Queue Text and Estimated captions with their edit boxes", function()
		local queueLabel = FindChildText(panel, "Queue Text")
		local estLabel = FindChildText(panel, "Estimated Text")
		local queueBox = FindChildText(panel, context.Addon.db.QueueFormat)
		local estBox = FindChildText(panel, context.Addon.db.EstimatedFormat)

		fw.not_nil(queueLabel, "fixture: queue label found")
		fw.not_nil(estLabel, "fixture: estimated label found")
		fw.not_nil(queueBox, "fixture: queue box found")
		fw.not_nil(estBox, "fixture: estimated box found")

		local _, _, _, queueLabelX = queueLabel:GetPoint()
		local _, _, _, estLabelX = estLabel:GetPoint()
		local _, _, _, queueBoxX = queueBox:GetPoint()
		local _, _, _, estBoxX = estBox:GetPoint()

		-- Both boxes' flattened field bleeds ~5px past their own frame's left edge, so both
		-- nudge 4px right of their label to line their visible edge up with it.
		fw.eq(queueBoxX, 4, "queue box nudges right to line up with its label")
		fw.eq(estBoxX, 4, "estimated box nudges right to line up with its label")

		-- Both labels then share the same left edge as each other.
		fw.eq(queueLabelX, estLabelX + 4, "the two captions line up with each other")
	end)
end)

fw.describe("MiniQueueTimer - font dropdown preview rows", function()
	fw.before_each(function()
		harness.Run("MiniQueueTimer")
	end)

	fw.it("wires the preview decorator onto the font dropdown, wearing the font it names", function()
		local initializer = FindFontRowInitializer("Fonts\\ARIALN.TTF")
		fw.not_nil(initializer, "fixture: the font dropdown captured an initializer for a known font")

		local stock = {}
		local row = NewRow(stock)

		initializer(row)

		local object = row.fontString:GetFontObject()
		fw.not_nil(object, "the row picked up a font object")
		fw.neq(object, stock, "not the stock font it started with")
		fw.eq(object:GetFont(), "Fonts\\ARIALN.TTF", "wearing the face it names")

		-- Only CreateFontFamily records its member definition.
		fw.not_nil(object.__members, "built through CreateFontFamily, not CreateFont+SetFont")

		local alphabets = {}
		for i, member in ipairs(object.__members) do
			alphabets[i] = member.alphabet
		end

		fw.eq(table.concat(alphabets, ","), "roman,korean,simplifiedchinese,traditionalchinese,russian",
			"one member for every alphabet the client distinguishes")
	end)

	fw.it("keeps the row's original stock font through repeated decorates, not the first preview", function()
		local first = FindFontRowInitializer("Fonts\\ARIALN.TTF")
		local second = FindFontRowInitializer("Fonts\\FRIZQT__.TTF")
		fw.not_nil(first, "fixture: an initializer captured for the first font")
		fw.not_nil(second, "fixture: an initializer captured for a different font")

		local stock = {}
		local row = NewRow(stock)

		first(row)
		second(row)

		fw.eq(row.MiniQueueTimerStockFont, stock, "the remembered stock font is still the original, not the first preview")
	end)
end)

fw.describe("MiniQueueTimer - font media subscription", function()
	fw.before_each(function()
		harness.Run("MiniQueueTimer")
	end)

	fw.it("picks up a font a media pack registers after the panel is built", function()
		local testFile = "Fonts\\MiniQueueTimerTestFace.ttf"

		fw.is_nil(FindFontRowInitializer(testFile), "fixture: the unregistered face isn't offered yet")

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", "MiniQueueTimer Test Face", testFile)
		fw.is_nil(FindFontRowInitializer(testFile), "the registration alone doesn't rebuild the list yet")

		WowMock.RunTimers()

		fw.not_nil(FindFontRowInitializer(testFile), "the font appears once the coalesced refresh runs")
	end)

	fw.it("coalesces two registrations in the same frame into a single refresh", function()
		local secondFile = "Fonts\\MiniQueueTimerSecondTestFace.ttf"
		local thirdFile = "Fonts\\MiniQueueTimerThirdTestFace.ttf"

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", "MiniQueueTimer Second Test Face", secondFile)
		lsm:Register("font", "MiniQueueTimer Third Test Face", thirdFile)

		fw.eq(WowMock.RunTimers(), 1, "two registrations in one frame coalesce into a single refresh")
		fw.not_nil(FindFontRowInitializer(secondFile), "the first of the pair lands after the one refresh")
		fw.not_nil(FindFontRowInitializer(thirdFile), "the second of the pair lands after the same refresh")
	end)

	fw.it("leaves the other faces listed once a global font override is set", function()
		local overrideTargetName = "MiniQueueTimer Override Target Face"
		local overrideTargetFile = "Fonts\\MiniQueueTimerOverrideTargetFace.ttf"
		local otherFile = "Fonts\\MiniQueueTimerOtherTestFace.ttf"
		local overriddenFile = "Fonts\\MiniQueueTimerOverriddenTestFace.ttf"

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", overrideTargetName, overrideTargetFile)
		lsm:Register("font", "MiniQueueTimer Other Test Face", otherFile)
		WowMock.RunTimers()

		fw.not_nil(FindFontRowInitializer(otherFile), "fixture: the other face is listed before the override")

		-- Fetch would answer this one face for every name, leaving a single row naming a raw path.
		lsm:SetGlobal("font", overrideTargetName)
		lsm:Register("font", "MiniQueueTimer Overridden Test Face", overriddenFile)

		WowMock.RunTimers()

		fw.not_nil(FindFontRowInitializer(otherFile), "a global font override leaves the other face listed")
		fw.not_nil(FindFontRowInitializer(overriddenFile), "the face registered under the override lands too")

		lsm:SetGlobal("font", nil)
	end)

	fw.it("adds a single row when two names resolve to the same file", function()
		local dd = FindFontDropdown()
		fw.not_nil(dd, "fixture: the font dropdown is found")

		local rowsBefore = CountFontRows(dd)
		local sharedFile = "Fonts\\MiniQueueTimerSharedTestFace.ttf"

		local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
		fw.not_nil(lsm, "fixture: LibSharedMedia resolves under the mock")

		lsm:Register("font", "MiniQueueTimer Shared Name One", sharedFile)
		lsm:Register("font", "MiniQueueTimer Shared Name Two", sharedFile)

		WowMock.RunTimers()

		fw.eq(CountFontRows(dd) - rowsBefore, 1, "two names resolving to one file add a single row")
	end)
end)
