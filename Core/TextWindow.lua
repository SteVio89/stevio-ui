local addonName, ns = ...

-- A window showing text to select and copy: the profile export, the error log
-- and debug dumps.

local window

local function CreateWindow()
	local frame = CreateFrame("Frame", "StevioUI_ExportWindow", UIParent)
	local width, height = 760, 560
	frame:SetSize(width, height)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	ns.CreateBackground(frame, { 0.05, 0.05, 0.05, 0.95 })
	ns.CreateBorder(frame)
	-- Lets Escape close the window like any Blizzard panel.
	tinsert(UISpecialFrames, frame:GetName())

	local title = ns.CreateFontString(frame, 12)
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText(
		ns.T("%s – select all and copy (Cmd+A, Cmd+C)", "%s – alles markieren und kopieren (Cmd+A, Cmd+C)")
			:format(addonName)
	)

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -32)
	scroll:SetPoint("BOTTOMRIGHT", -30, 10)

	local editBox = CreateFrame("EditBox", nil, scroll)
	editBox:SetMultiLine(true)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(ChatFontNormal)
	-- Scroll children need an explicit width; anchors don't size them.
	editBox:SetWidth(width - 40)
	editBox:SetScript("OnEscapePressed", function()
		frame:Hide()
	end)
	scroll:SetScrollChild(editBox)

	frame.editBox = editBox
	return frame
end

function ns.ShowTextWindow(text)
	window = window or CreateWindow()
	window.editBox:SetText(text)
	window:Show()
	window.editBox:SetFocus()
	window.editBox:HighlightText()
end

-- Debug output also goes to a saved variable, to read it from the WTF folder.
function ns.ShowDebugDump(text)
	StevioUIDebug = text
	ns.ShowTextWindow(text)
end
