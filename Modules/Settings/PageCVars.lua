local _, ns = ...

-- The "Graphics & game" page: the game settings (CVars) of the profile with
-- readable names and controls (CVarInfo.lua), your own changes on top of
-- them, the raid variants and a switch that makes them follow the normal
-- values. Changes go into StevioUIConfig.cvars and are applied at once.

local K = ns.PlayersKit
local C = ns.SettingsControls
local Info = ns.CVarInfo
local Meta = ns.SettingsMeta
local UI = ns.SettingsUI
local Window = ns.SettingsWindow
local config = ns.config.settings
local T = ns.T

local CARD_PAD = 16
local SOURCE_WIDTH = 60

local FILTERS = {
	{ "all", { "All", "Alle" } },
	{ "own", { "Own", "Eigene" } },
	{ "graphics", { "Graphics", "Grafik" } },
	{ "game", { "Game", "Spiel" } },
	{ "accessibility", { "Accessibility", "Barrierefreiheit" } },
	{ "other", { "Other", "Weitere" } },
}

local state = { filter = "all", query = "" }

local MIRROR_ITEM = {
	path = { "config", "settings", "mirrorRaidCVars" },
	label = (ns.ConfigLabel("mirrorRaidCVars")),
	meta = { live = true },
	control = "switch",
}

local function ProfileCVars()
	return config.profile.cvars or {}
end

local SetCVarOverride = ns.SettingsUI.SetCVarOverride

-- The pseudo item a control gets for a CVar: its kind and range.
local function ControlItem(info)
	if not info then
		return "text", { meta = {}, control = "text" }
	end
	local meta = {
		min = info.min,
		max = info.max,
		step = info.step,
		unit = info.unit,
		percent = info.percent,
		options = info.options,
	}
	return info.control, { meta = meta, control = info.control }
end

-- A CVar value as the page writes it ("Level 2", "on", "50 %").
local function ValueText(info, value)
	if value == nil then
		return "–"
	end
	if not info then
		return value
	end
	if info.control == "switch" then
		return Meta.FormatValue(Info.FromCVar(info, value), {})
	elseif info.control == "select" then
		return Meta.OptionLabel(info.options, value) or value
	elseif info.control == "slider" then
		return Meta.FormatValue(tonumber(value) or 0, { percent = info.percent, unit = info.unit })
	end
	return value
end

-- Rows ------------------------------------------------------------------------------------

local function CreateRow(parent, kind)
	local row = CreateFrame("Frame", nil, parent)
	row.line = K.Texture(row, "BACKGROUND", 1, 1, 1, 0.04)
	row.line:SetHeight(1)
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.dot = K.Circle(row, "ARTWORK")
	row.dot:SetSize(5, 5)
	row.name = K.Text(row, 12, "textStrong")
	row.technical = K.Text(row, 10, "textFaint")
	row.help = K.Text(row, 11, "textMuted")
	row.help:SetWordWrap(true)
	row.profile = K.Text(row, 10, "textFaint")
	row.reset = C.Link(row, T("Back to the profile", "Auf Profil zurücksetzen"), function()
		SetCVarOverride(row.cvar, nil)
	end)
	row.source = K.Text(row, 10, "textFaint", "RIGHT")
	row.source:SetWidth(SOURCE_WIDTH)
	row.control = C.Create(kind, row)
	row.control.onChange = function(value)
		SetCVarOverride(row.cvar, Info.ToCVar(value))
	end
	return row
end

