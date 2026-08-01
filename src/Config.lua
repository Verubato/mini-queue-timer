local _, addon = ...
---@type MiniFramework
local mini = addon.Framework

local builtinFontItems = {
	"Fonts\\FRIZQT__.TTF",
	"Fonts\\ARIALN.TTF",
	"Fonts\\MORPHEUS.TTF",
	"Fonts\\SKURRI.TTF",
	"Fonts\\MYRIADPRO-BOLD.TTF",
}

local builtinFontNames = {
	["Fonts\\FRIZQT__.TTF"]       = "Friz Quadrata",
	["Fonts\\ARIALN.TTF"]         = "Arial Narrow",
	["Fonts\\MORPHEUS.TTF"]       = "Morpheus",
	["Fonts\\SKURRI.TTF"]         = "Skurri",
	["Fonts\\MYRIADPRO-BOLD.TTF"] = "Myriad Pro",
}

local function GetFontLists()
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

	if LSM then
		local items = {}
		local names = {}

		for _, name in ipairs(LSM:List("font") or {}) do
			local file = LSM:Fetch("font", name)
			if file then
				items[#items + 1] = file
				names[file] = name
			end
		end

		if #items > 0 then
			return items, names
		end
	end

	return builtinFontItems, builtinFontNames
end

local fontFlagItems = { "OUTLINE", "THICKOUTLINE", "MONOCHROME", "" }

local fontFlagNames = {
	OUTLINE      = "Outline",
	THICKOUTLINE = "Thick Outline",
	MONOCHROME   = "Monochrome",
	[""]         = "None",
}

local function BuildContent(panel)
	local db = addon.db
	local gap = 12
	local insetX = 16
	local insetY = -16
	local fontItems, fontNames = GetFontLists()

	local header = mini:PanelHeader({
		Parent = panel,
		Description = "Shows how long you've been in the queue, and the estimated wait.",
		Y = insetY,
	})

	-- Font
	local fontDiv = mini:Divider({ Parent = panel, Text = "Font" })
	fontDiv:SetPoint("TOPLEFT", header.Anchor, "BOTTOMLEFT", 0, -gap)
	fontDiv:SetPoint("RIGHT", panel, "RIGHT", -insetX, 0)

	-- Font path
	local fontPathLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fontPathLabel:SetText("Font")
	fontPathLabel:SetPoint("TOPLEFT", fontDiv, "BOTTOMLEFT", 0, -gap)

	local fontPathDd = mini:Dropdown({
		Parent = panel,
		Items = fontItems,
		GetValue = function() return db.FontPath end,
		SetValue = function(v)
			db.FontPath = v
			addon:Refresh()
		end,
		GetText = function(v) return fontNames[v] or v end,
	})
	fontPathDd:SetPoint("TOPLEFT", fontPathLabel, "BOTTOMLEFT", 0, -4)
	fontPathDd:SetWidth(240)

	-- Font flags (same row, right of font path)
	local fontFlagsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fontFlagsLabel:SetText("Outline")
	fontFlagsLabel:SetPoint("TOP", fontPathLabel, "TOP", 0, 0)
	fontFlagsLabel:SetPoint("LEFT", fontPathDd, "RIGHT", gap * 2, 0)

	local fontFlagsDd = mini:Dropdown({
		Parent = panel,
		Items = fontFlagItems,
		GetValue = function() return db.FontFlags end,
		SetValue = function(v)
			db.FontFlags = v
			addon:Refresh()
		end,
		GetText = function(v) return fontFlagNames[v] or v end,
	})
	fontFlagsDd:SetPoint("TOPLEFT", fontFlagsLabel, "BOTTOMLEFT", 0, -4)
	fontFlagsDd:SetWidth(160)

	-- Font size slider
	-- M:Slider places its label 8px above the slider's top edge.
	-- Offset = gap(12) + label_height(16) + label_gap(8) = 36px below the font row.
	local sizeResult = mini:Slider({
		Parent = panel,
		LabelText = "Font Size",
		Min = 8,
		Max = 64,
		Step = 1,
		Width = 320,
		GetValue = function() return db.FontSize end,
		SetValue = function(v)
			db.FontSize = mini:ClampInt(v, 8, 64, 18)
			addon:Refresh()
		end,
	})
	sizeResult.Slider:SetPoint("TOPLEFT", fontPathDd, "BOTTOMLEFT", 0, -36)

	-- Font color
	local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	colorLabel:SetText("Font Color")
	colorLabel:SetPoint("TOPLEFT", sizeResult.Slider, "BOTTOMLEFT", 0, -gap)

	local colorBtn = mini:ColorSwatch({
		Parent = panel,
		Tooltip = "Click to change the font color.",
		GetValue = function()
			local c = db.FontColor
			return c.R, c.G, c.B, c.A
		end,
		SetValue = function(r, g, b, a)
			db.FontColor.R, db.FontColor.G, db.FontColor.B, db.FontColor.A = r, g, b, a
		end,
		OnChange = function()
			addon:Refresh()
		end,
	})

	colorBtn:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)

	local colorHint = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	colorHint:SetText("(click to change)")
	colorHint:SetTextColor(0.6, 0.6, 0.6, 1)
	colorHint:SetPoint("LEFT", colorBtn, "RIGHT", 6, 0)

	-- Text
	local textDiv = mini:Divider({ Parent = panel, Text = "Text" })
	textDiv:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -gap)
	textDiv:SetPoint("RIGHT", fontDiv, "RIGHT", 0, 0)

	-- Queue format
	local queueEdit = mini:EditBox({
		Parent = panel,
		LabelText = "Queue Text",
		Width = 340,
		GetValue = function() return db.QueueFormat end,
		SetValue = function(v)
			if v and v ~= "" then
				db.QueueFormat = v
			end
		end,
	})
	local queueLabel, queueBox = queueEdit.Label, queueEdit.EditBox
	queueLabel:SetPoint("TOPLEFT", textDiv, "BOTTOMLEFT", 0, -gap)
	queueBox:SetPoint("TOPLEFT", queueLabel, "BOTTOMLEFT", 0, -4)

	-- Estimated format
	local estEdit = mini:EditBox({
		Parent = panel,
		LabelText = "Estimated Text",
		Width = 340,
		GetValue = function() return db.EstimatedFormat end,
		SetValue = function(v)
			if v and v ~= "" then
				db.EstimatedFormat = v
			end
		end,
	})
	local estLabel, estBox = estEdit.Label, estEdit.EditBox
	estLabel:SetPoint("TOPLEFT", queueBox, "BOTTOMLEFT", 0, -gap)
	estBox:SetPoint("TOPLEFT", estLabel, "BOTTOMLEFT", 0, -4)

	-- Preview / Reset
	local previewBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	previewBtn:SetSize(120, 24)
	previewBtn:SetPoint("TOPLEFT", estBox, "BOTTOMLEFT", -3, -gap * 2)

	local function RefreshPreviewBtn()
		local active = addon.IsTestMode and addon.IsTestMode()
		previewBtn:SetText(active and "Preview: On" or "Preview: Off")
	end
	RefreshPreviewBtn()

	previewBtn:SetScript("OnClick", function()
		if addon.SetTestMode then
			addon.SetTestMode(not addon.IsTestMode())
		end
		RefreshPreviewBtn()
	end)

	local resetBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	resetBtn:SetSize(120, 24)
	resetBtn:SetText("Reset Defaults")
	resetBtn:SetPoint("LEFT", previewBtn, "RIGHT", gap, 0)
	resetBtn:SetScript("OnClick", function()
		mini:ResetSavedVars(addon.dbDefaults)
		addon:Refresh()
		if panel.MiniRefresh then
			panel:MiniRefresh()
		end
	end)
end

mini:WaitForAddonLoad(function()
	local panel = CreateFrame("Frame")
	panel.name = "MiniQueueTimer"

	BuildContent(panel)

	panel:HookScript("OnShow", function()
		if panel.MiniRefresh then
			panel:MiniRefresh()
		end
	end)

	local category = mini:AddCategory(panel)
	mini:RegisterSlashCommand(category, panel, { "/mqt", "/miniqueuetimer", "/miniqt" })
end)
