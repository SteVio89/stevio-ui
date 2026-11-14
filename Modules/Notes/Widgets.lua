local _, ns = ...

-- Building blocks shared by the notes window, the popup after a group and the
-- item note box: buttons, inputs, text areas, star ratings, role buttons and
-- a scrolling list.

local W = {}
ns.NotesWidgets = W

local Store = ns.NotesStore
local config = ns.config.notes
local colors = config.colors
local T = ns.T

W.STAR_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

local ROLE_NAMES = {
	TANK = { "Tank", "Tank" },
	HEALER = { "Healer", "Heiler" },
	DAMAGER = { "DPS", "DPS" },
}

function W.RoleName(role)
	local names = ROLE_NAMES[role]
	return names and T(names[1], names[2]) or "–"
end

-- "★ 4.3 (3)" with the star as a texture, since the game fonts have none.
function W.Rating(entry)
	if not entry then
		return "–"
	end
	return ("|T%s:0|t %s (%d)"):format(W.STAR_TEXTURE, Store.FormatAverage(entry.average), entry.count)
end

-- "★ 3.8 (4) · Healer 4.3 (3) · DPS 2.0 (1)", or nil when nothing is rated.
function W.SummaryText(player)
	local summary = Store.Summary(player)
	if not summary.overall then
		return nil
	end
	local parts = { W.Rating(summary.overall) }
	for _, role in ipairs(Store.ROLES) do
		local entry = summary[role]
		if entry then
			parts[#parts + 1] = ("%s %s (%d)"):format(W.RoleName(role), Store.FormatAverage(entry.average), entry.count)
		end
	end
	return table.concat(parts, " · ")
end

-- Why a player is marked: "guild <Name> (matches "pattern")", plus where
-- they were seen since when that is another guild. Nil when not marked.
function W.BlockReason(player)
	local blocked = player.blocked
	if not blocked then
		return nil
	end
	local text = T('guild <%s> (matches "%s")', 'Gilde <%s> (passt zu "%s")'):format(
		blocked.guild or "?",
		blocked.pattern or "?"
	)
	if player.guild and player.guild ~= blocked.guild then
		text = text .. T(", since seen in <%s>", ", seitdem gesehen in <%s>"):format(player.guild)
	end
	return text
end

function W.ClassColored(name, class)
	local color = class and C_ClassColor.GetClassColor(class)
	return color and color:WrapTextInColorCode(name) or name
end

function W.Date(time)
	return time and date("%d.%m.%y", time) or ""
end

function W.Button(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 80, 22)
	button:SetText(text)
	return button
end

-- A single-line input; `onChange(text)` runs on every edit by the player.
function W.Input(parent, width, onChange)
	local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	input:SetSize(width, 20)
	input:SetAutoFocus(false)
	input:SetScript("OnEnterPressed", input.ClearFocus)
	input:SetScript("OnEscapePressed", input.ClearFocus)
	input:SetScript("OnTextChanged", function(self, userInput)
		if userInput and onChange then
			onChange(self:GetText())
		end
	end)
	return input
end

-- A boxed multi-line text area; `onChange(text)` runs on every edit by the player.
function W.TextArea(parent, onChange)
	local box = CreateFrame("Frame", nil, parent)
	ns.CreateBackground(box, { 0, 0, 0, 0.5 })
	ns.CreateBorder(box)

	local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 6, -6)
	scroll:SetPoint("BOTTOMRIGHT", -26, 6)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetWidth(100)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and onChange then
			onChange(self:GetText())
		end
	end)
	-- Keeps the cursor in view while typing past the bottom (Blizzard's helpers).
	if ScrollingEdit_OnCursorChanged and ScrollingEdit_OnUpdate then
		edit:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
		edit:SetScript("OnUpdate", function(self, elapsed)
			ScrollingEdit_OnUpdate(self, elapsed, scroll)
		end)
	end
	scroll:SetScrollChild(edit)
	-- Scroll children need an explicit width; anchors don't size them.
	scroll:SetScript("OnSizeChanged", function(_, width)
		edit:SetWidth(width)
	end)
	-- The whole box focuses the text, not only its lines.
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function()
		edit:SetFocus()
	end)

	box.edit = edit
	function box:SetText(text)
		edit:SetText(text or "")
		edit:SetCursorPosition(0)
	end
	return box
end

