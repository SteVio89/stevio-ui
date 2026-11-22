local _, ns = ...

local config = ns.config.chat
local preview = config.preview
local C = ns.ChatInternal

-- New lines while the chat is hidden (#69): instead of popping up the whole
-- chat they show for a moment as lines of text where the chat sits, without
-- a background, the newest at the bottom. A line under the cursor stays; a
-- click opens the chat on its channel. Which lines show is decided in
-- Receive.lua (C.Delivery).

local PADDING = 4

-- The lines shown, oldest first: { key, line, r, g, b, age }.
local items = {}
local container
local rows = {}

local function RowHeight()
	return config.fontSize + 6
end

local function OpenAt(key)
	C.ClearPreview()
	if C.hidden then
		ns.ToggleChat()
	end
	C.Select(key)
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, container)
	row:SetHeight(RowHeight())
	row:SetPoint("TOPLEFT", 0, -(index - 1) * RowHeight())
	row.text = ns.CreateFontString(row, config.fontSize, "LEFT")
	row.text:SetPoint("LEFT", PADDING, 0)
	row:SetScript("OnClick", function(self)
		OpenAt(self.key)
	end)
	rows[index] = row
	return row
end

local function Render()
	local maxWidth = C.ChatWidth() - 2 * PADDING
	for index, item in ipairs(items) do
		local row = rows[index] or CreateRow(index)
		row.key = item.key
		-- Measured unbounded first; a long line is cut to the chat's width.
		row.text:SetWidth(0)
		row.text:SetText(item.line)
		row.text:SetTextColor(item.r, item.g, item.b)
		local width = math.min(row.text:GetStringWidth(), maxWidth)
		row.text:SetWidth(width)
		row:SetWidth(width + 2 * PADDING)
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
	container:SetSize(C.ChatWidth(), math.max(1, preview.maxRows) * RowHeight())
	container:SetFrameStrata("MEDIUM")
	container:Hide()
	container:SetScript("OnUpdate", OnUpdate)
end
