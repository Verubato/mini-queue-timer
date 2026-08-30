local addonName, addon = ...
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

local fontFlagItems = { "OUTLINE", "THICKOUTLINE", "MONOCHROME", "" }

local fontFlagNames = {
	OUTLINE      = "Outline",
	THICKOUTLINE = "Thick Outline",
	MONOCHROME   = "Monochrome",
	[""]         = "None",
}

-- Preview rows sit in a menu, so they take the menu's own text size.
local PREVIEW_FONT_SIZE = 13
-- Only the client's own locale takes the configured file, so text in another script still
-- renders from the game's files.
local FAMILY_ALPHABETS = { "roman", "korean", "simplifiedchinese", "traditionalchinese", "russian" }
local LOCALE_ALPHABETS = {
	koKR = "korean",
	zhCN = "simplifiedchinese",
	zhTW = "traditionalchinese",
	ruRU = "russian",
}
-- SetFont answers false for a file the client is still loading and leaves the object undefined
-- for good, so these are built once through CreateFontFamily and never edited after.
local previewFontObjects = {}
local previewFontObjectCount = 0

-- The dropdown holds these tables, so they are refilled in place rather than replaced.
local fontItems = {}
local fontNames = {}
local fontPathDd
local fontsMediaSubscribed = false
local fontsRefreshQueued = false

---The family members for a file at a size: the file itself for the client's own locale, the
---game's per-alphabet files for the rest.
---@param file string
---@param size number
---@param flags string
---@return table[] members
local function FamilyMembers(file, size, flags)
	local override = LOCALE_ALPHABETS[GetLocale()] or "roman"
	local members = {}

	for _, alphabet in ipairs(FAMILY_ALPHABETS) do
		local memberFile = file

		if alphabet ~= override and GameFontNormal and GameFontNormal.GetFontObjectForAlphabet then
			local gameObject = GameFontNormal:GetFontObjectForAlphabet(alphabet)

			memberFile = (gameObject and gameObject:GetFont()) or file
		end

		members[#members + 1] = {
			alphabet = alphabet,
			file = memberFile,
			height = size,
			flags = flags,
		}
	end

	return members
end

---A font object wearing this file's own face, for a dropdown row that previews the font it names.
---@param file string?
---@return table? object nil when there is no file to preview
local function PreviewFontObject(file)
	if not file or file == "" then
		return nil
	end

	local object = previewFontObjects[file]

	if object then
		return object
	end

	previewFontObjectCount = previewFontObjectCount + 1

	local name = addonName .. "FontPreview" .. previewFontObjectCount

	if CreateFontFamily then
		object = CreateFontFamily(name, FamilyMembers(file, PREVIEW_FONT_SIZE, ""))
	else
		-- Only an old client gets here, where the two-step is all there is.
		object = CreateFont(name)
		object:SetFont(file, PREVIEW_FONT_SIZE, "")
	end

	previewFontObjects[file] = object

	return object
end

---Each row previews the font it names. Menu rows are pooled, so the stock face is remembered
---the first time a row comes through here and put back on a row that previews nothing.
---@param button table
---@param value string?
local function DecorateFontRow(button, value)
	local text = button.fontString

	if not text then
		return
	end

	if button.MiniQueueTimerStockFont == nil then
		button.MiniQueueTimerStockFont = text:GetFontObject() or false
	end

	local preview = PreviewFontObject(value)

	if preview then
		text:SetFontObject(preview)
	elseif button.MiniQueueTimerStockFont then
		text:SetFontObject(button.MiniQueueTimerStockFont)
	end
end

