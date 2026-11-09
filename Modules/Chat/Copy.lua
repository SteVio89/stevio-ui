local _, ns = ...

local config = ns.config.chat
local style = ns.config.style
local C = ns.ChatInternal

-- WoW's message frames can't select text, so "Copy" shows the channel as plain
-- text in an edit box: select with the mouse (all of it is pre-selected) and Ctrl+C.

local function ToggleCopy()
	local copy = C.ui.copy
	if copy:IsShown() then
		copy:Hide()
		return
	end
	local channel = C.Selected()
	if not channel then
		return
	end
	copy.text = ns.ChatHistory.Transcript(channel, function(t)
		return date("%H:%M", t)
	end, C.Day)
	copy:Show()
	copy.edit:SetText(copy.text)
	copy.edit:SetFocus()
	copy.edit:HighlightText()
end

-- Covers the message area of the channel view; the "Copy" button sits in its header row.
function C.CreateCopyView(frame)
	local ui = C.ui
	local copy = CreateFrame("Frame", nil, frame)
	copy:SetFrameLevel(frame:GetFrameLevel() + 10)
	copy:SetPoint("TOPLEFT", ui.messages)
	copy:SetPoint("BOTTOMRIGHT", ui.messages)
	copy:Hide()
	ns.CreateBackground(copy, config.backgroundColor)

	local scroll = CreateFrame("ScrollFrame", nil, copy)
	scroll:SetAllPoints()
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local target = self:GetVerticalScroll() - delta * config.scrollStep * config.fontSize
		self:SetVerticalScroll(Clamp(target, 0, self:GetVerticalScrollRange()))
	end)

	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFont(style.font, config.fontSize, style.fontFlags)
	edit:SetMaxLetters(0)
	edit:SetWidth(C.ChatWidth() - config.sidebarWidth - 12)
	scroll:SetScrollChild(edit)
	scroll:SetScript("OnSizeChanged", function(_, width)
		edit:SetWidth(width)
	end)
	-- Read-only: any edit snaps back to the transcript.
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and self:GetText() ~= copy.text then
			self:SetText(copy.text)
			self:HighlightText()
		end
	end)
	edit:SetScript("OnEscapePressed", function()
		copy:Hide()
	end)
	-- Keep the caret in view while selecting with the mouse.
	edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
		local top, height = scroll:GetVerticalScroll(), scroll:GetHeight()
		y = -y
		if y < top then
			scroll:SetVerticalScroll(y)
		elseif y + h > top + height then
			scroll:SetVerticalScroll(y + h - height)
		end
	end)
	-- Ctrl+C is the end of the job: close once copied.
	edit:SetScript("OnKeyDown", function(_, key)
		if key == "C" and IsControlKeyDown() then
			C_Timer.After(0, function()
				copy:Hide()
			end)
		end
	end)
	copy:SetScript("OnHide", function()
		edit:ClearFocus()
	end)
	copy.edit = edit
	ui.copy = copy

	local button = CreateFrame("Button", nil, frame)
	button:SetHeight(config.rowHeight)
	button:SetPoint("TOPRIGHT", -6, 0)
	button.text = ns.CreateFontString(button, nil, "RIGHT")
	button.text:SetAllPoints()
	button.text:SetText(ns.T("Copy", "Kopieren"))
	button:SetWidth(button.text:GetStringWidth() + 4)
	button:SetScript("OnClick", ToggleCopy)
	ui.header:SetPoint("TOPRIGHT", button, "TOPLEFT", -6, 0)
end
