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
end)