-- Fills a row and returns its height.
local function FillRow(row, data, width, technical)
	row.cvar = data.name
	local info = data.info
	local label = info and T(info.name[1], info.name[2]) or data.name
	if data.raidOf then
		label = ("%s (%s)"):format(label, T("raid", "Schlachtzug"))
	end
	local textWidth = width - C.CONTROL_WIDTH - SOURCE_WIDTH - 40
	local y = 12
	row.dot:SetVertexColor(K.RGB(data.own and "accent" or "textFaint"))
	row.name:ClearAllPoints()
	row.name:SetPoint("TOPLEFT", 12, -y)
	row.name:SetText(label)
	row.dot:ClearAllPoints()
	row.dot:SetPoint("RIGHT", row.name, "LEFT", -6, 0)
	row.technical:ClearAllPoints()
	row.technical:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
	row.technical:SetText(data.name)
	row.technical:SetShown(technical and info ~= nil)
	y = y + 16
	local help = info and T(info.help[1], info.help[2])
	row.help:SetShown(help ~= nil)
	if help then
		row.help:ClearAllPoints()
		row.help:SetPoint("TOPLEFT", 12, -y)
		row.help:SetWidth(textWidth)
		row.help:SetText(help)
		y = y + row.help:GetStringHeight() + 2
	end
	local deviates = data.own and data.profileValue ~= nil
	row.profile:SetShown(data.own)
	row.reset:SetShown(data.own)
	if data.own then
		row.profile:ClearAllPoints()
		row.profile:SetPoint("TOPLEFT", 12, -(y + 3))
		row.profile:SetText(
			deviates and ("%s %s"):format(T("Profile:", "Profil:"), ValueText(info, data.profileValue))
				or T("Not in the profile", "Nicht im Profil")
		)
		row.reset:ClearAllPoints()
		row.reset:SetPoint("LEFT", row.profile, "RIGHT", 8, 0)
		row.reset:SetLabel(
			deviates and T("Back to the profile", "Auf Profil zurücksetzen") or T("Remove", "Entfernen")
		)
		y = y + 18
	end
	y = y + 12

	local _, item = ControlItem(info)
	local value = data.value
	if info then
		value = Info.FromCVar(info, value)
	end
	row.control:Set(item, value)
	local height = math.max(y, (row.control.height or 24) + 24)
	row.source:ClearAllPoints()
	row.source:SetPoint("RIGHT", row, "TOPRIGHT", 0, -height / 2)
	row.source:SetText(data.own and T("Own", "Eigene") or T("Profile", "Profil"))
	row.source:SetTextColor(K.RGB(data.own and "accent" or "textFaint"))
	row.control:ClearAllPoints()
	row.control:SetPoint("RIGHT", row.source, "LEFT", -16, 0)
	row:SetHeight(height)
	return height
end

-- Page ------------------------------------------------------------------------------------

local function CreateCard(parent)
	local card = K.Box(parent, K.CardColors())
	card.title = K.Text(card, 13, "textStrong")
	card.title:SetPoint("TOPLEFT", CARD_PAD, -14)
	card.subtitle = K.Text(card, 11, "textMuted")
	card.subtitle:SetPoint("LEFT", card.title, "RIGHT", 8, 0)
	card.rows = {}
	function card:Begin()
		self.used = {}
	end
	function card:Row(kind)
		self.rows[kind] = self.rows[kind] or {}
		local index = (self.used[kind] or 0) + 1
		self.used[kind] = index
		local row = self.rows[kind][index]
		if not row then
			row = CreateRow(self, kind)
			self.rows[kind][index] = row
		end
		row:Show()
		return row
	end
	function card:Finish()
		for kind, rows in pairs(self.rows) do
			for index = (self.used[kind] or 0) + 1, #rows do
				rows[index]:Hide()
			end
		end
	end
	return card
end

-- The switch that makes the raid variants follow the normal values.
local function CreateMirror(parent)
	local box = CreateFrame("Frame", nil, parent)
	box:SetHeight(48)
	box.switch = C.Switch(box)
	box.switch:SetPoint("LEFT", 0, 0)
	box.switch.onChange = function(on)
		UI.Set(MIRROR_ITEM, on)
		ns.ApplyOverridesNow()
	end
	box.title = K.Text(box, 12, "textStrong")
	box.title:SetPoint("TOPLEFT", 48, -8)
	box.title:SetText(MIRROR_ITEM.label)
	box.text = K.Text(box, 11, "textMuted")
	box.text:SetPoint("TOPLEFT", box.title, "BOTTOMLEFT", 0, -4)
	return box
end

local function Create(parent)
	local page = CreateFrame("Frame", nil, parent)
	page.crumb = K.Text(page, 10, "textMuted")
	page.crumb:SetPoint("TOPLEFT")
	page.crumb:SetText(T("System ›", "System ›"))
	page.title = K.Text(page, 22, "textStrong")
	page.title:SetPoint("TOPLEFT", 0, -16)
	page.title:SetText(T("Graphics & game", "Grafik & Spiel"))
	page.description = K.Text(page, 12, "text")
	page.description:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
	page.description:SetWordWrap(true)
	page.description:SetText(
		T(
			"Game settings stevio-ui sets at login. What you change here or in Blizzard's options is kept and wins. The graphics API and resolution belong to the computer and are never taken over.",
			"Spieleinstellungen, die stevio-ui beim Login setzt. Was du hier oder in Blizzards Optionen änderst, bleibt erhalten und hat Vorrang. Grafik-Schnittstelle und Auflösung gehören zum Rechner und werden nie übernommen."
		)
	)
	page.search = K.Input(page, T("Search name or CVar …", "Name oder CVar suchen …"), function(text)
		state.query = text
		Window.Render()
	end, 28)
	page.search:SetWidth(220)
	page.chips = {}
	for index, entry in ipairs(FILTERS) do
		local chip = K.Chip(page, 22)
		chip.filter = entry[1]
		chip:SetScript("OnClick", function(self)
			state.filter = self.filter
			Window.Render()
		end)
		page.chips[index] = chip
	end
	page.technical = C.Switch(page)
	page.technical.onChange = function(on)
		UI.SavedState().technicalNames = on
		Window.Render()
	end
	page.technicalLabel = K.Text(page, 11, "textMuted", "RIGHT")
	page.technicalLabel:SetText(T("Technical names", "Technische Namen"))
	page.technicalLabel:SetPoint("RIGHT", page.technical, "LEFT", -8, 0)
	page.cards = K.Pool(function()
		return CreateCard(page)
	end)
	page.mirror = CreateMirror(page)
	page.empty = K.Text(page, 12, "textMuted")
	page.empty:SetText(T("Nothing fits this filter.", "Nichts passt zu diesem Filter."))
	return page
