local _, ns = ...

-- The controls of the settings window: pill switch, slider with a number
-- box, plus/minus stepper, segmented choice, dropdown, colour swatch, text
-- box, list editor, switch chips and the position of a Layout.lua point; and
-- the setting row that puts a name, its visible help, the "default: x /
-- reset" line and one of these controls together. Built on the players
-- window's kit (Modules/Players/Kit.lua), colours from style.palette.

local K = ns.PlayersKit
local Meta = ns.SettingsMeta
local UI = ns.SettingsUI
local T = ns.T

local C = {}
ns.SettingsControls = C

C.CONTROL_WIDTH = 230
local BOX_HEIGHT = 24

-- Small parts ---------------------------------------------------------------

-- A number or text box: a flat box with an EditBox. onCommit(text) runs on
-- Enter and when the focus leaves; Escape puts `box.current` back.
function C.Box(parent, width, onCommit, justify)
	local box = K.Box(parent, { 0, 0, 0, 0.25 }, { 1, 1, 1, 0.10 })
	box:SetSize(width, BOX_HEIGHT)
	local edit = CreateFrame("EditBox", nil, box)
	edit:SetPoint("TOPLEFT", 6, 0)
	edit:SetPoint("BOTTOMRIGHT", -6, 0)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetJustifyH(justify or "RIGHT")
	edit:SetTextColor(K.RGB("textStrong"))
	box.edit = edit
	box.current = ""
	local committing = false
	local function Commit(self)
		if committing then
			return
		end
		committing = true
		onCommit(self:GetText())
		committing = false
	end
	edit:SetScript("OnEnterPressed", function(self)
		Commit(self)
		self:ClearFocus()
	end)
	edit:SetScript("OnEditFocusLost", function(self)
		Commit(self)
		self:HighlightText(0, 0)
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	edit:SetScript("OnEscapePressed", function(self)
		self:SetText(box.current)
		self:ClearFocus()
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function()
		edit:SetFocus()
	end)
	function box:SetValueText(text)
		self.current = text or ""
		if not edit:HasFocus() then
			edit:SetText(self.current)
			edit:SetCursorPosition(0)
		end
	end
	return box
end

-- A flat text button in a box ("Reset", "+ Add").
function C.Button(parent, text, onClick, height)
	local button = K.Button(parent, text, height or 22)
	button:SetScript("OnClick", onClick)
	return button
end

-- A text that is a link: accent coloured, underlined on hover.
function C.Link(parent, text, onClick, size)
	local link = CreateFrame("Button", nil, parent)
	link.text = K.Text(link, size or 10, "accent")
	link.text:SetPoint("LEFT")
	link.line = K.Texture(link, "ARTWORK", K.RGB("accent"))
	link.line:SetHeight(1)
	link.line:SetPoint("TOPLEFT", link.text, "BOTTOMLEFT", 0, -1)
	link.line:SetPoint("TOPRIGHT", link.text, "BOTTOMRIGHT", 0, -1)
	link.line:SetAlpha(0.5)
	function link:SetLabel(value)
		self.text:SetText(value)
		self:SetSize(self.text:GetStringWidth() + 2, 14)
	end
	link:SetScript("OnEnter", function(self)
		self.line:SetAlpha(1)
	end)
	link:SetScript("OnLeave", function(self)
		self.line:SetAlpha(0.5)
	end)
	link:SetScript("OnClick", onClick)
	link:SetLabel(text or "")
	return link
end

-- A small pill with a count or word ("3", "1 change", "off").
function C.Pill(parent)
	local pill = K.Box(parent, { K.RGB("pill") })
	pill:SetHeight(16)
	pill.text = K.Text(pill, 10, "pillText", "CENTER")
	pill.text:SetPoint("CENTER", 0, 0)
	function pill:SetLabel(text)
		self.text:SetText(text)
		self:SetWidth(math.max(16, self.text:GetStringWidth() + 12))
	end
	return pill
end

-- Switch ----------------------------------------------------------------------

-- A pill switch; switch.onChange(on).
function C.Switch(parent)
	local switch = CreateFrame("Button", nil, parent)
	switch:SetSize(34, 18)
	switch.height = 18
	-- A flat track between two circles makes the pill.
	switch.track = K.Texture(switch, "BACKGROUND")
	switch.track:SetPoint("TOPLEFT", 9, 0)
	switch.track:SetPoint("BOTTOMRIGHT", -9, 0)
	switch.capLeft = K.Circle(switch, "BACKGROUND", 1)
	switch.capLeft:SetSize(18, 18)
	switch.capLeft:SetPoint("LEFT")
	switch.capRight = K.Circle(switch, "BACKGROUND", 1)
	switch.capRight:SetSize(18, 18)
	switch.capRight:SetPoint("RIGHT")
	switch.knob = K.Circle(switch, "ARTWORK")
	switch.knob:SetSize(14, 14)
	function switch:SetOn(on)
		self.on = on and true or false
		local r, g, b, a = 1, 1, 1, 0.14
		if self.on then
			r, g, b, a = K.RGB("accent")
		end
		for _, part in ipairs({ self.track, self.capLeft, self.capRight }) do
			part:SetVertexColor(r, g, b, a)
		end
		self.knob:ClearAllPoints()
		self.knob:SetPoint(self.on and "RIGHT" or "LEFT", self.on and -2 or 2, 0)
		self.knob:SetVertexColor(1, 1, 1, self.on and 1 or 0.7)
	end
	switch:SetScript("OnClick", function(self)
		self:SetOn(not self.on)
		if self.onChange then
			self.onChange(self.on)
		end
	end)
	function switch:Set(_, value)
		self:SetOn(value)
	end
	switch:SetOn(false)
	return switch
end

-- Numbers ---------------------------------------------------------------------

local function ParseNumber(text, meta)
	local number = tonumber((text or ""):gsub(",", "."):match("%-?[%d%.]+"))
	if not number then
		return nil
	end
	if meta.percent then
		number = number / 100
	end
	return Meta.Clamp(number, meta)
end

-- The number as the box shows it: "38 %" or "12".
local function BoxText(value, meta)
	if meta.percent then
		return ("%d %%"):format(math.floor(value * 100 + 0.5))
	end
	return Meta.Number(value)
end

-- A slider with a number box; slider.onChange(value).
function C.Slider(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(C.CONTROL_WIDTH, BOX_HEIGHT)
	frame.height = BOX_HEIGHT

	local slider = CreateFrame("Slider", nil, frame)
	slider:SetOrientation("HORIZONTAL")
	slider:SetPoint("LEFT", 0, 0)
	slider:SetSize(C.CONTROL_WIDTH - 72, 16)
	slider:SetObeyStepOnDrag(true)
	slider.track = K.Texture(slider, "BACKGROUND", 1, 1, 1, 0.12)
	slider.track:SetHeight(4)
	slider.track:SetPoint("LEFT")
	slider.track:SetPoint("RIGHT")
	slider.thumb = K.Circle(slider, "OVERLAY")
	slider.thumb:SetSize(14, 14)
	slider.thumb:SetVertexColor(1, 1, 1, 1)
	slider:SetThumbTexture(slider.thumb)
	slider.fill = K.Texture(slider, "ARTWORK", K.RGB("accent"))
	slider.fill:SetHeight(4)
	slider.fill:SetPoint("LEFT", slider.track, "LEFT")
	slider.fill:SetPoint("RIGHT", slider.thumb, "CENTER")
	frame.slider = slider

	local function Emit(value)
		value = Meta.Clamp(value, frame.meta)
		if frame.onChange and value ~= frame.value then
			frame.value = value
			frame.box:SetValueText(BoxText(value, frame.meta))
			frame.onChange(value)
		end
	end

	frame.box = C.Box(frame, 60, function(text)
		local value = ParseNumber(text, frame.meta)
		if value then
			Emit(value)
			frame:Set(nil, frame.value)
		else
			frame.box.edit:SetText(frame.box.current)
		end
	end)
	frame.box:SetPoint("RIGHT")

	slider:SetScript("OnValueChanged", function(_, value, userInput)
		if userInput and not frame.updating then
			Emit(value)
		end
	end)
	local function Nudge(delta)
		Emit((frame.value or 0) + delta * (frame.meta.step or 1))
		frame:Set(nil, frame.value)
	end
	for _, target in ipairs({ slider, frame.box }) do
		target:EnableMouseWheel(true)
		target:SetScript("OnMouseWheel", function(_, delta)
			Nudge(delta)
		end)
	end
	frame.box.edit:SetScript("OnArrowPressed", function(_, key)
		if key == "UP" or key == "RIGHT" then
			Nudge(1)
		elseif key == "DOWN" or key == "LEFT" then
			Nudge(-1)
		end
	end)

	function frame:Set(item, value)
		if item then
			self.meta = item.meta
		end
		self.value = value
		self.updating = true
		slider:SetMinMaxValues(self.meta.min, self.meta.max)
		slider:SetValueStep(self.meta.step or 1)
		slider:SetValue(value)
		self.updating = false
		self.box:SetValueText(BoxText(value, self.meta))
	end
	return frame
end

-- [−] value [+]; stepper.onChange(value).
function C.Stepper(parent)
	local frame = K.Box(parent, { 0, 0, 0, 0.25 }, { 1, 1, 1, 0.10 })
	frame:SetSize(96, BOX_HEIGHT)
	frame.height = BOX_HEIGHT
	local function Step(delta)
		local meta = frame.meta or {}
		local value = Meta.Clamp((frame.value or 0) + delta * (meta.step or 1), meta)
		if value ~= frame.value and frame.onChange then
			frame.value = value
			frame.box:SetValueText(BoxText(value, meta))
			frame.onChange(value)
		end
	end
	local function Side(text, delta, point)
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(24, BOX_HEIGHT)
		button:SetPoint(point)
		button.text = K.Text(button, 13, "textMuted", "CENTER")
		button.text:SetPoint("CENTER", 0, 1)
		button.text:SetText(text)
		button:SetScript("OnClick", function()
			Step(delta)
		end)
		button:SetScript("OnEnter", function(self)
			self.text:SetTextColor(K.RGB("textStrong"))
		end)
		button:SetScript("OnLeave", function(self)
			self.text:SetTextColor(K.RGB("textMuted"))
		end)
		return button
	end
	Side("–", -1, "LEFT")
	Side("+", 1, "RIGHT")
	frame.box = C.Box(frame, 48, function(text)
		local value = ParseNumber(text, frame.meta or {})
		if value and value ~= frame.value and frame.onChange then
			frame.value = value
			frame.onChange(value)
		end
		frame.box:SetValueText(BoxText(frame.value, frame.meta or {}))
	end, "CENTER")
	frame.box:SetPoint("CENTER")
	frame.box:SetColors(nil, nil)
	frame:EnableMouseWheel(true)
	frame:SetScript("OnMouseWheel", function(_, delta)
		Step(delta)
	end)
	function frame:Set(item, value)
		if item then
			self.meta = item.meta
		end
		self.value = value
		self.box:SetValueText(BoxText(value, self.meta or {}))
	end
	return frame
end

-- Choices -----------------------------------------------------------------------

local function OptionText(option)
	return T(option[2][1], option[2][2])
end

-- Buttons side by side, one of them active; segmented.onChange(value).
function C.Segmented(parent)
	local frame = K.Box(parent, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.10 })
	frame:SetHeight(BOX_HEIGHT)
	frame.height = BOX_HEIGHT
	frame.buttons = K.Pool(function()
		local button = CreateFrame("Button", nil, frame)
		button:SetHeight(BOX_HEIGHT - 4)
		button.bg = K.Texture(button, "BACKGROUND", 0, 0, 0, 0)
		button.bg:SetAllPoints()
		button.text = K.Text(button, 11, "textMuted", "CENTER")
		button.text:SetPoint("CENTER")
		button:SetScript("OnClick", function(self)
			if frame.onChange and self.value ~= frame.value then
				frame:Select(self.value)
				frame.onChange(self.value)
			end
		end)
		return button
	end)
	function frame:Select(value)
		self.value = value
		for index = 1, #(self.options or {}) do
			local button = self.buttons:Get(index)
			local on = button.value == value
			if on then
				button.bg:SetVertexColor(K.RGB("accent", 0.45))
				button.text:SetTextColor(K.RGB("textStrong"))
			else
				button.bg:SetVertexColor(0, 0, 0, 0)
				button.text:SetTextColor(K.RGB("textMuted"))
			end
		end
	end
	function frame:Set(item, value)
		self.options = item.meta.options
		local x = 2
		for index, option in ipairs(self.options) do
			local button = self.buttons:Get(index)
			button.value = option[1]
			button.text:SetText(OptionText(option))
			local width = math.max(26, button.text:GetStringWidth() + 16)
			button:SetWidth(width)
			button:ClearAllPoints()
			button:SetPoint("LEFT", x, 0)
			x = x + width
		end
		self.buttons:HideFrom(#self.options + 1)
		self:SetWidth(x + 2)
		self:Select(value)
	end
	return frame
end

-- A box with the chosen option's name that opens a menu of all of them.
-- dropdown:SetOptions(options, value); dropdown.onChange(value).
function C.Dropdown(parent, width)
	local button = K.Box(parent, { 1, 1, 1, 0.04 }, { 1, 1, 1, 0.12 }, "Button")
	button:SetSize(width or 160, BOX_HEIGHT)
	button.height = BOX_HEIGHT
	button.text = K.Text(button, 11, "textStrong")
	button.text:SetPoint("LEFT", 8, 0)
	button.text:SetPoint("RIGHT", -18, 0)
	local arrow = button:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(10, 10)
	arrow:SetPoint("RIGHT", -6, -1)
	arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	arrow:SetVertexColor(K.RGB("textMuted"))
	function button:SetOptions(options, value)
		self.options, self.value = options, value
		self.text:SetText(Meta.OptionLabel(options, value) or tostring(value))
	end
	button:SetScript("OnClick", function(self)
		MenuUtil.CreateContextMenu(self, function(_, root)
			for _, option in ipairs(self.options or {}) do
				root:CreateRadio(OptionText(option), function()
					return self.value == option[1]
				end, function()
					self:SetOptions(self.options, option[1])
					if self.onChange then
						self.onChange(option[1])
					end
				end)
			end
		end)
	end)
	function button:Set(item, value)
		self:SetOptions(item.meta.options, value)
	end
	return button
end

-- Colour ---------------------------------------------------------------------------

-- Picker values are rounded, so confirming an untouched colour saves nothing.
local function Round(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

-- Blizzard's colour picker for `color` (3 or 4 numbers, the 4th is alpha);
-- onPick(newColor) while picking and with the old colour on cancel.
function C.PickColor(color, onPick)
	local previous = { unpack(color) }
	-- The picker reports a colour while it is being set up; only later ones count.
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
		onPick(value)
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
			onPick(previous)
		end,
	})
	ready = true
end

-- A swatch with its hex value; color.onChange(newColor).
function C.Color(parent)
	local frame = CreateFrame("Button", nil, parent)
	frame:SetSize(C.CONTROL_WIDTH, 20)
	frame.height = 20
	frame.swatch = K.Box(frame, { 1, 1, 1, 1 }, { 1, 1, 1, 0.25 })
	frame.swatch:SetSize(20, 20)
	frame.swatch:SetPoint("RIGHT")
	frame.swatch:EnableMouse(false)
	frame.hex = K.Text(frame, 10, "textMuted", "RIGHT")
	frame.hex:SetPoint("RIGHT", frame.swatch, "LEFT", -8, 0)
	frame:SetScript("OnClick", function(self)
		C.PickColor(self.value, function(value)
			self:Set(nil, value)
			if self.onChange then
				self.onChange(value)
			end
		end)
	end)
	function frame:Set(_, value)
		self.value = value
		self.swatch.bg:SetVertexColor(value[1], value[2], value[3], value[4] or 1)
		self.hex:SetText(Meta.ColorText(value))
	end
	return frame
end

-- Text and lists -----------------------------------------------------------------

-- A text box; text.onChange(newText).
function C.Text(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(C.CONTROL_WIDTH, BOX_HEIGHT)
	frame.height = BOX_HEIGHT
	frame.box = C.Box(frame, C.CONTROL_WIDTH, function(text)
		if text ~= frame.value and frame.onChange then
			frame.value = text
			frame.onChange(text)
		end
	end, "LEFT")
	frame.box:SetPoint("RIGHT")
	function frame:Set(_, value)
		self.value = tostring(value)
		self.box:SetValueText(self.value)
	end
	return frame
end

-- Rows of text boxes with an ×, and "+ Add"; list.onChange(newList).
function C.List(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetWidth(C.CONTROL_WIDTH)
	local function Copy()
		local copy = {}
		for index, entry in ipairs(frame.value) do
			copy[index] = entry
		end
		return copy
	end
	frame.rows = K.Pool(function(index)
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(C.CONTROL_WIDTH, BOX_HEIGHT)
		row:SetPoint("TOPRIGHT", 0, -(index - 1) * (BOX_HEIGHT + 4))
		row.box = C.Box(row, C.CONTROL_WIDTH - 28, function(text)
			local list = Copy()
			if list[row.index] ~= text then
				list[row.index] = text
				frame.onChange(list)
			end
		end, "LEFT")
		row.box:SetPoint("LEFT")
		row.remove = ns.CreateCloseButton(row, 20, function()
			local list = Copy()
			table.remove(list, row.index)
			frame.onChange(list)
		end)
		row.remove:SetPoint("RIGHT")
		return row
	end)
	frame.add = C.Button(frame, T("+ Add", "+ Hinzufügen"), function()
		local list = Copy()
		list[#list + 1] = ""
		frame.onChange(list)
	end)
	function frame:Set(_, value)
		self.value = value
		for index, entry in ipairs(value) do
			local row = self.rows:Get(index)
			row.index = index
			row.box:SetValueText(tostring(entry))
		end
		self.rows:HideFrom(#value + 1)
		self.add:ClearAllPoints()
		self.add:SetPoint("TOPRIGHT", 0, -#value * (BOX_HEIGHT + 4))
		self.height = #value * (BOX_HEIGHT + 4) + 22
		self:SetHeight(self.height)
	end
	return frame
end

-- Chips for a table of switches (main channels); flags.onChange(newTable).
function C.Flags(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetWidth(C.CONTROL_WIDTH)
	frame.chips = K.Pool(function()
		local chip = K.Chip(frame, 20)
		chip:SetScript("OnClick", function(self)
			local copy = {}
			for key, on in pairs(frame.value) do
				copy[key] = on
			end
			copy[self.key] = not copy[self.key]
			frame.onChange(copy)
		end)
		return chip
	end)
	function frame:Set(_, value)
		self.value = value
		local x, y, index = 0, 0, 0
		for _, key in ipairs(ns.EditorModel.SortedKeys(value)) do
			index = index + 1
			local chip = self.chips:Get(index)
			chip.key = key
			chip:SetChip((ns.ConfigLabel(key)), nil, value[key] == true)
			if x > 0 and x + chip:GetWidth() > C.CONTROL_WIDTH then
				x, y = 0, y + 24
			end
			chip:ClearAllPoints()
			chip:SetPoint("TOPLEFT", x, -y)
			x = x + chip:GetWidth() + 4
		end
		self.chips:HideFrom(index + 1)
		self.height = y + 20
		self:SetHeight(self.height)
	end
	return frame
end

-- Anchor dropdown and X/Y boxes of a Layout.lua point;
-- position.onChange({ point = ..., x = ..., y = ... }) with the changed field.
function C.Position(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(C.CONTROL_WIDTH + 20, BOX_HEIGHT)
	frame.height = BOX_HEIGHT
	local function Offset(key, label)
		local box = C.Box(frame, 46, function(text)
			local number = tonumber((text or ""):match("%-?%d+%.?%d*"))
			if number and number ~= frame.value[key] then
				frame.onChange({ [key] = number })
			else
				box:SetValueText(Meta.Number(frame.value[key]))
			end
		end)
		box.label = K.Text(frame, 10, "textMuted", "RIGHT")
		box.label:SetText(label)
		box:EnableMouseWheel(true)
		box:SetScript("OnMouseWheel", function(_, delta)
			frame.onChange({ [key] = frame.value[key] + delta })
		end)
		return box
	end
	frame.y = Offset("y", "Y")
	frame.y:SetPoint("RIGHT")
	frame.y.label:SetPoint("RIGHT", frame.y, "LEFT", -5, 0)
	frame.x = Offset("x", "X")
	frame.x:SetPoint("RIGHT", frame.y.label, "LEFT", -8, 0)
	frame.x.label:SetPoint("RIGHT", frame.x, "LEFT", -5, 0)
	frame.anchor = C.Dropdown(frame, 108)
	frame.anchor:SetPoint("RIGHT", frame.x.label, "LEFT", -8, 0)
	frame.anchor.onChange = function(point)
		frame.onChange({ point = point })
	end
	function frame:Set(_, value)
		self.value = value
		self.anchor:SetOptions(Meta.ANCHORS, value.point)
		self.x:SetValueText(Meta.Number(value.x))
		self.y:SetValueText(Meta.Number(value.y))
	end
	return frame
end

local FACTORIES = {
	switch = C.Switch,
	slider = C.Slider,
	stepper = C.Stepper,
	segmented = C.Segmented,
	select = C.Dropdown,
	color = C.Color,
	text = C.Text,
	list = C.List,
	flags = C.Flags,
	position = C.Position,
}

-- The control kind a row uses: a slider without a range becomes a stepper.
function C.Kind(item)
	local kind = item.control
	if kind == "slider" and not (item.meta.min and item.meta.max) then
		kind = "stepper"
	end
	return FACTORIES[kind] and kind or "text"
end

function C.Create(kind, parent)
	return FACTORIES[kind](parent)
end

-- Setting row -------------------------------------------------------------------

local TEXT_GAP = 24
local ROW_PAD = 12

-- `query` highlighted (accent, case-insensitive) in `text`.
function C.Highlight(text, query)
	if not query or query == "" or not text then
		return text
	end
	return ns.SettingsSearch.Highlight(text, query, ns.Hex(K.Color("accent")), "|r")
end

-- A row for one setting: dot (changed), name, visible help, "Default: x ·
-- Reset" when changed, and the control on the right. One pool per control
-- kind, so a row keeps its control.
function C.Row(parent, kind)
	local row = CreateFrame("Frame", nil, parent)
	row.kind = kind
	row.line = K.Texture(row, "BACKGROUND", 1, 1, 1, 0.05)
	row.line:SetHeight(1)
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.dot = K.Circle(row, "ARTWORK")
	row.dot:SetSize(5, 5)
	row.dot:SetVertexColor(K.RGB("accent"))
	row.path = K.Text(row, 10, "textFaint")
	row.name = K.Text(row, 12, "textStrong")
	row.tag = K.Text(row, 10, "accent")
	row.help = K.Text(row, 11, "textMuted")
	row.help:SetWordWrap(true)
	row.help:SetNonSpaceWrap(false)
	row.default = K.Text(row, 10, "textFaint")
	row.reset = C.Link(row, T("Reset", "Zurücksetzen"), function()
		UI.Reset(row.item)
	end)
	row.control = C.Create(kind, row)
	row.control.onChange = function(value)
		local item = row.item
		if item.control == "position" then
			UI.SetFields(item, value)
		else
			UI.Set(item, value)
		end
	end
	return row
end

-- Fills the row and returns its height. opts: width, query (highlights),
-- showPath (the section above the name, for search results), showAdvanced
-- (an "Advanced" tag).
function C.FillRow(row, item, opts)
	row.item = item
	local width = opts.width
	local value = UI.Value(item.path)
	local changed = UI.IsChanged(item)
	local controlWidth = math.max(row.control:GetWidth(), C.CONTROL_WIDTH)
	local textWidth = width - controlWidth - TEXT_GAP

	local y = ROW_PAD
	if opts.pathText then
		row.path:SetText(opts.pathText)
		row.path:ClearAllPoints()
		row.path:SetPoint("TOPLEFT", 0, -y)
		row.path:Show()
		y = y + 14
	else
		row.path:Hide()
	end
	row.name:ClearAllPoints()
	row.name:SetPoint("TOPLEFT", 12, -y)
	row.name:SetText(C.Highlight(item.label, opts.query))
	row.name:SetWidth(math.min(row.name:GetStringWidth() + 2, textWidth - 12))
	row.dot:ClearAllPoints()
	row.dot:SetPoint("RIGHT", row.name, "LEFT", -6, 0)
	row.dot:SetShown(changed)
	row.tag:ClearAllPoints()
	row.tag:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
	row.tag:SetText(opts.showAdvanced and item.advanced and T("Advanced", "Erweitert") or "")
	y = y + 16

	row.help:ClearAllPoints()
	row.help:SetPoint("TOPLEFT", 12, -y)
	row.help:SetWidth(textWidth - 12)
	if item.help then
		row.help:SetText(C.Highlight(item.help, opts.query))
		row.help:Show()
		y = y + row.help:GetStringHeight() + 2
	else
		row.help:SetText("")
		row.help:Hide()
	end

	if changed then
		local default = UI.Default(item.path)
		row.default:SetText(
			("%s %s"):format(T("Default:", "Standard:"), Meta.FormatValue(default, item.meta, item.control))
		)
		row.default:ClearAllPoints()
		row.default:SetPoint("TOPLEFT", 12, -(y + 3))
		row.default:Show()
		row.reset:ClearAllPoints()
		row.reset:SetPoint("LEFT", row.default, "RIGHT", 8, 0)
		row.reset:Show()
		y = y + 18
	else
		row.default:Hide()
		row.reset:Hide()
	end
	y = y + ROW_PAD

	row.control:Set(item, value)
	local controlHeight = row.control.height or 24
	local height = math.max(y, controlHeight + 2 * ROW_PAD)
	row.control:ClearAllPoints()
	if controlHeight > 30 then
		row.control:SetPoint("TOPRIGHT", 0, -ROW_PAD)
	else
		row.control:SetPoint("RIGHT", row, "TOPRIGHT", 0, -height / 2)
	end
	row:SetHeight(height)
	return height
end

-- Recycled rows: rows:Get(kind) during a render, rows:Finish() hides the
-- ones not used.
function C.RowPools(parent)
	local pools = { used = {}, frames = {} }
	function pools:Begin()
		self.used = {}
	end
	function pools:Get(kind)
		self.frames[kind] = self.frames[kind] or {}
		local index = (self.used[kind] or 0) + 1
		self.used[kind] = index
		local row = self.frames[kind][index]
		if not row then
			row = C.Row(parent, kind)
			self.frames[kind][index] = row
		end
		row:Show()
		return row
	end
	function pools:Finish()
		for kind, frames in pairs(self.frames) do
			for index = (self.used[kind] or 0) + 1, #frames do
				frames[index]:Hide()
			end
		end
	end
	return pools
end

-- Section heading: a title and a muted subtitle beside it.
function C.Heading(parent)
	local heading = CreateFrame("Frame", nil, parent)
	heading:SetHeight(28)
	heading.title = K.Text(heading, 14, "textStrong")
	heading.title:SetPoint("BOTTOMLEFT", 0, 6)
	heading.subtitle = K.Text(heading, 11, "textMuted")
	heading.subtitle:SetPoint("LEFT", heading.title, "RIGHT", 10, 0)
	function heading:Set(title, subtitle)
		self.title:SetText(title)
		self.subtitle:SetText(subtitle or "")
	end
	return heading
end