---Refills the font lists in place from LibSharedMedia, falling back to the client's own faces
---only when nothing has registered anything at all.
local function RefillFontLists()
	wipe(fontItems)
	wipe(fontNames)

	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	-- Fetch answers one override file for every name once an addon sets a global font.
	local hash = LSM and LSM:HashTable("font")

	if hash then
		for _, name in ipairs(LSM:List("font") or {}) do
			local file = hash[name]

			if file and not fontNames[file] then
				fontItems[#fontItems + 1] = file
				fontNames[file] = name
			end
		end
	end

	if #fontItems == 0 then
		for _, file in ipairs(builtinFontItems) do
			fontItems[#fontItems + 1] = file
			fontNames[file] = builtinFontNames[file]
		end
	end
end

---Runs the list refresh once at the end of the frame however many times it is asked for in one,
---since LibSharedMedia fires once per registered entry and a media pack registers its whole set
---inside a single frame.
local function QueueFontListsChanged()
	if fontsRefreshQueued then
		return
	end

	fontsRefreshQueued = true

	C_Timer.After(0, function()
		fontsRefreshQueued = false
		RefillFontLists()

		if fontPathDd then
			fontPathDd:MiniRefresh()
		end
	end)
end

---Fonts keep arriving for as long as media addons keep loading, which is routinely after this
---panel was built.
local function EnsureFontMediaSubscription()
	if fontsMediaSubscribed then
		return
	end

	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

	if not LSM or not LSM.RegisterCallback then
		return
	end

	fontsMediaSubscribed = true

	LSM.RegisterCallback(addon, "LibSharedMedia_Registered", QueueFontListsChanged)
end

local function BuildContent(panel)
	-- A styled button clashes with the stock Blizzard art around it in the settings screen.
	mini:SetCustomStyling(true, { Button = false })

	local db = addon.db
	local gap = 12
	local insetX = 16

	RefillFontLists()

	local header = mini:PanelHeader({
		Parent = panel,
		Description = "Shows how long you've been in the queue, and the estimated wait.",
		Test = {
			OnClick = function()
				if addon.SetTestMode then
					addon.SetTestMode(not addon.IsTestMode())
				end
			end,
		},
		Reset = {
			OnAccept = function()
				mini:ResetSavedVars(addon.dbDefaults)
				addon:Refresh()
			end,
		},
	})

	local fontDiv = mini:Divider({ Parent = panel, Text = "Font" })
	fontDiv:SetPoint("TOPLEFT", header.Anchor, "BOTTOMLEFT", 0, -gap)
	fontDiv:SetPoint("RIGHT", panel, "RIGHT", -insetX, 0)

	local fontPathLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fontPathLabel:SetText("Font")
	fontPathLabel:SetPoint("TOPLEFT", fontDiv, "BOTTOMLEFT", 0, -gap)

	fontPathDd = mini:Dropdown({
		Parent = panel,
		Items = fontItems,
		GetValue = function() return db.FontPath end,
		SetValue = function(v)
			db.FontPath = v
			addon:Refresh()
		end,
		GetText = function(v) return fontNames[v] or v end,
		DecorateItem = DecorateFontRow,
	})
	fontPathDd:SetPoint("TOPLEFT", fontPathLabel, "BOTTOMLEFT", 0, -4)
	fontPathDd:SetWidth(240)

	EnsureFontMediaSubscription()

	local fontFlagsLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
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

	local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	colorLabel:SetText("Font Colour")
	-- The slider's min/max numbers sit below its own frame, so a single gap crowds them.
	colorLabel:SetPoint("TOPLEFT", sizeResult.Slider, "BOTTOMLEFT", 0, -gap * 2)

	local colorBtn = mini:ColorSwatch({
		Parent = panel,
		Tooltip = "Click to change the font colour.",
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

	local textDiv = mini:Divider({ Parent = panel, Text = "Text" })
	textDiv:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -gap)
	textDiv:SetPoint("RIGHT", fontDiv, "RIGHT", 0, 0)

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
	-- The flattened field's border bleeds ~5px left of the box's own frame, so a 4px nudge
	-- lines its visible left edge up with the label above it.
	queueBox:SetPoint("TOPLEFT", queueLabel, "BOTTOMLEFT", 4, -4)

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
	-- queueBox sits 4px right of queueLabel, so the same 4px is backed out here to keep
	-- estLabel under queueLabel rather than under queueBox.
	estLabel:SetPoint("TOPLEFT", queueBox, "BOTTOMLEFT", -4, -gap)
	estBox:SetPoint("TOPLEFT", estLabel, "BOTTOMLEFT", 4, -4)
end

mini:WaitForAddonLoad(function()
	local panel = CreateFrame("Frame")
	panel.name = "MiniQueueTimer"

	BuildContent(panel)
	addon.ConfigPanel = panel

	panel:HookScript("OnShow", function()
		if panel.MiniRefresh then
			panel:MiniRefresh()
		end
	end)

	local category = mini:AddCategory(panel)
	mini:RegisterSlashCommand(category, panel, { "/mqt", "/miniqueuetimer", "/miniqt" })
end)
