local _, ns = ...

-- The small box Alt+right-click on an item opens: the note for that item type,
-- with Save and Remove (saving empty text removes it too).

local ItemBox = {}
ns.NotesItemBox = ItemBox

local W = ns.NotesWidgets
local T = ns.T

local frame

local function Close()
	frame.text.edit:ClearFocus()
	frame:Hide()
end

local function Save()
	ns.Notes.store:SetItemNote(frame.itemID, frame.text.edit:GetText(), time())
	ns.NotesWindow.Refresh()
	Close()
end

local function CreateBox()
	frame = CreateFrame("Frame", "StevioUI_NotesItemBox", UIParent)
	frame:SetSize(340, 170)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	ns.CreateBackground(frame, { 0.05, 0.05, 0.05, 0.95 })
	ns.CreateBorder(frame)
	tinsert(UISpecialFrames, frame:GetName())

	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(20, 20)
	frame.icon:SetPoint("TOPLEFT", 10, -10)
	ns.CropIcon(frame.icon)
	frame.name = ns.CreateFontString(frame, 12)
	frame.name:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
	frame.name:SetPoint("RIGHT", -10, 0)

	frame.text = W.TextArea(frame)
	frame.text:SetPoint("TOPLEFT", 10, -38)
	frame.text:SetPoint("BOTTOMRIGHT", -10, 40)
	-- Enter saves; Shift+Enter starts a new line.
	frame.text.edit:SetScript("OnEnterPressed", function(self)
		if IsShiftKeyDown() then
			self:Insert("\n")
		else
			Save()
		end
	end)
	frame.text.edit:SetScript("OnEscapePressed", Close)

	local save = W.Button(frame, T("Save", "Speichern"), 90)
	save:SetPoint("BOTTOMRIGHT", -10, 10)
	save:SetScript("OnClick", Save)
	local remove = W.Button(frame, T("Remove", "Entfernen"), 90)
	remove:SetPoint("RIGHT", save, "LEFT", -6, 0)
	remove:SetScript("OnClick", function()
		frame.text.edit:SetText("")
		Save()
	end)
	local cancel = W.Button(frame, CANCEL, 90)
	cancel:SetPoint("RIGHT", remove, "LEFT", -6, 0)
	cancel:SetScript("OnClick", Close)
end

-- Opens the box for the item in `link` (an item link or ID) next to the cursor.
function ItemBox.Open(link)
	local itemID = C_Item.GetItemInfoInstant(link)
	if not itemID then
		return
	end
	if not frame then
		CreateBox()
	end
	frame.itemID = itemID
	frame.icon:SetTexture(C_Item.GetItemIconByID(itemID))
	-- A full link shows in its quality colour; an item string or ID by name.
	local isLink = type(link) == "string" and link:find("|H", 1, true)
	frame.name:SetText(isLink and link or C_Item.GetItemNameByID(itemID) or ("item:" .. itemID))
	frame.text:SetText(ns.Notes.store:ItemNote(itemID))

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale - 10)
	frame:Show()
	frame.text.edit:SetFocus()
	frame.text.edit:SetCursorPosition(frame.text.edit:GetNumLetters())
end