end

local function Render(page, filter, width)
	if filter and filter ~= state.lastArg then
		state.filter = filter
	end
	state.lastArg = filter
	page.description:SetWidth(width - 120)
	local y = 16 + 30 + page.description:GetStringHeight() + 18

	local technical = UI.SavedState().technicalNames == true
	local mirror = config.mirrorRaidCVars == true
	local groups, counts = Info.Rows(ProfileCVars(), StevioUIConfig.cvars, {
		isIgnored = ns.IsIgnoredCVar,
		mirror = mirror,
		filter = state.filter,
		query = state.query,
	})

	page.search:ClearAllPoints()
	page.search:SetPoint("TOPLEFT", 0, -y)
	local x = 232
	for index, chip in ipairs(page.chips) do
		local entry = FILTERS[index]
		local count = counts[entry[1]] or 0
		chip:SetShown(entry[1] ~= "other" or count > 0)
		chip:SetChip(T(entry[2][1], entry[2][2]), count, state.filter == entry[1])
		chip:ClearAllPoints()
		chip:SetPoint("LEFT", page, "TOPLEFT", x, -y - 14)
		if chip:IsShown() then
			x = x + chip:GetWidth() + 6
		end
	end
	page.technical:ClearAllPoints()
	page.technical:SetPoint("RIGHT", page, "TOPRIGHT", 0, -y - 14)
	page.technical:SetOn(technical)
	y = y + 28 + 18

	local raidCount = Info.RaidCount(ProfileCVars(), StevioUIConfig.cvars)
	local showMirror = raidCount > 0 and (state.filter == "all" or state.filter == "graphics") and state.query == ""
	local rowWidth = width - 2 * CARD_PAD
	local cards = 0
	page.mirror:Hide()
	for _, group in ipairs(groups) do
		cards = cards + 1
		local card = page.cards:Get(cards)
		card.title:SetText(T(group.group.title[1], group.group.title[2]))
		card.subtitle:SetText(group.group.subtitle and T(group.group.subtitle[1], group.group.subtitle[2]) or "")
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", 0, -y)
		card:SetWidth(width)
		card:Begin()
		local rowY = 40
		for _, data in ipairs(group.rows) do
			local kind = ControlItem(data.info)
			local row = card:Row(kind)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", CARD_PAD, -rowY)
			row:SetWidth(rowWidth)
			rowY = rowY + FillRow(row, data, rowWidth, technical)
		end
		card:Finish()
		-- The raid switch closes the graphics card.
		if group.key == "graphics" and showMirror then
			page.mirror:SetParent(card)
			page.mirror:ClearAllPoints()
			page.mirror:SetPoint("TOPLEFT", CARD_PAD, -(rowY + 8))
			page.mirror:SetPoint("RIGHT", -CARD_PAD, 0)
			page.mirror:Show()
			rowY = rowY + 56
		end
		card:SetHeight(rowY + 10)
		y = y + rowY + 10 + 12
	end
	if showMirror and not page.mirror:IsShown() then
		-- No graphics card (everything filtered): the switch stands alone.
		page.mirror:SetParent(page)
		page.mirror:ClearAllPoints()
		page.mirror:SetPoint("TOPLEFT", 0, -y)
		page.mirror:SetPoint("RIGHT")
		page.mirror:Show()
		y = y + 56
	end
	page.mirror.switch:SetOn(mirror)
	page.mirror.text:SetText(
		mirror
				and T(
					"%d raid values (RAID…) follow the values above.",
					"%d Schlachtzug-Werte (RAID…) folgen automatisch den Werten oben."
				):format(raidCount)
			or T(
				"Off: the raid values are listed on their own below.",
				"Aus: Die Schlachtzug-Werte stehen unten als eigene Zeilen."
			)
	)
	page.cards:HideFrom(cards + 1)
	page.empty:SetShown(cards == 0)
	if cards == 0 then
		page.empty:ClearAllPoints()
		page.empty:SetPoint("TOPLEFT", 0, -y)
		y = y + 30
	end
	page:SetHeight(y)
	return y
end

Window.RegisterPage("cvars", { Create = Create, Render = Render })