-- Five stars; a click sets the rating, a click on the current one clears it.
-- `onChange(stars or nil)`.
function W.Stars(parent, size, onChange)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(Store.MAX_STARS * (size + 2), size)
	frame.buttons = {}
	frame.value = nil

	function frame:SetValue(value)
		self.value = value
		for index, button in ipairs(self.buttons) do
			local lit = value and index <= value
			button.icon:SetDesaturated(not lit)
			button.icon:SetAlpha(lit and 1 or 0.3)
		end
	end

	for index = 1, Store.MAX_STARS do
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(size, size)
		button:SetPoint("LEFT", (index - 1) * (size + 2), 0)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button.icon:SetTexture(W.STAR_TEXTURE)
		button:SetScript("OnClick", function()
			local value = frame.value ~= index and index or nil
			frame:SetValue(value)
			onChange(value)
		end)
		frame.buttons[index] = button
	end
	frame:SetValue(nil)
	return frame
end

-- A button showing a role; clicks cycle none, tank, healer, DPS.
-- `onChange(role or nil)`.
function W.RoleButton(parent, width, onChange)
	local button = W.Button(parent, "", width)
	function button:SetRole(role)
		self.role = role
		self:SetText(W.RoleName(role))
	end
	button:SetScript("OnClick", function(self)
		self:SetRole(Store.NextRole(self.role))
		onChange(self.role)
	end)
	button:SetRole(nil)
	return button
end

-- One session of a player: a label (date and place, or the name), role,
-- stars and comment. Edits go straight into the session; `onChange()` runs after.
function W.SessionRow(parent, labelWidth, onChange)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(24)

	row.label = ns.CreateFontString(row)
	row.label:SetPoint("LEFT", 2, 0)
	row.label:SetWidth(labelWidth)

	row.role = W.RoleButton(row, 64, function(role)
		row.session.role = role
		onChange(row)
	end)
	row.role:SetPoint("LEFT", row.label, "RIGHT", 6, 0)

	row.stars = W.Stars(row, 16, function(stars)
		Store.Rate(row.session, stars)
		onChange(row)
	end)
	row.stars:SetPoint("LEFT", row.role, "RIGHT", 8, 0)

	row.comment = W.Input(row, 100, function(text)
		Store.SetComment(row.session, text)
		onChange(row)
	end)
	row.comment:SetPoint("LEFT", row.stars, "RIGHT", 12, 0)
	row.comment:SetPoint("RIGHT", -4, 0)

	function row:Set(session, label)
		self.session = session
		self.label:SetText(label)
		self.role:SetRole(session.role)
		self.stars:SetValue(session.stars)
		self.comment:SetText(session.comment or "")
		self.comment:SetCursorPosition(0)
	end
	return row
end

-- A scrolling list of clickable rows. `render(row, item)` fills a row (it has
-- `left` and `right` font strings and an `icon`); `onClick(item)`.
function W.List(parent, rowHeight, onClick)
	local list = CreateFrame("Frame", nil, parent)
	local scroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT")
	scroll:SetPoint("BOTTOMRIGHT", -22, 0)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	scroll:SetScript("OnSizeChanged", function(_, width)
		content:SetWidth(width)
	end)
	list.rows, list.items = {}, {}

	local function CreateRow(index)
		local row = CreateFrame("Button", nil, content)
		row:SetHeight(rowHeight)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * rowHeight)
		row:SetPoint("RIGHT")
		row.highlight = row:CreateTexture(nil, "BACKGROUND")
		row.highlight:SetAllPoints()
		row.highlight:SetColorTexture(unpack(colors.selected))
		row.highlight:Hide()
		local hover = row:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(unpack(colors.hover))
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(rowHeight - 4, rowHeight - 4)
		row.icon:SetPoint("LEFT", 2, 0)
		ns.CropIcon(row.icon)
		row.right = ns.CreateFontString(row, nil, "RIGHT")
		row.right:SetPoint("RIGHT", -4, 0)
		row.left = ns.CreateFontString(row)
		row.left:SetPoint("LEFT", 4, 0)
		row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
		row:SetScript("OnClick", function(self)
			onClick(self.item)
		end)
		return row
	end

	function list:SetItems(items, render, selected)
		self.items = items
		for index, item in ipairs(items) do
			local row = self.rows[index] or CreateRow(index)
			self.rows[index] = row
			row.item = item
			row.icon:Hide()
			row.left:ClearAllPoints()
			row.left:SetPoint("LEFT", 4, 0)
			row.left:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
			render(row, item)
			if row.icon:IsShown() then
				row.left:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
			end
			row.highlight:SetShown(item == selected)
			row:Show()
		end
		for index = #items + 1, #self.rows do
			self.rows[index]:Hide()
		end
		content:SetHeight(math.max(#items * rowHeight, 1))
	end

	-- Shows the icon in a row being rendered.
	function list.ShowIcon(row, texture)
		row.icon:SetTexture(texture)
		row.icon:Show()
	end
	return list
end
