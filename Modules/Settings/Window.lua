local _, ns = ...

-- The settings window (/sui config, /sui, the gear in the notch island):
-- a title bar, the navigation on the left (search, start, appearance, the
-- module pages by category, the system pages) and the page on the right.
-- A bar at the bottom lists the changes that wait for a reload. The pages
-- register themselves (Window.RegisterPage) from the Page*.lua files.

local K = ns.PlayersKit
local UI = ns.SettingsUI
local Pages = ns.ConfigPages
local T = ns.T

local Window = {}
ns.SettingsWindow = Window

local NAME = "StevioUI_Settings"
local WIDTH, HEIGHT = 1150, 860
local TITLE_HEIGHT = 52
local NAV_WIDTH = 260
local NAV_ROW = 26
local NAV_HEADER = 30
local PAD = 32
local RELOAD_HEIGHT = 52

local frame
-- page: the shown page's key, arg: what it shows (a module key), search: the
-- query in the navigation's search box.
local state = { page = "start", search = "" }
Window.state = state

-- Pages ---------------------------------------------------------------------

-- key -> { Create(parent) -> frame, Render(frame, arg, width) -> height }
local pageTypes = {}

function Window.RegisterPage(key, pageType)
	pageTypes[key] = pageType
end

-- Navigation ------------------------------------------------------------------

