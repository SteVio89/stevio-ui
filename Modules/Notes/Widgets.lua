local _, ns = ...

-- Building blocks shared by the notes window, the item note box and the
-- player database (Modules/Players): buttons, inputs, text areas and a
-- scrolling list.

local W = {}
ns.NotesWidgets = W

local config = ns.config.notes
local colors = config.colors

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
