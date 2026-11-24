local _, ns = ...

-- The start page of the settings window: welcome, the two colour themes as
-- cards, every module as a tile with its switch, the profile and backup at
-- a glance and the /sui commands.

local K = ns.PlayersKit
local C = ns.SettingsControls
local UI = ns.SettingsUI
local Pages = ns.ConfigPages
local Window = ns.SettingsWindow
local T = ns.T

local COLUMNS = 3
local TILE_HEIGHT = 66
local GAP = 12

local THEMES = {
	{
		key = "dusk",
		description = {
			"Blue-grey tinted black, old gold accent. Calm and neutral.",
			"Blaugrau getöntes Schwarz, Akzent in Altgold. Ruhig und neutral.",
		},
	},
	{
		key = "violet",
		description = {
			"Violet tinted black, a muted violet accent. A little warmer.",
			"Violett getöntes Schwarz, gedeckter violetter Akzent. Etwas wärmer.",
		},
	},
}

local FILTERS = {
	{ "all", { "All", "Alle" } },
	{ "changed", { "Changed", "Geändert" } },
	{ "off", { "Off", "Aus" } },
}

local filter = "all"

local THEME_ITEM = {
	path = { "config", "style", "theme" },
	label = T("Colour theme", "Farbschema"),
	meta = {},
	control = "text",
}

local function Card(parent)
	return K.Box(parent, K.CardColors())
end

-- A theme card: a small preview drawn in the theme's own colours, its name
-- and description; the active one has an accent frame and an "Active" pill.
local function CreateThemeCard(parent)
	local card = K.Box(parent, nil, nil, "Button")
	card:SetHeight(84)
	card.preview = K.Box(card, { 0, 0, 0, 1 }, { 0, 0, 0, 1 })
	card.preview:SetSize(104, 62)
	card.preview:SetPoint("LEFT", 12, 0)
	card.preview:EnableMouse(false)
	local p = card.preview
	p.bar = K.Texture(p, "ARTWORK")
	p.bar:SetPoint("TOPLEFT", 8, -8)
	p.bar:SetPoint("TOPRIGHT", -8, -8)
	p.bar:SetHeight(14)
	p.title = K.Texture(p, "OVERLAY")
	p.title:SetSize(34, 2)
	p.title:SetPoint("LEFT", p.bar, "LEFT", 6, 0)
	p.stripe = K.Texture(p, "ARTWORK")
	p.stripe:SetSize(2, 12)
	p.stripe:SetPoint("TOPLEFT", 8, -32)
	p.line1 = K.Texture(p, "ARTWORK")
	p.line1:SetSize(38, 2)
	p.line1:SetPoint("TOPLEFT", p.stripe, "TOPRIGHT", 4, -2)
	p.line2 = K.Texture(p, "ARTWORK")
	p.line2:SetSize(28, 2)
	p.line2:SetPoint("TOPLEFT", p.line1, "BOTTOMLEFT", 0, -4)
	p.square = K.Texture(p, "ARTWORK")
	p.square:SetSize(14, 14)
	p.square:SetPoint("BOTTOMRIGHT", -8, 6)
	card.name = K.Text(card, 13, "textStrong")
	card.name:SetPoint("TOPLEFT", card.preview, "TOPRIGHT", 14, -6)
	card.active = C.Pill(card)
	card.active:SetPoint("LEFT", card.name, "RIGHT", 8, 0)
	card.active:SetLabel(T("Active", "Aktiv"))
	card.description = K.Text(card, 11, "textMuted")
	card.description:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -6)
	card.description:SetPoint("RIGHT", -12, 0)
	card.description:SetWordWrap(true)
	card:SetScript("OnClick", function(self)
		UI.Set(THEME_ITEM, self.key)
	end)
	function card:Set(theme, active)
		self.key = theme.key
		local colors = ns.config.style.themes[theme.key]
		p.bg:SetVertexColor(unpack(colors.panel))
		p.bar:SetVertexColor(unpack(colors.cell))
		p.title:SetVertexColor(unpack(colors.textStrong))
		p.stripe:SetVertexColor(unpack(colors.accent))
		p.line1:SetVertexColor(unpack(colors.textMuted))
		p.line2:SetVertexColor(unpack(colors.textFaint))
		p.square:SetVertexColor(unpack(colors.accent))
		self.name:SetText((ns.ConfigLabel(theme.key)))
		self.description:SetText(T(theme.description[1], theme.description[2]))
		self.active:SetShown(active)
		if active then
			local accent = ns.config.style.palette.accent
			self:SetColors({ accent[1], accent[2], accent[3], 0.10 }, { accent[1], accent[2], accent[3], 0.8 })
		else
			self:SetColors({ 1, 1, 1, 0.025 }, { 1, 1, 1, 0.08 })
		end
	end
	return card