-- The entries of the navigation in order: { kind = "page" | "header", page,
-- arg, label, count, off }.
local function NavEntries()
	local entries = {
		{ kind = "page", page = "start", label = T("Start", "Start") },
		{ kind = "page", page = "module", arg = "style", label = Pages.Title(Pages.STYLE) },
	}
	for _, category in ipairs(Pages.CATEGORIES) do
		local modules = category.key == "system" and {} or Pages.InCategory(category.key)
		entries[#entries + 1] = { kind = "header", label = Pages.CategoryTitle(category.key) }
		for _, module in ipairs(modules) do
			entries[#entries + 1] = {
				kind = "page",
				page = "module",
				arg = module[1],
				label = Pages.Title(module),
				count = UI.ChangedCount(module),
				off = not UI.IsEnabled(module[1]),
			}
		end
		if category.key == "system" then
			local bindings, cvars = 0, 0
			for _ in pairs(StevioUIConfig.bindings) do
				bindings = bindings + 1
			end
			for _ in pairs(StevioUIConfig.cvars) do
				cvars = cvars + 1
			end
			entries[#entries + 1] = {
				kind = "page",
				page = "bindings",
				label = T("Keybindings", "Tastenbelegung"),
				count = bindings,
			}
			entries[#entries + 1] = {
				kind = "page",
				page = "cvars",
				label = T("Graphics & game", "Grafik & Spiel"),
				count = cvars,
			}
			entries[#entries + 1] = {
				kind = "page",
				page = "profile",
				label = T("Profile & backup", "Profil & Sicherung"),
				count = UI.ChangedCount(Pages.Module("settings")),
			}
		end
	end
	return entries
end

local function IsCurrent(entry)
	if state.search ~= "" then
		return false
	end
	return entry.page == state.page and entry.arg == state.arg
end

local function CreateNavRow(parent)
	local row = CreateFrame("Button", nil, parent)
	row:SetHeight(NAV_ROW)
	row.selected = K.Texture(row, "BACKGROUND", K.RGB("selected"))
	row.selected:SetAllPoints()
	row.stripe = K.Texture(row, "ARTWORK", K.RGB("accent"))
	row.stripe:SetPoint("TOPLEFT")
	row.stripe:SetPoint("BOTTOMLEFT")
	row.stripe:SetWidth(2)
	local hover = K.Texture(row, "HIGHLIGHT", 1, 1, 1, 0.04)
	hover:SetAllPoints()
	row.label = K.Text(row, 12, "text")
	row.label:SetPoint("LEFT", 12, 0)
	row.pill = ns.SettingsControls.Pill(row)
	row.pill:SetPoint("RIGHT", -10, 0)
	row.off = K.Text(row, 10, "textFaint", "RIGHT")
	row.off:SetPoint("RIGHT", -12, 0)
	row.off:SetText(T("off", "aus"))
	row:SetScript("OnClick", function(self)
		Window.Open(self.entry.page, self.entry.arg)
	end)
	return row
end

local function CreateNavHeader(parent)
	local header = CreateFrame("Frame", nil, parent)
	header:SetHeight(NAV_HEADER)
	header.text = K.Text(header, 10, "textFaint")
	header.text:SetPoint("BOTTOMLEFT", 12, 6)
	return header
end

local function RenderNav()
	local nav = frame.nav
	local y, rows, headers = 0, 0, 0
	for _, entry in ipairs(NavEntries()) do
		local widget
		if entry.kind == "header" then
			headers = headers + 1
			widget = nav.headers:Get(headers)
			widget.text:SetText(entry.label:upper())
		else
			rows = rows + 1
			widget = nav.rows:Get(rows)
			widget.entry = entry
			local current = IsCurrent(entry)
			widget.selected:SetShown(current)
			widget.stripe:SetShown(current)
			widget.label:SetText(entry.label)
			widget.label:SetTextColor(K.RGB(entry.off and "textFaint" or (current and "textStrong" or "text")))
			widget.off:SetShown(entry.off == true)
			local count = entry.count or 0
			widget.pill:SetShown(count > 0 and not entry.off)
			widget.pill:SetLabel(tostring(count))
		end
		widget:ClearAllPoints()
		widget:SetPoint("TOPLEFT", nav.child, "TOPLEFT", 0, -y)
		widget:SetPoint("RIGHT", nav.child, "RIGHT")
		y = y + widget:GetHeight()
	end
	nav.rows:HideFrom(rows + 1)
	nav.headers:HideFrom(headers + 1)
	nav:SetContentHeight(y + 8)
end

-- Reload bar --------------------------------------------------------------------

local MAX_NAMES = 90

local function ShortList(names)
	local text = table.concat(names, " · ")
	if #text > MAX_NAMES then
		text = text:sub(1, MAX_NAMES):gsub("[\128-\191]*$", ""):gsub("[\192-\255]$", "") .. " …"
	end
	return text
end

local function UpdateReloadBar()
	local count, names = UI.PendingChanges()
	local shown = count > 0 and not UI.reloadDismissed
	frame.reload:SetShown(shown)
	if shown then
		frame.reload.title:SetText(
			count == 1 and T("1 change takes effect after a reload", "1 Änderung wirkt nach dem Neuladen")
				or T("%d changes take effect after a reload", "%d Änderungen wirken nach dem Neuladen"):format(count)
		)
		frame.reload.names:SetText(ShortList(names))
	end
	local bottom = shown and RELOAD_HEIGHT or 0
	frame.side:SetPoint("BOTTOMLEFT", 0, bottom)
	frame.content:SetPoint("BOTTOMRIGHT", -PAD, bottom + 16)
end

local function CreateReloadBar()
	local bar = K.Box(frame, { K.RGB("selected") })
	bar:SetPoint("BOTTOMLEFT", 1, 1)
	bar:SetPoint("BOTTOMRIGHT", -1, 1)
	bar:SetHeight(RELOAD_HEIGHT - 1)
	local line = K.Texture(bar, "ARTWORK", K.RGB("accent", 0.5))
	line:SetPoint("TOPLEFT")
	line:SetPoint("TOPRIGHT")
	line:SetHeight(1)
	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(14, 14)
	icon:SetPoint("LEFT", PAD - 8, 0)
	icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
	icon:SetVertexColor(K.RGB("accent"))
	bar.title = K.Text(bar, 12, "textStrong")
	bar.title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	bar.names = K.Text(bar, 11, "textMuted")
	bar.names:SetPoint("LEFT", bar.title, "RIGHT", 12, 0)
	local now = ns.SettingsControls.Button(bar, T("Reload now", "Jetzt neu laden"), ReloadUI, 26)
	now:SetPoint("RIGHT", -PAD + 8, 0)
	now:SetActive(true)
	now:SetScript("OnLeave", function(self)
		self:SetActive(true)
		GameTooltip_Hide()
	end)
	local later = ns.SettingsControls.Button(bar, T("Later", "Später"), function()
		UI.reloadDismissed = true
		UpdateReloadBar()
	end, 26)
	later:SetPoint("RIGHT", now, "LEFT", -8, 0)
	bar.names:SetPoint("RIGHT", later, "LEFT", -12, 0)
	bar:Hide()
	frame.reload = bar
end

-- Page --------------------------------------------------------------------------

local function ContentWidth()
	return frame:GetWidth() - NAV_WIDTH - 1 - 2 * PAD - 8
end

local function PageFrame(key)
	frame.pages = frame.pages or {}
	local page = frame.pages[key]
	if not page then
		page = pageTypes[key].Create(frame.content.child)
		page:SetPoint("TOPLEFT")
		page:SetPoint("TOPRIGHT")
		frame.pages[key] = page
	end
	return page
end

local renderPending = false

function Window.Render()
	renderPending = false
	if not frame or not frame:IsShown() then
		return
	end
	local key = state.search ~= "" and "search" or state.page
	if not pageTypes[key] then
		key, state.page, state.arg = "start", "start", nil
	end
	if not pageTypes[key] then
		return
	end
	for pageKey, page in pairs(frame.pages or {}) do
		if pageKey ~= key then
			page:Hide()
		end
	end
	local page = PageFrame(key)
	page:Show()
	local arg = key == "search" and state.search or state.arg
	local ok, height = ns.SafeCall(pageTypes[key].Render, page, arg, ContentWidth())
	frame.content:SetContentHeight((ok and height or 0) + 24)
	RenderNav()
	UpdateReloadBar()
end

-- Redraws once on the next frame, however many changes come before it.
function Window.RequestRender()
	if renderPending or not frame then
		return
	end
	renderPending = true
	C_Timer.After(0, Window.Render)
end

-- Window ------------------------------------------------------------------------

local function SaveGeometry()
	local saved = UI.SavedState()
	local point, _, relativePoint, x, y = frame:GetPoint()
	saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
	saved.width, saved.height = frame:GetSize()
end

local function RestoreGeometry()
	local saved = UI.SavedState()
	frame:SetSize(saved.width or WIDTH, saved.height or HEIGHT)
	frame:ClearAllPoints()
	if saved.point then
		frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
	else
		frame:SetPoint("CENTER")
	end
end

local function CreateTitleBar()
	local bar = CreateFrame("Frame", nil, frame)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(TITLE_HEIGHT)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	bar:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		SaveGeometry()
	end)
	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetPoint("LEFT", 20, 0)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
	ns.CropIcon(icon)
	local title = K.Text(bar, 15, "textStrong")
	title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	title:SetText(T("Settings", "Einstellungen"))
	local command = K.Text(bar, 11, "textMuted")
	command:SetPoint("LEFT", title, "RIGHT", 10, -1)
	command:SetText("/sui config")
	local close = ns.CreateCloseButton(bar, 22, function()
		frame:Hide()
	end)
	close:SetPoint("RIGHT", -16, 0)
	local line = K.Texture(frame, "ARTWORK", 1, 1, 1, 0.06)
	line:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT)
	line:SetPoint("TOPRIGHT", 0, -TITLE_HEIGHT)
	line:SetHeight(1)
