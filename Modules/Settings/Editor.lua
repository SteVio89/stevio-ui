local _, ns = ...

-- Generated editor for the config: a page walks the Config.lua / Layout.lua
-- tables below its paths and shows a row per value. Booleans get a checkbox,
-- numbers and texts an input box, colors a swatch with Blizzard's color
-- picker; tables are collapsible headers, lists can grow (a copy of the last
-- entry) and shrink. Every change goes into the live config at once and is
-- saved as an override (see Core/Overrides.lua); it takes effect on reload.

local Overrides = ns.Overrides

local Editor = {}
ns.ConfigEditor = Editor

local ROW_HEIGHT = 24
local INDENT = 16
local CONTROL_X = 300
local OVERRIDDEN_COLOR = { 1, 0.82, 0 }
local DEFAULT_COLOR = { 0.9, 0.9, 0.9 }

local function T(english, german)
	return ns.isGerman and german or english
end

-- Paths the editor never shows: the profile has pages of its own, and the
-- settings module builds this panel, so turning it off would lock it away.
local HIDDEN = {
	["config/settings/profile"] = true,
	["config/settings/enabled"] = true,
}

-- A list of 3 or 4 numbers between 0 and 1 (r, g, b and maybe alpha); the
-- config has no other lists like that.
local function IsColor(key, value)
	if not Overrides.IsList(value) or (#value ~= 3 and #value ~= 4) then
		return false
	end
	for _, component in ipairs(value) do
		if type(component) ~= "number" or component < 0 or component > 1 then
			return false
		end
	end
	return type(key) == "string"
end

-- Keys in display order: "enabled" first, then plain values, then tables, each by label.
local function SortedKeys(tbl)
	if Overrides.IsList(tbl) then
		local keys = {}
		for index = 1, #tbl do
			keys[index] = index
		end
		return keys
	end
	local keys = {}
	for key in pairs(tbl) do
		keys[#keys + 1] = key
	end
	local function Rank(key)
		if key == "enabled" then
			return 0
		end
		local value = tbl[key]
		return (type(value) == "table" and not IsColor(key, value)) and 2 or 1
	end
	table.sort(keys, function(a, b)
		local rankA, rankB = Rank(a), Rank(b)
		if rankA ~= rankB then
			return rankA < rankB
		end
		return ns.ConfigLabel(a):lower() < ns.ConfigLabel(b):lower()
	end)
	return keys
end

local function Copy(path, key)
	local copy = {}
	for i, part in ipairs(path) do
		copy[i] = part
	end
	copy[#copy + 1] = key
	return copy
end

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

local function CreateSmallButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 22, 20)
	button:SetText(text)
	return button
end

local function OpenColorPicker(page, path, color)
	local previous = { unpack(color) }
	local function Apply()
		local r, g, b = ColorPickerFrame:GetColorRGB()
		local value = { r, g, b }
		if #previous == 4 then
			value[4] = ColorPickerFrame:GetColorAlpha()
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

	row.input = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	row.input:SetSize(180, 20)
	row.input:SetPoint("LEFT", CONTROL_X + 6, 0)
	row.input:SetAutoFocus(false)
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
	row.input:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	row.input:SetScript("OnEditFocusLost", CommitInput)
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

local Visit

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

-- `labelOverride` names a page section's top row instead of its key.
function Visit(page, path, value, depth, listPath, index, labelOverride)
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
		local childPath = Copy(path, childKey)
		Visit(page, childPath, value[childKey], depth + 1, isList and path or nil, isList and childKey or nil)
	end
end

local function Render(page)
	page.used = 0
	for _, section in ipairs(page.sections) do
		local value = Overrides.Get(ns.overrideRoots, section.path)
		if value ~= nil then
			Visit(page, section.path, value, section.depth or 0, nil, nil, section.label)
		end
	end
	for i = page.used + 1, #page.rows do
		page.rows[i]:Hide()
	end
	page.content:SetHeight(math.max(page.used * ROW_HEIGHT, 1))
end

-- Page frame ----------------------------------------------------------------

-- A scrollable page with a title, a reload hint and button, and the rows of
-- `sections` ({ path = {...}, label = optional name of its top row } each). `extra(page, top)` may add own controls
-- below the title and returns the height it used.
function Editor.CreatePage(title, sections, extra)
	local page = CreateFrame("Frame")
	page.sections = sections
	page.rows, page.used, page.collapsed = {}, 0, {}
	page.Render = Render

	local heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	heading:SetPoint("TOPLEFT", 16, -16)
	heading:SetText(title)

	local reload = CreateSmallButton(page, T("Reload UI", "UI neu laden"), 120)
	reload:SetPoint("TOPRIGHT", -16, -12)
	reload:SetScript("OnClick", ReloadUI)

	page.reloadHint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	page.reloadHint:SetPoint("RIGHT", reload, "LEFT", -8, 0)
	page.reloadHint:SetText(T("Changes apply after a reload.", "Änderungen wirken nach dem Neuladen."))
	page.reloadHint:Hide()

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

	page:SetScript("OnShow", function(self)
		self:Render()
	end)
	return page
end
