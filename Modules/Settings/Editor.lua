local _, ns = ...

-- Generated editor for the config: a page walks the Config.lua / Layout.lua
-- tables below its paths and shows a row per value. Booleans get a checkbox,
-- numbers and texts an input box, colors a swatch with Blizzard's color
-- picker; tables are collapsible headers, lists can grow (a copy of the last
-- entry) and shrink. Every change goes into the live config at once and is
-- saved as an override (see Core/Overrides.lua); it takes effect on reload.

local Overrides = ns.Overrides
local Model = ns.EditorModel

local Editor = {}
ns.ConfigEditor = Editor

local ROW_HEIGHT = 24
local INDENT = 16
local CONTROL_X = 300
local OVERRIDDEN_COLOR = { 1, 0.82, 0 }
local DEFAULT_COLOR = { 0.9, 0.9, 0.9 }
local HEADING_COLOR = { 0.6, 0.8, 1 }

local T = ns.T

local HIDDEN = Model.HIDDEN
local IsColor = Model.IsColor
local SortedKeys = Model.SortedKeys

local function IsOverridden(path)
	return Overrides.OverriddenAt(StevioUIConfig.values, path) ~= nil
end

-- Saves the live value at `path` as an override and redraws the page.
local function Commit(page, path)
	Overrides.Record(StevioUIConfig.values, ns.overrideDefaults, ns.overrideRoots, path)
	page.reloadHint:Show()
	page:Render()
end

local function SetValue(page, path, value)
	if Overrides.Equal(Overrides.Get(ns.overrideRoots, path), value) then
		return
	end
	Overrides.Put(ns.overrideRoots, path, value)
	Commit(page, path)
end

-- Row widgets ---------------------------------------------------------------

-- Widgets the options panel's own pages (Panel.lua) share.
function Editor.CreateButton(parent, text, width, height)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, height)
	button:SetText(text)
	return button
end

-- An input box that gives up the focus on Enter and Escape.
function Editor.CreateInput(parent, width)
	local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	input:SetSize(width, 20)
	input:SetAutoFocus(false)
	input:SetScript("OnEnterPressed", input.ClearFocus)
	input:SetScript("OnEscapePressed", input.ClearFocus)
	return input
end

local function CreateSmallButton(parent, text, width)
	return Editor.CreateButton(parent, text, width or 22, 20)
end

-- Picker values are rounded, so confirming an untouched color saves nothing.
local function Round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

local function OpenColorPicker(page, path, color)
	local previous = { unpack(color) }
	-- The picker reports a color while it is being set up; only later ones count.
	local ready = false
	local function Apply()
		if not ready then
			return
		end
		local r, g, b = ColorPickerFrame:GetColorRGB()
		local value = { Round(r), Round(g), Round(b) }
		if #previous == 4 then
			value[4] = Round(ColorPickerFrame:GetColorAlpha())
		end
		for i, component in ipairs(value) do
			if math.abs(component - previous[i]) < 0.001 then
				value[i] = previous[i]
			end
		end
		SetValue(page, path, value)
	end
	ColorPickerFrame:SetupColorPickerAndShow({
		r = color[1],
		g = color[2],
		b = color[3],
		opacity = color[4],
		hasOpacity = #color == 4,
		swatchFunc = Apply,
		opacityFunc = Apply,
		cancelFunc = function()
			SetValue(page, path, previous)
		end,
	})
	ready = true
end

