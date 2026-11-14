local _, ns = ...

-- Notes on players you group with (sessions with role, stars and comment),
-- on item types and general notes; see docs/notes.md. This file connects the
-- store to the game: group and zone tracking, tooltips, Alt+right-click on
-- items, the notch button and /sui notes.

local Notes = ns.RegisterModule("notes", {})
ns.Notes = Notes

local Store = ns.NotesStore
local W = ns.NotesWidgets
local config = ns.config.notes
local T = ns.T

local NOTE_COLOR = "|cffd9d999"

-- Sessions that ended while in the current group, for the popup on leaving it.
local ended = {}

-- The name players are stored under: "Name" on your realm, else "Name-Realm",
-- as Ambiguate(..., "none") gives it for chat names too. Nil while the name
-- isn't known yet or is secret.
local function UnitKey(unit)
	local name, realm = UnitName(unit)
	if not name or issecretvalue(name) or issecretvalue(realm) or name == "" or name == UNKNOWNOBJECT then
		return nil
	end
	if realm and realm ~= "" then
		name = name .. "-" .. realm
	end
	return Ambiguate(name, "none")
end

-- Where you are: an instance (dungeon, raid, battleground, ...) by name, or
-- else the zone.
local function CurrentPlace()
	local name, instanceType = GetInstanceInfo()
	if instanceType and instanceType ~= "none" and name and name ~= "" then
		return name, true
	end
	local zone = GetRealZoneText() or ""
	if zone == "" then
		zone = GetZoneText() or ""
	end
	return zone ~= "" and zone or nil, false
end

local function GroupUnits()
	local units = {}
	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			units[#units + 1] = "raid" .. index
		end
	else
		for index = 1, GetNumSubgroupMembers() do
			units[#units + 1] = "party" .. index
		end
	end
	return units
end

local function Remind(player)
	if not config.joinReminder or not (player.note or Store.HasRating(player)) then
		return
	end
	local parts = { W.ClassColored(player.name, player.class) }
	parts[#parts + 1] = W.SummaryText(player) or T("not rated", "nicht bewertet")
	if player.note then
		parts[#parts + 1] = NOTE_COLOR .. Store.Title(player.note) .. "|r"
	end
	ns.Print(T("In your group: %s", "In deiner Gruppe: %s"):format(table.concat(parts, " · ")))
end

local function EndSession(name, now)
	local session = Notes.store:Close(name, now)
	if not session then
		return
	end
	for _, entry in ipairs(ended) do
		if entry.session == session then
			return
		end
	end
	ended[#ended + 1] = { name = name, session = session }
end

-- You left the group: offers to rate its players whose sessions are unrated.
local function FinishGroup()
	local entries = {}
	for _, entry in ipairs(ended) do
		local player = Notes.store:Player(entry.name)
		if player and not entry.session.open and not entry.session.stars then
			entries[#entries + 1] = { name = entry.name, class = player.class, session = entry.session }
		end
	end
	ended = {}
	if #entries == 0 or not config.popupAfterGroup then
		return
	end
	if #entries > config.popupMaxPlayers then
		ns.Print(
			T("%d players from your group to rate: /sui notes", "%d Spieler aus deiner Gruppe zu bewerten: /sui notes"):format(
				#entries
			)
		)
	else
		ns.NotesPopup.Show(entries)
	end
end

-- Brings the sessions in line with the group: opens one for each member,
-- closes those of players no longer in it.
local function Sync()
	local store, now = Notes.store, time()
	if not IsInGroup() then
		for _, name in ipairs(store:OpenNames()) do
			EndSession(name, now)
		end
		FinishGroup()
		return
	end

	local place, isInstance = CurrentPlace()
	local own = UnitKey("player")
	local present, complete = {}, true
	for _, unit in ipairs(GroupUnits()) do
		if UnitExists(unit) then
			local name = UnitKey(unit)
			if not name then
				-- Not known yet: keep everyone's sessions until the roster is.
				complete = false
			elseif name ~= own and UnitIsPlayer(unit) then
				present[name] = true
				local _, class = UnitClass(unit)
				local _, isNew = store:Open(name, {
					class = class,
					role = UnitGroupRolesAssigned(unit),
					place = place,
					isInstance = isInstance,
				}, now)
				if isNew then
					Remind(store:Player(name))
				end
			end
		end
	end
	if complete then
		for _, name in ipairs(store:OpenNames()) do
			if not present[name] then
				EndSession(name, now)
			end
		end
	end
end

local function OnZoneChanged()
	local place, isInstance = CurrentPlace()
	Notes.store:Visit(place, isInstance, time())
	Sync()
end

-- Tooltips ---------------------------------------------------------------------

local function AddUnitLines(tooltip)
	if not config.showInTooltip or not tooltip.GetUnit then
		return
	end
	local _, unit = tooltip:GetUnit()
	if not unit or issecretvalue(unit) then
		return
	end
	local isPlayer = UnitIsPlayer(unit)
	if issecretvalue(isPlayer) or not isPlayer then
		return
	end
	local name = UnitKey(unit)
	local player = name and Notes.store:Player(name)
	if not player then
		return
	end
	local summary = W.SummaryText(player)
	if summary then
		tooltip:AddLine(summary, 1, 1, 1)
	end
	if player.note then
		tooltip:AddLine(NOTE_COLOR .. player.note .. "|r", 1, 1, 1, true)
	end
end

local function AddItemLines(tooltip, data)
	if not config.showInTooltip then
		return
	end
	local itemID = data and data.id
	if not itemID or issecretvalue(itemID) then
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
	ns.NotchButtons.AddOwn(button)
end

-- API for other modules --------------------------------------------------------

-- Opens the notes window on a player ("Name-Realm" or "Name"), e.g. from the
-- chat's name menu; false while the module is off.
function ns.OpenPlayerNote(fullName)
	if not Notes.active then
		return false
	end
	local name = Ambiguate(fullName, "none")
	Notes.store:Ensure(name, nil, time())
	ns.NotesWindow.Open("players", name)
	return true
end

function Notes:OnEnable()
	self.store = Store.New(StevioUINotes, { rejoinGrace = config.rejoinGrace })
	StevioUINotes = self.store.db
	self.store:Prune(time(), config.keepUnratedDays)

	ns.RegisterEvent("GROUP_ROSTER_UPDATE", Sync)
	ns.RegisterEvent("PLAYER_ROLES_ASSIGNED", Sync)
	ns.RegisterEvent("PLAYER_ENTERING_WORLD", OnZoneChanged)
	ns.RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChanged)
	OnZoneChanged()

	if TooltipDataProcessor then
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddUnitLines)
		TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, AddItemLines)
	end

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