end

local function CreateTile(parent)
	local tile = Card(parent)
	tile:SetHeight(TILE_HEIGHT)
	tile.name = CreateFrame("Button", nil, tile)
	tile.name:SetPoint("TOPLEFT", 12, -10)
	tile.name:SetHeight(16)
	tile.name.text = K.Text(tile.name, 12, "textStrong")
	tile.name.text:SetPoint("LEFT")
	tile.name:SetScript("OnClick", function()
		Window.Open("module", tile.key)
	end)
	tile.name:SetScript("OnEnter", function(self)
		self.text:SetTextColor(K.RGB("accent"))
	end)
	tile.name:SetScript("OnLeave", function(self)
		self.text:SetTextColor(K.RGB(tile.off and "textFaint" or "textStrong"))
	end)
	tile.pill = C.Pill(tile)
	tile.pill:SetPoint("LEFT", tile.name, "RIGHT", 6, 0)
	tile.switch = C.Switch(tile)
	tile.switch:SetPoint("TOPRIGHT", -12, -10)
	tile.switch.onChange = function(on)
		UI.SetEnabled(tile.key, on)
	end
	tile.description = K.Text(tile, 10, "textMuted")
	tile.description:SetPoint("TOPLEFT", 12, -30)
	tile.description:SetPoint("RIGHT", -12, 0)
	tile.description:SetWordWrap(true)
	tile.description:SetMaxLines(2)
	return tile
end

local function ChangesText(count)
	if count == 1 then
		return T("1 change", "1 Änderung")
	end
	return T("%d changes", "%d Änderungen"):format(count)
end

