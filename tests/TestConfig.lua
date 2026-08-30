-- Config.lua's controls are direct children of the panel, so a test finds one the same way a
-- player would: by the text it shows. This does not check the panel's pixel layout as a whole,
-- only the specific anchor values a fleet-standard change touched.

local fw = require("TestFramework")
local harness = require("AddonHarness")

local function FindChildText(parent, text)
	for _, child in ipairs(parent.__children or {}) do
		if child.GetText and child:GetText() == text then
			return child
		end
	end
end

local function FindButtonText(mock, text)
	for _, frame in ipairs(mock.Frames) do
		if frame.GetText and frame.Click and frame:GetText() == text then
			return frame
		end
	end
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

		resetBtn:Click()
		fw.eq(context.Addon.db.FontSize, 40, "the click only opened the confirmation")

		local acceptBtn = FindButtonText(context.Mock, "Reset")
		fw.not_nil(acceptBtn, "fixture: the confirmation dialog is showing")

		acceptBtn:Click()
		fw.eq(context.Addon.db.FontSize, context.Addon.dbDefaults.FontSize, "accepting applied the defaults")
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
