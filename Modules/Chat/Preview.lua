local _, ns = ...

local config = ns.config.chat
local preview = config.preview
local C = ns.ChatInternal

-- New lines while the chat is hidden (#69): instead of popping up the whole
-- chat they show for a moment as lines of text where the chat sits, without
-- a background, the newest at the bottom. A line under the cursor stays; a
-- click opens the chat on its channel. Which lines show is decided in
-- Receive.lua (C.Delivery).
-- A long message wraps onto as many lines as it needs (#79); the oldest
-- preview lines drop out once they no longer fit where the chat sits.

local PADDING = 4
-- Space above and below a preview line's text.
local SPACING = 3

-- The lines shown, oldest first: { key, line, r, g, b, age }.
local items = {}
local container
local rows = {}

local function OpenAt(key)
	C.ClearPreview()
	if C.hidden then
		ns.ToggleChat()
	end
	C.Select(key)
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, container)
	row.text = ns.CreateFontString(row, config.fontSize, "LEFT")
	row.text:SetWordWrap(true)
	row.text:SetNonSpaceWrap(true)
	row.text:SetPoint("TOPLEFT", PADDING, -SPACING)
	row:SetScript("OnClick", function(self)
		OpenAt(self.key)
	end)
	rows[index] = row
	return row
end

-- Fills `row` with `item` and sizes it to its text: as wide as the text, at
-- most the chat's width, and as high as the lines the text wraps onto.
local function Fill(row, item, maxWidth)
	row.key = item.key
	-- Measured unbounded first; a longer line wraps at the chat's width.
	row.text:SetWidth(0)
	row.text:SetText(item.line)
	row.text:SetTextColor(item.r, item.g, item.b)
	local width = math.min(row.text:GetUnboundedStringWidth(), maxWidth)
	row.text:SetWidth(width)
	row:SetSize(width + 2 * PADDING, row.text:GetStringHeight() + 2 * SPACING)
end

local function Render()
	local maxWidth = C.ChatWidth() - 2 * PADDING
	local heights = {}
	for index, item in ipairs(items) do
		local row = rows[index] or CreateRow(index)
		Fill(row, item, maxWidth)
		heights[index] = row:GetHeight()
	end
	-- The oldest lines that no longer fit where the chat sits drop out.
	local overflow = C.PreviewOverflow(heights, container:GetHeight())
	if overflow > 0 then
		for _ = 1, overflow do
			table.remove(items, 1)
		end
		for index, item in ipairs(items) do
			Fill(rows[index], item, maxWidth)
		end
	end
	local top = 0
	for index, item in ipairs(items) do
		local row = rows[index]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 0, -top)
		top = top + row:GetHeight()
		row:SetAlpha(C.PreviewAlpha(item.age, preview.holdTime, preview.fadeOutTime))
		row:Show()
	end
	for index = #items + 1, #rows do
		rows[index]:Hide()
	end
	container:SetShown(#items > 0)
end

local function IsHovered()
	for index = 1, #items do
		if rows[index] and rows[index]:IsMouseOver() then
			return true
		end
	end
	return false
end

local function OnUpdate(_, elapsed)
	-- Lines don't age while one of them is under the cursor.
	if IsHovered() then
		return
	end
	local gone = false
	for index = #items, 1, -1 do
		local item = items[index]
		item.age = item.age + elapsed
		local alpha = C.PreviewAlpha(item.age, preview.holdTime, preview.fadeOutTime)
		if alpha <= 0 then
			table.remove(items, index)
			gone = true
		elseif rows[index] then
			rows[index]:SetAlpha(alpha)
		end
	end
	if gone then
		Render()
	end
end

-- Shows `entry` of `channel` as a preview line.
function C.ShowPreview(channel, entry)
	local line, r, g, b = C.FormatEntry(channel, entry, C.TypeColor)
	C.PushPreview(items, {
		key = channel.key,
		line = line,
		r = r or 1,
		g = g or 1,
		b = b or 1,
		age = 0,
	}, preview.maxRows)
	Render()
end

function C.ClearPreview()
	if #items == 0 then
		return
	end
	for index = #items, 1, -1 do
		items[index] = nil
	end
	Render()
end

function C.CreatePreview()
	container = CreateFrame("Frame", "StevioUI_ChatPreview", UIParent)
	container:SetPoint("TOPLEFT", C.ui.frame, "TOPLEFT")
	-- As big as the chat; a single message taller than that is cut off.
	container:SetSize(C.ChatWidth(), config.height)
	container:SetClipsChildren(true)
	container:SetFrameStrata("MEDIUM")
	container:Hide()
	container:SetScript("OnUpdate", OnUpdate)
end
