local _, ns = ...

-- After leaving a group: a small window listing its players with role, stars
-- and a comment field. Ratings are saved as they are clicked; "Later" just
-- closes it, the players stay unrated in the notes window.

local Popup = {}
ns.NotesPopup = Popup

local W = ns.NotesWidgets
local T = ns.T

local ROW_HEIGHT = 26

local frame

local function CreatePopup()
	frame = CreateFrame("Frame", "StevioUI_NotesPopup", UIParent)
	frame:SetWidth(640)
	frame:SetPoint("TOP", 0, -140)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	ns.CreateBackground(frame, { 0.05, 0.05, 0.05, 0.95 })
	ns.CreateBorder(frame)
	tinsert(UISpecialFrames, frame:GetName())

	frame.title = ns.CreateFontString(frame, 14)
	frame.title:SetPoint("TOPLEFT", 12, -10)
	frame.title:SetText(T("Rate your group", "Bewerte deine Gruppe"))
	frame.place = ns.CreateFontString(frame)
	frame.place:SetPoint("LEFT", frame.title, "RIGHT", 10, 0)
	frame.place:SetPoint("RIGHT", -120, 0)
	frame.place:SetTextColor(unpack(ns.config.notes.colors.dim))

	frame.close = W.Button(frame, "", 100)
	frame.close:SetPoint("TOPRIGHT", -8, -6)
	frame.close:SetScript("OnClick", function()
		frame:Hide()
	end)

	frame.rows = {}
end

local function OnRated()
	frame.close:SetText(T("Done", "Fertig"))
	ns.NotesWindow.Refresh()
end

-- entries: { name, class, session } of the players of the group just left.
function Popup.Show(entries)
	if not frame then
		CreatePopup()
	end
	frame.close:SetText(T("Later", "Später"))
	local first = entries[1] and entries[1].session
	frame.place:SetText(first and first.where or "")

	for index, entry in ipairs(entries) do
		local row = frame.rows[index]
		if not row then
			row = W.SessionRow(frame, 150, OnRated)
			row:SetPoint("TOPLEFT", 8, -36 - (index - 1) * ROW_HEIGHT)
			row:SetPoint("RIGHT", -8, 0)
			frame.rows[index] = row
		end
		row:Set(entry.session, W.ClassColored(entry.name, entry.class))
		row:Show()
	end
	for index = #entries + 1, #frame.rows do
		frame.rows[index]:Hide()
	end
	frame:SetHeight(36 + #entries * ROW_HEIGHT + 10)
	frame:Show()
end