local function CreateRow(page)
	local row = CreateFrame("Frame", nil, page.content)
	row:SetHeight(ROW_HEIGHT)

	-- The label doubles as the collapse toggle of table headers.
	row.toggle = CreateFrame("Button", nil, row)
	row.toggle:SetHeight(ROW_HEIGHT)
	row.label = row.toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.label:SetPoint("LEFT")
	row.label:SetJustifyH("LEFT")
	row.toggle:SetScript("OnClick", function()
		if row.onToggle then
			row.onToggle()
		end
	end)
	row.toggle:SetScript("OnEnter", function(self)
		if row.help then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(row.help, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	row.toggle:SetScript("OnLeave", GameTooltip_Hide)

	row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	row.check:SetSize(24, 24)
	row.check:SetPoint("LEFT", CONTROL_X, 0)
	row.check:SetScript("OnClick", function(self)
		SetValue(page, row.path, self:GetChecked() and true or false)
	end)

	row.input = Editor.CreateInput(row, 180)
	row.input:SetPoint("LEFT", CONTROL_X + 6, 0)
	local function CommitInput(self)
		local text = self:GetText()
		local value = text
		if row.valueType == "number" then
			value = tonumber(text)
			if not value then
				self:SetText(tostring(Overrides.Get(ns.overrideRoots, row.path)))
				return
			end
		end
		SetValue(page, row.path, value)
	end
	row.input:SetScript("OnEditFocusLost", CommitInput)
	-- Escape also puts the current value back.
	row.input:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(Overrides.Get(ns.overrideRoots, row.path)))
		self:ClearFocus()
	end)

	row.swatch = CreateFrame("Button", nil, row)
	row.swatch:SetSize(20, 20)
	row.swatch:SetPoint("LEFT", CONTROL_X + 2, 0)
	row.swatch.color = row.swatch:CreateTexture(nil, "ARTWORK")
	row.swatch.color:SetAllPoints()
	ns.CreateBorder(row.swatch)
	row.swatch:SetScript("OnClick", function()
		OpenColorPicker(page, row.path, Overrides.Get(ns.overrideRoots, row.path))
	end)

	row.add = CreateSmallButton(row, "+")
	row.remove = CreateSmallButton(row, "x")
	return row
end