-- The modules with tiles: all but the profile, which can't be turned off.
local function TileModules()
	local list = {}
	for _, module in ipairs(Pages.MODULES) do
		if module[1] ~= "settings" then
			list[#list + 1] = module
		end
	end
	return list
end

local function Create(parent)
	local page = CreateFrame("Frame", nil, parent)

	page.title = K.Text(page, 22, "textStrong")
	page.title:SetPoint("TOPLEFT")
	page.title:SetText(T("Welcome to stevio-ui", "Willkommen bei stevio-ui"))
	page.intro = K.Text(page, 12, "text")
	page.intro:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
	page.intro:SetWordWrap(true)
	page.helpButton = C.Button(page, T("Commands & help", "Befehle & Hilfe"), function()
		Window.ScrollTo(page.commandsTop or 0)
	end, 26)
	page.helpButton:SetPoint("TOPRIGHT", 0, 0)

	page.themes = Card(page)
	page.themes.title = K.Text(page.themes, 14, "textStrong")
	page.themes.title:SetPoint("TOPLEFT", 16, -16)
	page.themes.title:SetText(T("Colour theme", "Farbschema"))
	page.themes.subtitle = K.Text(page.themes, 11, "textMuted")
	page.themes.subtitle:SetPoint("LEFT", page.themes.title, "RIGHT", 10, 0)
	page.themes.subtitle:SetText(
		T(
			"Sets surfaces, text and the accent colour of every element.",
			"Bestimmt Flächen, Schrift und die Akzentfarbe aller Elemente."
		)
	)
	page.themeCards = {}
	for index in ipairs(THEMES) do
		page.themeCards[index] = CreateThemeCard(page.themes)
	end
	page.themes.note = K.Text(page.themes, 10, "textMuted")
	page.themes.note:SetPoint("BOTTOMLEFT", 16, 14)
	page.themes.note:SetText(T("Single colours can be changed under", "Einzelne Farben lassen sich unter"))
	page.themes.link = C.Link(page.themes, Pages.Title(Pages.STYLE), function()
		Window.Open("module", "style")
	end)
	page.themes.link:SetPoint("LEFT", page.themes.note, "RIGHT", 4, 0)
	page.themes.after = K.Text(page.themes, 10, "textMuted")
	page.themes.after:SetPoint("LEFT", page.themes.link, "RIGHT", 4, 0)
	page.themes.after:SetText(T(".", "anpassen."))

	page.modulesTitle = K.Text(page, 15, "textStrong")
	page.modulesTitle:SetText(T("Modules", "Module"))
	page.modulesInfo = K.Text(page, 11, "textMuted")
	page.modulesInfo:SetPoint("LEFT", page.modulesTitle, "RIGHT", 10, 0)
	page.chips = {}
	for index, entry in ipairs(FILTERS) do
		local chip = K.Chip(page, 22)
		chip.filter = entry[1]
		chip:SetScript("OnClick", function(self)
			filter = self.filter
			Window.Render()
		end)
		page.chips[index] = chip
	end
	page.tiles = K.Pool(function()
		return CreateTile(page)
	end)
	page.empty = K.Text(page, 11, "textMuted")
	page.empty:SetText(T("No module fits this filter.", "Kein Modul passt zu diesem Filter."))

	page.status = Card(page)
	page.status.icon = page.status:CreateTexture(nil, "ARTWORK")
	page.status.icon:SetSize(26, 26)
	page.status.icon:SetPoint("LEFT", 16, 0)
	page.status.title = K.Text(page.status, 13, "textStrong")
	page.status.title:SetPoint("TOPLEFT", page.status.icon, "TOPRIGHT", 14, 4)
	page.status.text = K.Text(page.status, 11, "textMuted")
	page.status.text:SetPoint("TOPLEFT", page.status.title, "BOTTOMLEFT", 0, -4)
	page.status.text:SetWordWrap(true)
	page.status.restore = C.Button(page.status, T("Restore backup", "Sicherung wiederherstellen"), function()
		Window.Open("profile")
	end, 26)
	page.status.restore:SetPoint("RIGHT", -16, 0)
	page.status.export = C.Button(page.status, T("Export", "Exportieren"), function()
		Window.Open("profile", "share")
	end, 26)
	page.status.export:SetPoint("RIGHT", page.status.restore, "LEFT", -8, 0)
	page.status.text:SetPoint("RIGHT", page.status.export, "LEFT", -16, 0)

	page.commands = Card(page)
	page.commands.title = K.Text(page.commands, 14, "textStrong")
	page.commands.title:SetPoint("TOPLEFT", 16, -16)
	page.commands.title:SetText(T("Commands & help", "Befehle & Hilfe"))
	page.commands.lines = {}
	for index, line in ipairs(ns.SettingsHelp.Lines()) do
		local command = K.Text(page.commands, 11, "accent")
		command:SetPoint("TOPLEFT", 16, -44 - (index - 1) * 20)
		command:SetText(line.command)
		local text = K.Text(page.commands, 11, "text")
		text:SetPoint("TOPLEFT", 250, -44 - (index - 1) * 20)
		text:SetPoint("RIGHT", -16, 0)
		text:SetText(line.text)
		page.commands.lines[index] = text
	end
	page.commands:SetHeight(44 + #page.commands.lines * 20 + 12)
	return page
end

local function Render(page, _, width)
	page.intro:SetWidth(width - page.helpButton:GetWidth() - 24)
	page.intro:SetText(
		T(
			"A lean interface for WoW Forever. Every change here is saved account-wide right away and takes effect after the next reload. Version %s.",
			"Ein schlankes Interface für WoW Forever. Jede Änderung hier wird sofort kontoweit gespeichert und wirkt nach dem nächsten Neuladen. Version %s."
		):format(UI.Version())
	)
	local y = 36 + page.intro:GetStringHeight() + 24

	-- Theme cards side by side.
	page.themes:ClearAllPoints()
	page.themes:SetPoint("TOPLEFT", 0, -y)
	page.themes:SetPoint("RIGHT")
	local cardWidth = (width - 32 - GAP) / 2
	local theme = ns.config.style.theme
	for index, card in ipairs(page.themeCards) do
		card:ClearAllPoints()
		card:SetPoint("TOPLEFT", 16 + (index - 1) * (cardWidth + GAP), -46)
		card:SetWidth(cardWidth)
		card:Set(THEMES[index], THEMES[index].key == theme)
	end
	page.themes:SetHeight(46 + 84 + 40)
	y = y + page.themes:GetHeight() + 28

	-- Module tiles.
	local modules = TileModules()
	local active = 0
	for _, module in ipairs(modules) do
		if UI.IsEnabled(module[1]) then
			active = active + 1
		end
	end
	page.modulesTitle:ClearAllPoints()
	page.modulesTitle:SetPoint("TOPLEFT", 0, -y)
	page.modulesInfo:SetText(
		T(
			"%d of %d on · Modules that are off don't load at all.",
			"%d von %d aktiv · Ausgeschaltete Module laden gar nicht erst."
		):format(active, #modules)
	)
	local x = width
	for index = #page.chips, 1, -1 do
		local chip = page.chips[index]
		local entry = FILTERS[index]
		chip:SetChip(T(entry[2][1], entry[2][2]), nil, filter == entry[1])
		chip:ClearAllPoints()
		chip:SetPoint("TOPRIGHT", page, "TOPLEFT", x, -y + 3)
		x = x - chip:GetWidth() - 6
	end
	y = y + 32

	local tileWidth = (width - (COLUMNS - 1) * GAP) / COLUMNS
	local shown = 0
	for _, module in ipairs(modules) do
		local key = module[1]
		local count = UI.ChangedCount(module)
		local off = not UI.IsEnabled(key)
		local visible = filter == "all" or (filter == "changed" and count > 0) or (filter == "off" and off)
		if visible then
			shown = shown + 1
			local tile = page.tiles:Get(shown)
			tile.key, tile.off = key, off
			tile.name.text:SetText(Pages.Title(module))
			tile.name.text:SetTextColor(K.RGB(off and "textFaint" or "textStrong"))
			tile.name:SetWidth(tile.name.text:GetStringWidth())
			tile.pill:SetShown(count > 0)
			tile.pill:SetLabel(ChangesText(count))
			tile.switch:SetOn(not off)
			tile.description:SetText(Pages.Description(module))
			tile.description:SetTextColor(K.RGB(off and "textFaint" or "textMuted"))
			local column = (shown - 1) % COLUMNS
			local line = math.floor((shown - 1) / COLUMNS)
			tile:ClearAllPoints()
			tile:SetPoint("TOPLEFT", column * (tileWidth + GAP), -(y + line * (TILE_HEIGHT + GAP)))
			tile:SetWidth(tileWidth)
		end
	end
	page.tiles:HideFrom(shown + 1)
	page.empty:SetShown(shown == 0)
	if shown == 0 then
		page.empty:ClearAllPoints()
		page.empty:SetPoint("TOPLEFT", 0, -y)
		y = y + 30
	else
		y = y + math.ceil(shown / COLUMNS) * (TILE_HEIGHT + GAP) + 16
	end

	-- Profile and backup.
	local state = StevioUIState or {}
	local hasBackup = state.backup ~= nil
	page.status:ClearAllPoints()
	page.status:SetPoint("TOPLEFT", 0, -y)
	page.status:SetPoint("RIGHT")
	page.status:SetHeight(72)
	page.status.icon:SetTexture(hasBackup and "Interface\\RaidFrame\\ReadyCheck-Ready" or K.ICON_WARNING)
	page.status.title:SetText(
		hasBackup and T("Profile active · backup present", "Profil aktiv · Sicherung vorhanden")
			or T("Profile active · no backup", "Profil aktiv · keine Sicherung")
	)
	page.status.text:SetText(
		T(
			"stevio-ui sets keybindings, action bars and game settings at login. Your previous settings are backed up and can be brought back any time.",
			"stevio-ui setzt beim Login Tastenbelegung, Aktionsleisten und Spieleinstellungen. Deine vorherigen Einstellungen sind gesichert und lassen sich jederzeit zurückholen."
		)
	)
	page.status.restore:SetShown(hasBackup)
	y = y + 72 + 24

	page.commands:ClearAllPoints()
	page.commands:SetPoint("TOPLEFT", 0, -y)
	page.commands:SetPoint("RIGHT")
	page.commandsTop = y
	y = y + page.commands:GetHeight()

	page:SetHeight(y)
	return y
end

Window.RegisterPage("start", { Create = Create, Render = Render })
