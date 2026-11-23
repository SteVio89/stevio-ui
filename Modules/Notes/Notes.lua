local _, ns = ...

-- Notes on item types and general notes; see docs/notes.md. Notes on players
-- are part of the player database (Modules/Players). This file connects the
-- store to the game: item tooltips, Alt+right-click on items, the notch
-- button and /sui notes.

local Notes = ns.RegisterModule("notes", {})
ns.Notes = Notes

local Store = ns.NotesStore
local config = ns.config.notes
local T = ns.T

local NOTE_COLOR = "|cffd9d999"

-- Tooltips ---------------------------------------------------------------------

local function AddItemLines(tooltip, data)
	if not config.showInTooltip then
		return
	end
	local itemID = data and data.id
	if issecretvalue(itemID) or not itemID then
		return
	end
	local text = Notes.store:ItemNote(itemID)
	if text then
		tooltip:AddLine(NOTE_COLOR .. T("Note: ", "Notiz: ") .. text .. "|r", 1, 1, 1, true)
	end
end

-- Notch button -----------------------------------------------------------------

local function CreateNotchButton()
	if not ns.NotchButtons then
		return
	end
	-- Parked in a hidden frame until the notch island adopts it.
	local parking = CreateFrame("Frame")
	parking:Hide()
	local size = ns.config.notch.buttonSize
	local button = CreateFrame("Button", "StevioUI_NotesButton", parking)
	button:SetSize(size, size)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
	ns.CropIcon(icon)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnClick", ns.NotesWindow.Toggle)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(T("Notes", "Notizen"))
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	ns.NotchButtons.AddOwn(button, "StevioUI_Notes")
end

function Notes:OnEnable()
	self.store = Store.New(StevioUINotes)
	StevioUINotes = self.store.db

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddItemLines)

	-- Bags, bank and chat links all pass modified clicks through here.
	hooksecurefunc("HandleModifiedItemClick", function(link)
		if
			link
			and IsAltKeyDown()
			and not IsShiftKeyDown()
			and not IsControlKeyDown()
			and GetMouseButtonClicked() == "RightButton"
		then
			ns.NotesItemBox.Open(link)
		end
	end)

	CreateNotchButton()
end

-- /sui notes toggles the window; /sui notes <item link> edits that item's note.
ns.RegisterModuleCommand("notes", "notes", function(input)
	local itemString = input:match("item:[%-%d:]+")
	if itemString then
		ns.NotesItemBox.Open(itemString)
	else
		ns.NotesWindow.Toggle()
	end
end)