local function AcquireRow(page)
	page.used = page.used + 1
	local row = page.rows[page.used] or CreateRow(page)
	page.rows[page.used] = row
	row:ClearAllPoints()
	row:SetPoint("TOPLEFT", 0, -(page.used - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT", page.content, "RIGHT")
	for _, widget in ipairs({ row.check, row.input, row.swatch, row.add, row.remove }) do
		widget:Hide()
	end
	row.onToggle, row.help = nil, nil
	row:Show()
	return row
end

-- Rendering -----------------------------------------------------------------

local function SetLabel(row, path, text, depth, help)
	row.path = path
	row.toggle:ClearAllPoints()
	row.toggle:SetPoint("LEFT", depth * INDENT, 0)
	row.toggle:SetWidth(CONTROL_X - depth * INDENT - 4)
	row.label:SetWidth(CONTROL_X - depth * INDENT - 4)
	row.label:SetText(text)
	row.label:SetTextColor(unpack(IsOverridden(path) and OVERRIDDEN_COLOR or DEFAULT_COLOR))
	row.help = help
end

-- The "x" of a list entry, right of its control.
local function ShowRemove(page, row, listPath, index, anchorX)
	row.remove:ClearAllPoints()
	row.remove:SetPoint("LEFT", anchorX, 0)
	row.remove:SetScript("OnClick", function()
		table.remove(Overrides.Get(ns.overrideRoots, listPath), index)
		Commit(page, listPath)
	end)
	row.remove:Show()
end

local function ShowScalar(row, value, key)
	if type(value) == "boolean" then
		row.check:SetChecked(value)
		row.check:Show()
	elseif IsColor(key, value) then
		row.swatch.color:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
		row.swatch:Show()
	else
		row.valueType = type(value)
		row.input:SetText(tostring(value))
		row.input:SetCursorPosition(0)
		row.input:Show()
	end
end

local function AddToList(page, path)
	local list = Overrides.Get(ns.overrideRoots, path)
	local last = list[#list]
	list[#list + 1] = last ~= nil and Overrides.DeepCopy(last) or ""
	page.collapsed[Overrides.Encode(path)] = false
	Commit(page, path)
end

-- A plain title row between sections, e.g. "Position" on a module page.
local function ShowHeading(page, text)
	local row = AcquireRow(page)
	row.path = nil
	row.toggle:ClearAllPoints()
	row.toggle:SetPoint("BOTTOMLEFT", 0, 2)
	row.toggle:SetWidth(CONTROL_X)
	row.label:SetWidth(CONTROL_X)
	row.label:SetText(text)
	row.label:SetTextColor(unpack(HEADING_COLOR))
end

-- `labelOverride` names a page section's top row instead of its key.
local function Visit(page, path, value, depth, listPath, index, labelOverride)
	local encoded = Overrides.Encode(path)
	if HIDDEN[encoded] then
		return
	end
	local key = path[#path]
	local label, help = ns.ConfigLabel(key)
	if type(key) == "number" then
		label = ("#%d"):format(key)
	end
	label = labelOverride or label
	local row = AcquireRow(page)

	if type(value) ~= "table" or IsColor(key, value) then
		SetLabel(row, path, label, depth, help)
		ShowScalar(row, value, key)
		if listPath then
			ShowRemove(page, row, listPath, index, CONTROL_X + 192)
		end
		return
	end

	local collapsed = page.collapsed[encoded]
	if collapsed == nil then
		collapsed = depth > 0
	end
	local isList = Overrides.IsList(value)
	SetLabel(
		row,
		path,
		(collapsed and "+ " or "- ") .. label .. (isList and (" (%d)"):format(#value) or ""),
		depth,
		help
	)
	row.onToggle = function()
		page.collapsed[encoded] = not collapsed
		page:Render()
	end
	if isList then
		row.add:ClearAllPoints()
		row.add:SetPoint("LEFT", CONTROL_X + 2, 0)
		row.add:SetScript("OnClick", function()
			AddToList(page, path)
		end)
		row.add:Show()
	end
	if listPath then
		ShowRemove(page, row, listPath, index, CONTROL_X + 30)
	end
	if collapsed then
		return
	end
	for _, childKey in ipairs(SortedKeys(value)) do
		local childPath = Overrides.Child(path, childKey)
		Visit(page, childPath, value[childKey], depth + 1, isList and path or nil, isList and childKey or nil)
	end
end

-- Hiding a focused input commits it, which renders again; such a render
-- waits until the running one is done.
local function Render(page)
	if page.rendering then
		page.renderAgain = true
		return
	end
	page.rendering = true
	page.used = 0
	for _, section in ipairs(page.sections) do
		if section.heading then
			ShowHeading(page, section.heading)
		else
			local value = Overrides.Get(ns.overrideRoots, section.path)
			if value ~= nil and section.flatten and type(value) == "table" then
				-- The table's own header row is left out (the page title names it).
				for _, childKey in ipairs(SortedKeys(value)) do
					Visit(page, Overrides.Child(section.path, childKey), value[childKey], 0)
				end
			elseif value ~= nil then
				Visit(page, section.path, value, 0, nil, nil, section.label)
			end
		end
	end
	for i = page.used + 1, #page.rows do
		page.rows[i]:Hide()
	end
	page.content:SetHeight(math.max(page.used * ROW_HEIGHT, 1))
	page.rendering = false
	if page.renderAgain then
		page.renderAgain = false
		Render(page)
	end
end

-- Page frame ----------------------------------------------------------------

-- A page with a title and a scroll area below it, for Blizzard's options panel.
-- `extra(page, top)`, if given, may add own controls below the title and
-- returns the height it used. Rows go into `page.content`.
function Editor.CreateScrollPage(title, extra)
	local page = CreateFrame("Frame")
	-- A parentless frame starts out shown, so the first time Blizzard's panel
	-- displays it there is no OnShow and the page stayed empty until it was
	-- hidden and shown again. Starting hidden makes every display an OnShow.
	page:Hide()

	local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -16)
	heading:SetText(title)

	local top = 44
	if extra then
		top = top + extra(page, top)
	end

	local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -top)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)
	page.content = CreateFrame("Frame", nil, scroll)
	page.content:SetSize(1, 1)
	scroll:SetScrollChild(page.content)
	scroll:SetScript("OnSizeChanged", function(_, width)
		page.content:SetWidth(width)
	end)
	return page
end

-- A scrollable page with a title, a reload hint and button, and the rows of
-- `sections`, each one of
--   { path = {...}, label = optional name of its top row }
--   { path = {...}, flatten = true }: the table's values without its own header row
--   { heading = "text" }: a title row
-- `extra(page, top)` may add own controls below the title and returns the
-- height it used.
function Editor.CreatePage(title, sections, extra)
	local page = Editor.CreateScrollPage(title, function(page, top)
		local reload = CreateSmallButton(page, T("Reload UI", "UI neu laden"), 120)
		reload:SetPoint("TOPRIGHT", -16, -12)
		reload:SetScript("OnClick", ReloadUI)

		page.reloadHint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		page.reloadHint:SetPoint("RIGHT", reload, "LEFT", -8, 0)
		page.reloadHint:SetText(T("Changes apply after a reload.", "Änderungen wirken nach dem Neuladen."))
		page.reloadHint:Hide()

		return extra and extra(page, top) or 0
	end)
	page.sections = sections
	page.rows, page.used, page.collapsed = {}, 0, {}
	page.Render = Render

	-- Every display renders (see CreateScrollPage); OnRefresh is what the
	-- settings panel calls on canvas pages, and a first render here fills the
	-- page even if neither ever comes.
	page:SetScript("OnShow", function(self)
		self:Render()
	end)
	page.OnRefresh = page.Render
	page:Render()
	return page
end