end

local function SetSearch(text)
	text = text or ""
	if text == state.search then
		return
	end
	state.search = text
	frame.content:ScrollTo(0)
	Window.Render()
end

-- Focuses the navigation's search box (Ctrl+F).
function Window.FocusSearch()
	if frame then
		frame.search.edit:SetFocus()
		frame.search.edit:HighlightText()
	end
end

-- Empties the search, back to the page shown before it.
function Window.ClearSearch()
	frame.search:SetText("")
	SetSearch("")
end

local function CreateSide()
	local side = CreateFrame("Frame", nil, frame)
	side:SetPoint("TOPLEFT", 0, -TITLE_HEIGHT - 1)
	side:SetPoint("BOTTOMLEFT")
	side:SetWidth(NAV_WIDTH)
	frame.side = side
	local divider = K.Texture(frame, "ARTWORK", 1, 1, 1, 0.06)
	divider:SetPoint("TOPLEFT", side, "TOPRIGHT")
	divider:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT")
	divider:SetWidth(1)

	local search = K.Input(side, T("Search settings", "Einstellungen durchsuchen"), SetSearch, 32)
	search:SetPoint("TOPLEFT", 16, -16)
	search:SetPoint("TOPRIGHT", -16, -16)
	local glass = search:CreateTexture(nil, "ARTWORK")
	glass:SetSize(14, 14)
	glass:SetPoint("LEFT", 10, 0)
	glass:SetTexture(K.ICON_SEARCH)
	local shortcut = K.Box(search, { 1, 1, 1, 0.06 }, { 1, 1, 1, 0.12 })
	shortcut:SetSize(42, 18)
	shortcut:SetPoint("RIGHT", -7, 0)
	shortcut:EnableMouse(false)
	local shortcutText = K.Text(shortcut, 10, "textMuted", "CENTER")
	shortcutText:SetPoint("CENTER")
	shortcutText:SetText(T("Ctrl F", "Strg F"))
	search.edit:SetPoint("TOPLEFT", 30, 0)
	search.edit:SetPoint("BOTTOMRIGHT", -54, 0)
	-- Escape empties the search first, then leaves the box.
	search.edit:SetScript("OnEscapePressed", function(self)
		if self:GetText() ~= "" then
			Window.ClearSearch()
		else
			self:ClearFocus()
		end
	end)
	frame.search = search

	local footer = CreateFrame("Frame", nil, side)
	footer:SetPoint("BOTTOMLEFT")
	footer:SetPoint("BOTTOMRIGHT")
	footer:SetHeight(36)
	local footerLine = K.Texture(footer, "ARTWORK", 1, 1, 1, 0.06)
	footerLine:SetPoint("TOPLEFT")
	footerLine:SetPoint("TOPRIGHT")
	footerLine:SetHeight(1)
	local version = K.Text(footer, 10, "textFaint")
	version:SetPoint("LEFT", 16, 0)
	version:SetText("stevio-ui " .. UI.Version())
	local saved = K.Text(footer, 10, "textFaint", "RIGHT")
	saved:SetPoint("RIGHT", -16, 0)
	saved:SetText(T("saved account-wide", "kontoweit gespeichert"))

	local nav = K.Scroll(side, NAV_ROW * 2)
	nav:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -8, -12)
	nav:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -16, 8)
	nav.rows = K.Pool(function()
		return CreateNavRow(nav.child)
	end)
	nav.headers = K.Pool(function()
		return CreateNavHeader(nav.child)
	end)
	frame.nav = nav
