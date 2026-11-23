local _, ns = ...

-- The visual building blocks of the players window (#86): flat boxes and
-- cards, chips, stat tiles, bars, the round initial of a player, segmented
-- switches and a scroll area. Colors come from the theme (style.palette)
-- and config.players.colors.

local K = {}
ns.PlayersKit = K

local style = ns.config.style
local colors = ns.config.players.colors

K.WHITE = "Interface\\Buttons\\WHITE8X8"
K.CIRCLE = "Interface\\Masks\\CircleMaskScalable"
K.ICON_WARNING = "Interface\\DialogFrame\\DialogIcon-AlertNew-16"
K.ICON_NOTE = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
K.ICON_DICE = "Interface\\Buttons\\UI-GroupLoot-Dice-Up"
K.ICON_SEARCH = "Interface\\COMMON\\UI-Searchbox-Icon"
K.ICON_OPTIONS = "Interface\\Buttons\\UI-OptionsButton"
K.ICON_STAR = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

-- Colors ---------------------------------------------------------------------

function K.Palette()
	return style.palette
end

-- { r, g, b } of a palette or players color by name ("accent", "need", ...).
function K.Color(name)
	return colors[name] or style.palette[name]
end

function K.RGB(name, alpha)
	local color = K.Color(name)
	return color[1], color[2], color[3], alpha or color[4] or 1
end

-- "|cffRRGGBB" of a named color.
function K.Hex(name)
	return ns.Hex(K.Color(name))
end

function K.ClassRGB(class)
	local color = class and C_ClassColor.GetClassColor(class)
	if color then
		return color.r, color.g, color.b
	end
	return K.RGB("text")
end

-- "Name-Realm" as the name in class color and "-Realm" muted.
function K.ColoredName(name, class)
	local short, realm = name:match("^([^-]+)(%-.+)$")
	local r, g, b = K.ClassRGB(class)
	local text = ns.Hex({ r, g, b }) .. (short or name) .. "|r"
	if realm then
		text = text .. K.Hex("textMuted") .. realm .. "|r"
	end
	return text
end

-- Regions -----------------------------------------------------------------------

function K.Text(parent, size, color, justify)
	local text = ns.CreateFontString(parent, size, justify)
	text:SetTextColor(K.RGB(color or "text"))
	return text
end

function K.Texture(parent, layer, r, g, b, a, sublevel)
	local texture = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
	texture:SetTexture(K.WHITE)
	texture:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
	return texture
end

-- A flat box: background and a 1 px border inside its edges.
-- box:SetColors({ r, g, b, a } background, { r, g, b, a } border or nil).
function K.Box(parent, background, border, frameType)
	local box = CreateFrame(frameType or "Frame", nil, parent)
	box.bg = K.Texture(box, "BACKGROUND")
	box.bg:SetAllPoints()
	box.border = ns.CreateInsetBorder(box, 1, 1, "BORDER")
	function box:SetColors(bg, edge)
		self.bg:SetVertexColor(unpack(bg or { 0, 0, 0, 0 }))
		self.border:SetShown(edge ~= nil)
		if edge then
			self.border:SetColor(unpack(edge))
		end
	end
	box:SetColors(background, border)
	return box
end

-- The card background: a little lighter than the window, faint border.
function K.CardColors()
	local accent = style.palette.accent
	return { 1, 1, 1, 0.025 }, { accent[1], accent[2], accent[3], 0.16 }
end

-- A card with a small upper-case title and an optional text right of it.
function K.Card(parent, title)
	local card = K.Box(parent, K.CardColors())
	card.title = K.Text(card, 10, "textMuted")
	card.title:SetPoint("TOPLEFT", 16, -16)
	card.title:SetText(title and title:upper() or "")
	card.aside = K.Text(card, 10, "textMuted", "RIGHT")
	card.aside:SetPoint("TOPRIGHT", -16, -16)
	return card
end

-- A flat button: text (and an optional icon), a pill background, lighter
-- while hovered. button:SetActive(on, colorName) tints it.
function K.Button(parent, text, height, icon)
	local button = K.Box(parent, nil, nil, "Button")
	button:SetHeight(height or 24)
	button.label = K.Text(button, 11, "textStrong", "CENTER")
	button.label:SetPoint("CENTER")
	if icon then
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetSize(12, 12)
		button.icon:SetTexture(icon)
	end
	function button:SetLabel(value)
		self.label:SetText(value)
		local width = self.label:GetStringWidth()
		if self.icon then
			self.icon:ClearAllPoints()
			self.icon:SetPoint("LEFT", 10, 0)
			self.label:ClearAllPoints()
			self.label:SetPoint("LEFT", self.icon, "RIGHT", 6, 0)
			width = width + 18
		end
		self:SetWidth(math.floor(width + 22))
	end
	function button:SetActive(on, colorName)
		self.active = on
		local accent = K.Color(colorName or "accent")
		if on then
			self:SetColors({ accent[1], accent[2], accent[3], 0.28 }, { accent[1], accent[2], accent[3], 0.5 })
		else
			self:SetColors({ 1, 1, 1, 0.04 }, { 1, 1, 1, 0.10 })
		end
	end
	button:SetScript("OnEnter", function(self)
		if not self.active then
			self.bg:SetVertexColor(1, 1, 1, 0.09)
		end
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.tooltip, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		self:SetActive(self.active, self.activeColor)
		GameTooltip_Hide()
	end)
	button:SetActive(false)
	button:SetLabel(text or "")
	return button
end

-- A small rounded-looking chip: label and a muted count.
function K.Chip(parent, height)
	local chip = K.Button(parent, "", height or 20)
	function chip:SetChip(text, count, active, colorName)
		self.activeColor = colorName
		if count then
			text = text .. "  " .. K.Hex("textMuted") .. count .. "|r"
		end
		self:SetLabel(text)
		self:SetActive(active, colorName)
	end
	return chip
end

-- A small icon button (options, close), lighter while hovered.
function K.IconButton(parent, texture, size, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexture(texture)
	button.icon:SetVertexColor(0.75, 0.75, 0.8)
	button:SetScript("OnEnter", function(self)
		self.icon:SetVertexColor(1, 1, 1)
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText(self.tooltip)
			GameTooltip:Show()
		end
	end)
	button:SetScript("OnLeave", function(self)
		self.icon:SetVertexColor(0.75, 0.75, 0.8)
		GameTooltip_Hide()
	end)
	button:SetScript("OnClick", onClick)
	return button
end

-- A stat tile: label, big value, a muted line below.
function K.Tile(parent)
	local tile = K.Box(parent, K.CardColors())
	tile:SetHeight(90)
	tile.label = K.Text(tile, 10, "textMuted")
	tile.label:SetPoint("TOPLEFT", 16, -16)
	tile.value = K.Text(tile, 22, "textStrong")
	tile.value:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -8)
	tile.sub = K.Text(tile, 10, "textMuted")
	tile.sub:SetPoint("TOPLEFT", tile.value, "BOTTOMLEFT", 0, -8)
	tile.sub:SetPoint("RIGHT", -10, 0)
	function tile:Set(label, value, sub)
		self.label:SetText(label:upper())
		self.value:SetText(value)
		self.sub:SetText(sub or "")
	end
	return tile
end

-- A horizontal bar on a track; bar:SetFraction(0..1, r, g, b).
function K.Bar(parent, height)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(height or 8)
	bar.track = K.Texture(bar, "BACKGROUND", 1, 1, 1, 0.06)
	bar.track:SetAllPoints()
	bar.fill = K.Texture(bar, "ARTWORK")
	bar.fill:SetPoint("TOPLEFT")
	bar.fill:SetPoint("BOTTOMLEFT")
	function bar:SetFraction(fraction, r, g, b)
		self.fraction = math.max(0, math.min(1, fraction or 0))
		self.fill:SetVertexColor(r or 1, g or 1, b or 1, 1)
		self:Layout()
	end
	function bar:Layout()
		local width = self:GetWidth() * (self.fraction or 0)
		self.fill:SetShown(width >= 1)
		self.fill:SetWidth(math.max(width, 1))
	end
	bar:SetScript("OnSizeChanged", bar.Layout)
	-- Hover shows `bar.tooltip` (a text or a function returning one).
	bar:SetScript("OnEnter", function(self)
		local text = type(self.tooltip) == "function" and self.tooltip() or self.tooltip
		if text then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(text, 1, 1, 1, 1, true)
			GameTooltip:Show()
		end
	end)
	bar:SetScript("OnLeave", GameTooltip_Hide)
	return bar
end

-- Bars side by side in one track with 2 px gaps: SetParts({ { value, colorName } }).
function K.StackedBar(parent, height)
	local bar = CreateFrame("Frame", nil, parent)
	bar:SetHeight(height or 8)
	bar.segments = {}
	function bar:SetParts(parts)
		self.parts = parts
		self:Layout()
	end
	function bar:Layout()
		local parts = self.parts or {}
		local total, shown = 0, 0
		for _, part in ipairs(parts) do
			total = total + part[1]
			shown = shown + (part[1] > 0 and 1 or 0)
		end
		local gap = 2
		local width = self:GetWidth() - gap * math.max(0, shown - 1)
		local x = 0
		for index, part in ipairs(parts) do
			local segment = self.segments[index] or K.Texture(self, "ARTWORK")
			self.segments[index] = segment
			local w = total > 0 and width * part[1] / total or 0
			segment:ClearAllPoints()
			segment:SetPoint("TOPLEFT", x, 0)
			segment:SetPoint("BOTTOMLEFT", x, 0)
			segment:SetWidth(math.max(w, 1))
			segment:SetVertexColor(K.RGB(part[2]))
			segment:SetShown(w >= 1)
			if w >= 1 then
				x = x + w + gap
			end
		end
		for index = #parts + 1, #self.segments do
			self.segments[index]:Hide()
		end
	end
	bar:SetScript("OnSizeChanged", bar.Layout)
	return bar
end

-- A colored square and a text: a legend entry.
function K.Legend(parent)
	local entry = CreateFrame("Frame", nil, parent)
	entry:SetHeight(14)
	entry.swatch = K.Texture(entry, "ARTWORK")
	entry.swatch:SetSize(9, 9)
	entry.swatch:SetPoint("LEFT")
	entry.text = K.Text(entry, 11, "text")
	entry.text:SetPoint("LEFT", entry.swatch, "RIGHT", 6, 0)
	function entry:Set(colorName, text)
		self.swatch:SetVertexColor(K.RGB(colorName))
		self.text:SetText(text)
		self:SetWidth(15 + self.text:GetStringWidth())
	end
	return entry
end

local function Circle(parent, layer, sublevel)
	local texture = parent:CreateTexture(nil, layer, nil, sublevel)
	texture:SetTexture(K.WHITE)
	local mask = parent:CreateMaskTexture()
	mask:SetTexture(K.CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(texture)
	texture:AddMaskTexture(mask)
	return texture
end
K.Circle = Circle

-- The round initial of a player: a circle in class color at 14 % with a
-- ring at 35 %, the first letter in class color.
function K.Avatar(parent, size)
	local avatar = CreateFrame("Frame", nil, parent)
	avatar:SetSize(size, size)
	local ring = math.max(1, math.floor(size / 24 + 0.5))
	avatar.ring = Circle(avatar, "BORDER", 0)
	avatar.ring:SetAllPoints()
	avatar.base = Circle(avatar, "BORDER", 1)
	avatar.base:SetPoint("TOPLEFT", ring, -ring)
	avatar.base:SetPoint("BOTTOMRIGHT", -ring, ring)
	avatar.fill = Circle(avatar, "BORDER", 2)
	avatar.fill:SetAllPoints(avatar.base)
	avatar.letter = K.Text(avatar, math.floor(size * 0.42), "text", "CENTER")
	avatar.letter:SetPoint("CENTER", 0, 0)
	function avatar:Set(name, class)
		local r, g, b = K.ClassRGB(class)
		self.ring:SetVertexColor(r, g, b, 0.35)
		local panel = style.palette.cell
		self.base:SetVertexColor(panel[1], panel[2], panel[3], 1)
		self.fill:SetVertexColor(r, g, b, 0.14)
		-- The first character, umlauts included.
		self.letter:SetText((name or "?"):match("^[%z\1-\127\194-\244][\128-\191]*") or "?")
		self.letter:SetTextColor(r, g, b)
	end
	return avatar
end

-- Buttons side by side in one box, one of them active: a dot and label
-- each. items: { { key, label, colorName } }; onSelect(key).
function K.Segmented(parent, items, onSelect, height)
	local box = K.Box(parent, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.08 })
	height = height or 26
	box:SetHeight(height)
	box.buttons = {}
	local x = 3
	for _, item in ipairs(items) do
		local button = CreateFrame("Button", nil, box)
		button.key, button.colorName = item[1], item[3]
		button.bg = K.Texture(button, "BACKGROUND", 0, 0, 0, 0)
		button.bg:SetAllPoints()
		button.text = K.Text(button, 11, "textMuted", "CENTER")
		button.text:SetText(item[2])
		if item[3] ~= false then
			button.dot = Circle(button, "ARTWORK")
			button.dot:SetSize(5, 5)
			button.dot:SetPoint("LEFT", 10, 0)
			button.text:SetPoint("LEFT", button.dot, "RIGHT", 6, 0)
		else
			button.text:SetPoint("CENTER")
		end
		local width = button.text:GetStringWidth() + (button.dot and 32 or 24)
		button:SetSize(width, height - 6)
		button:SetPoint("LEFT", x, 0)
		x = x + width
		button:SetScript("OnClick", function(self)
			box:Select(self.key)
			onSelect(self.key)
		end)
		box.buttons[#box.buttons + 1] = button
	end
	box:SetWidth(x + 3)
	function box:Select(key)
		self.selected = key
		for _, button in ipairs(self.buttons) do
			local on = button.key == key
			local name = on and button.colorName or nil
			if on then
				local color = K.Color(name or "accent")
				button.bg:SetVertexColor(color[1], color[2], color[3], 0.25)
				button.text:SetTextColor(K.RGB(name and name or "textStrong"))
			else
				button.bg:SetVertexColor(0, 0, 0, 0)
				button.text:SetTextColor(K.RGB("textMuted"))
			end
			if button.dot then
				if on and name then
					button.dot:SetVertexColor(K.RGB(name))
				else
					button.dot:SetVertexColor(K.RGB(on and "textStrong" or "textFaint"))
				end
			end
		end
	end
	return box
end

-- A flat single-line input with a muted placeholder. onChange(text) runs on
-- the player's edits.
function K.Input(parent, placeholder, onChange, height)
	local box = K.Box(parent, { 0, 0, 0, 0.25 }, { 1, 1, 1, 0.10 })
	box:SetHeight(height or 30)
	local edit = CreateFrame("EditBox", nil, box)
	edit:SetPoint("TOPLEFT", 10, 0)
	edit:SetPoint("BOTTOMRIGHT", -10, 0)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetTextColor(K.RGB("textStrong"))
	edit.placeholder = K.Text(box, 11, "textFaint")
	edit.placeholder:SetPoint("LEFT", edit, "LEFT", 0, 0)
	edit.placeholder:SetText(placeholder or "")
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnEnterPressed", edit.ClearFocus)
	edit:SetScript("OnTextChanged", function(self, userInput)
		self.placeholder:SetShown(self:GetText() == "")
		if userInput and onChange then
			onChange(self:GetText())
		end
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function()
		edit:SetFocus()
	end)
	box.edit = edit
	function box:SetText(text)
		edit:SetText(text or "")
		edit:SetCursorPosition(0)
		edit.placeholder:SetShown((text or "") == "")
	end
	return box
end

-- A vertical scroll area: `scroll.child` holds the content, whose height is
-- set with SetContentHeight; mouse wheel and a thin draggable bar scroll it.
function K.Scroll(parent, step)
	local scroll = CreateFrame("ScrollFrame", nil, parent)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	scroll.child = child
	scroll:SetScript("OnSizeChanged", function(self, width)
		child:SetWidth(width)
		self:UpdateBar()
	end)

	local bar = CreateFrame("Slider", nil, scroll)
	bar:SetOrientation("VERTICAL")
	bar:SetPoint("TOPRIGHT", 8, 0)
	bar:SetPoint("BOTTOMRIGHT", 8, 0)
	bar:SetWidth(4)
	bar:SetMinMaxValues(0, 0)
	bar:SetValueStep(1)
	bar:SetObeyStepOnDrag(false)
	bar.thumb = K.Texture(bar, "OVERLAY", 1, 1, 1, 0.18)
	bar.thumb:SetSize(4, 40)
	bar:SetThumbTexture(bar.thumb)
	bar:SetScript("OnValueChanged", function(_, value)
		scroll:SetVerticalScroll(value)
	end)
	scroll.bar = bar

	function scroll:SetContentHeight(height)
		child:SetHeight(math.max(height, 1))
		self:UpdateBar()
	end
	function scroll:UpdateBar()
		local range = math.max(0, child:GetHeight() - self:GetHeight())
		bar:SetMinMaxValues(0, range)
		bar:SetShown(range > 0)
		local visible = self:GetHeight()
		if visible > 0 and child:GetHeight() > 0 then
			bar.thumb:SetHeight(math.max(24, visible * visible / child:GetHeight()))
		end
		if bar:GetValue() > range then
			bar:SetValue(range)
		end
	end
	function scroll:ScrollTo(offset)
		local _, max = bar:GetMinMaxValues()
		bar:SetValue(math.max(0, math.min(max, offset)))
	end
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		self:ScrollTo(bar:GetValue() - delta * (step or 60))
	end)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		if self.onScroll then
			self.onScroll(offset)
		end
	end)
	return scroll