end

local function CreateContent()
	local content = K.Scroll(frame, 80)
	content:SetPoint("TOPLEFT", NAV_WIDTH + 1 + PAD, -TITLE_HEIGHT - 1 - 24)
	content:SetPoint("BOTTOMRIGHT", -PAD, 16)
	frame.content = content
end

local function CreateResizeGrip()
	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(14, 14)
	grip:SetPoint("BOTTOMRIGHT", -2, 2)
	grip:SetFrameLevel(frame:GetFrameLevel() + 20)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		frame:StopMovingOrSizing()
		SaveGeometry()
		Window.Render()
	end)
end

-- Ctrl+F (Cmd+F) searches, Escape empties the search or closes. Keys are only
-- taken out of combat, where letting them through can't be changed.
local function OnKeyDown(self, key)
	if InCombatLockdown() then
		return
	end
	local handled = true
	if key == "F" and (IsControlKeyDown() or IsMetaKeyDown()) then
		Window.FocusSearch()
	elseif key == "ESCAPE" then
		if state.search ~= "" then
			Window.ClearSearch()
		else
			self:Hide()
		end
	else
		handled = false
	end
	self:SetPropagateKeyboardInput(not handled)
end

local function CreateWindow()
	frame = CreateFrame("Frame", NAME, UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetResizeBounds(900, 600, 1600, 1200)
	frame:SetClampedToScreen(true)
	frame:Hide()
	ns.CreatePanel(frame, { color = ns.PanelColor() })
	-- Escape closes the window like any Blizzard panel (also in combat,
	-- where the window takes no keys).
	tinsert(UISpecialFrames, NAME)
	RestoreGeometry()

	CreateTitleBar()
	CreateSide()
	CreateContent()
	CreateReloadBar()
	CreateResizeGrip()

	frame:SetScript("OnShow", function(self)
		if not InCombatLockdown() then
			self:EnableKeyboard(true)
		end
		Window.Render()
	end)
	frame:SetScript("OnHide", function(self)
		if not InCombatLockdown() then
			self:EnableKeyboard(false)
		end
	end)
	frame:SetScript("OnKeyDown", OnKeyDown)
	frame:SetScript("OnSizeChanged", function()
		Window.RequestRender()
	end)
	ns.RegisterEvent("PLAYER_REGEN_DISABLED", function()
		frame:EnableKeyboard(false)
	end)
	ns.RegisterEvent("PLAYER_REGEN_ENABLED", function()
		frame:EnableKeyboard(frame:IsShown())
	end)
	UI.OnChange(Window.RequestRender)
end

-- Opens the window on a page: "start", "module" (arg: the module key, also
-- "style"), "bindings", "cvars", "profile". Without a page it keeps the last one.
function Window.Open(page, arg)
	if not frame then
		CreateWindow()
	end
	if page then
		local changed = page ~= state.page or arg ~= state.arg
		state.page, state.arg = page, arg
		if state.search ~= "" then
			frame.search:SetText("")
			state.search = ""
		end
		if changed then
			frame.content:ScrollTo(0)
		end
	end
	if frame:IsShown() then
		Window.Render()
	else
		frame:Show()
	end
end

function Window.Toggle()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		Window.Open()
	end
end

-- Scrolls the page to `offset` (a section's top).
function Window.ScrollTo(offset)
	frame.content:ScrollTo(offset)
end

function Window.IsShown()
	return frame ~= nil and frame:IsShown()
end

-- The gear in the notch island.
local function CreateNotchButton()
	if not ns.NotchButtons then
		return
	end
	-- Parked in a hidden frame until the notch island adopts it.
	local parking = CreateFrame("Frame")
	parking:Hide()
	local button = CreateFrame("Button", "StevioUI_SettingsButton", parking)
	local size = ns.config.notch.buttonSize
	button:SetSize(size, size)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Icons\\INV_Misc_Gear_01")
	ns.CropIcon(icon)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnClick", Window.Toggle)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(T("Settings", "Einstellungen"))
		GameTooltip:AddLine("/sui config", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	ns.NotchButtons.AddOwn(button, NAME)
end

function Window.Setup()
	ns.RegisterSlashCommand("config", function()
		Window.Open()
	end)
	-- /sui alone opens the window too.
	ns.RegisterSlashCommand("", function()
		Window.Open()
	end)
	ns.SafeCall(CreateNotchButton)
end