end

-- Five stars, lit up to `value`; clicks set the rating, a click on the
-- current one clears it. onChange(stars or nil); without onChange they only show.
function K.Stars(parent, size, onChange, gap)
	local frame = CreateFrame("Frame", nil, parent)
	gap = gap or 3
	frame:SetSize(5 * size + 4 * gap, size)
	frame.stars = {}
	function frame:SetValue(value)
		self.value = value
		for index, star in ipairs(self.stars) do
			-- Averages light a star from three quarters on (4.8 shows 5, 1.5 shows 1).
			local lit = value and index <= value + 0.25
			star.icon:SetDesaturated(not lit)
			star.icon:SetAlpha(lit and 1 or 0.25)
		end
	end
	for index = 1, 5 do
		local star = CreateFrame(onChange and "Button" or "Frame", nil, frame)
		star:SetSize(size, size)
		star:SetPoint("LEFT", (index - 1) * (size + gap), 0)
		star.icon = star:CreateTexture(nil, "ARTWORK")
		star.icon:SetAllPoints()
		star.icon:SetTexture(K.ICON_STAR)
		if onChange then
			star:SetScript("OnClick", function()
				local value = frame.value ~= index and index or nil
				frame:SetValue(value)
				onChange(value)
			end)
		end
		frame.stars[index] = star
	end
	frame:SetValue(nil)
	return frame
end

-- A context menu at `owner`: entries { { text, onClick } }.
function K.Menu(owner, entries)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, entry in ipairs(entries) do
			root:CreateButton(entry[1], entry[2])
		end
	end)
end

-- Lays frames out from the top of `parent`: place(frame, height, gap)
-- anchors it below the previous one across the full width.
function K.Stack(parent, inset)
	local stack = { y = 0 }
	function stack:Place(frame, height, gap)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", inset or 0, -self.y)
		frame:SetPoint("RIGHT", parent, "RIGHT", -(inset or 0), 0)
		frame:SetHeight(height)
		frame:Show()
		self.y = self.y + height + (gap or 16)
	end
	return stack
end

-- Frames recycled by index: pool:Get(index) creates them with `create`,
-- pool:HideFrom(n) hides the rest.
function K.Pool(create)
	local pool = { frames = {} }
	function pool:Get(index)
		local frame = self.frames[index]
		if not frame then
			frame = create(index)
			self.frames[index] = frame
		end
		frame:Show()
		return frame
	end
	function pool:HideFrom(first)
		for index = first, #self.frames do
			self.frames[index]:Hide()
		end
	end
	return pool
end
