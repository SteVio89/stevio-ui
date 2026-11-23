local _, ns = ...

-- The player database (#74): everyone you group with, with group sessions
-- (role, stars, comment, place, bosses), a note, the guild, blocked-guild
-- marks and their loot rolls; see docs/players.md. This file connects the
-- store to the game: group, zone and boss tracking, the roll history's
-- results, tooltips, the notch button and /sui players.

local Players = ns.RegisterModule("players", {})
ns.Players = Players

local Store = ns.PlayersStore
local W = ns.NotesWidgets
local PW = ns.PlayerWidgets
local config = ns.config.players
local T = ns.T

local NOTE_COLOR = "|cffd9d999"
local WARN_COLOR = "|cffff5050"

-- Sessions that ended while in the current group, for the popup on leaving it.
local ended = {}

-- The name players are stored under: "Name" on your realm, else "Name-Realm",
-- as Ambiguate(..., "none") gives it for chat names too. Nil while the name
-- isn't known yet or is secret.
local function UnitKey(unit)
	local name, realm = UnitName(unit)
	if issecretvalue(name) or issecretvalue(realm) or not name or name == "" or name == UNKNOWNOBJECT then
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

-- Blocked guilds (#45) ----------------------------------------------------------

local function Warn(text, ...)
	if config.blockWarnings then
		ns.Print(WARN_COLOR .. text:format(...) .. "|r")
	end
end

-- Records the guild of `unit` when it is a player whose guild the game knows,
-- marking them when the guild is blocked. Returns the player's entry (nil
-- when not in the notes) and whether they were marked just now.
local function CheckGuild(unit)
	local isPlayer = UnitIsPlayer(unit)
	if issecretvalue(isPlayer) or not isPlayer then
		return nil, false
	end
	local name = UnitKey(unit)
	if not name or name == UnitKey("player") then
		return nil, false
	end
	local guild = GetGuildInfo(unit)
	-- Nil both for no guild and not known yet: only a name is recorded.
	if issecretvalue(guild) or not guild or guild == "" then
		return Players.store:Player(name), false
	end
	local _, class = UnitClass(unit)
	if issecretvalue(class) then
		class = nil
	end
	return Players.store:SeeGuild(name, guild, class, config.blockedGuilds, time())
end

-- A target, mouseover, nameplate or tooltip: warns when it is marked just
-- now. Returns the player's entry (nil when not in the notes).
local function CheckSeen(unit)
	if not UnitExists(unit) then
		return nil
	end
	local player, marked = CheckGuild(unit)
	if marked then
		Warn(
			T("Marked %s: %s", "Markiert %s: %s"),
			W.ClassColored(player.name, player.class) .. WARN_COLOR,
			PW.BlockReason(player)
		)
	end
	return player
end

-- The warning for a whisper from `fullName` ("Name-Realm" or "Name"), nil
-- when they aren't marked; the chat shows it under the whisper.
function ns.BlockedWhisperWarning(fullName)
	if not Players.active or not config.blockWarnings or not fullName or issecretvalue(fullName) then
		return nil
	end
	local player = Players.store:Player(Ambiguate(fullName, "none"))
	if not player or not player.blocked then
		return nil
	end
	return WARN_COLOR
		.. T("Careful, %s is marked: %s", "Vorsicht, %s ist markiert: %s"):format(player.name, PW.BlockReason(player))
		.. "|r"
end

-- Whispers when the chat module is off (it shows the warning itself).
local function OnWhisper(_, _, sender)
	if ns.ChatInternal and ns.ChatInternal.store then
		return
	end
	local warning = not issecretvalue(sender) and ns.BlockedWhisperWarning(sender)
	if warning then
		ns.Print(warning)
	end
end

local function WarnInGroup(player)
	if player.blocked then
		Warn(
			T("In your group: %s, marked: %s", "In deiner Gruppe: %s, markiert: %s"),
			W.ClassColored(player.name, player.class) .. WARN_COLOR,
			PW.BlockReason(player)
		)
	end
end

local function Remind(player)
	WarnInGroup(player)
	if not config.joinReminder or not (player.note or Store.HasRating(player)) then
		return
	end
	local parts = { W.ClassColored(player.name, player.class) }
	parts[#parts + 1] = PW.SummaryText(player) or T("not rated", "nicht bewertet")
	if player.note then
		parts[#parts + 1] = NOTE_COLOR .. Store.Title(player.note) .. "|r"
	end
	ns.Print(T("In your group: %s", "In deiner Gruppe: %s"):format(table.concat(parts, " · ")))
end

local function EndSession(name, now)
	local session = Players.store:Close(name, now)
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
		local player = Players.store:Player(entry.name)
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
			T(
				"%d players from your group to rate: /sui players",
				"%d Spieler aus deiner Gruppe zu bewerten: /sui players"
			):format(#entries)
		)
	else
		ns.PlayersPopup.Show(entries)
	end
end

-- Brings the sessions in line with the group: opens one for each member,
-- closes those of players no longer in it.
local function Sync()
	local store, now = Players.store, time()
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
				local _, marked = CheckGuild(unit)
				local _, class = UnitClass(unit)
				local _, isNew = store:Open(name, {
					class = class,
					role = UnitGroupRolesAssigned(unit),
					place = place,
					isInstance = isInstance,
				}, now)
				if isNew then
					Remind(store:Player(name))
				elseif marked then
					-- Already grouped, the guild only became known now.
					WarnInGroup(store:Player(name))
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
	Players.store:Visit(place, isInstance, time())
	Sync()
end

-- Tooltips ---------------------------------------------------------------------

local function AddUnitLines(tooltip)
	if not config.showInTooltip or not tooltip.GetUnit then
		return
	end
	local _, unit = tooltip:GetUnit()
	if issecretvalue(unit) or not unit then
		return
	end
	local isPlayer = UnitIsPlayer(unit)
	if issecretvalue(isPlayer) or not isPlayer then
		return
	end
	local player = CheckSeen(unit)
	if not player then
		return
	end
	if player.blocked then
		tooltip:AddLine(WARN_COLOR .. T("Marked: ", "Markiert: ") .. PW.BlockReason(player) .. "|r", 1, 1, 1, true)
	end
	local summary = PW.SummaryText(player)
	if summary then
		tooltip:AddLine(summary, 1, 1, 1)
	end
	if config.lootInTooltip then
		local loot = PW.LootText(Store.Stats(player, time()))
		if loot then
			tooltip:AddLine(loot, 0.8, 0.8, 0.8)
		end
	end
	if player.note then
		tooltip:AddLine(NOTE_COLOR .. player.note .. "|r", 1, 1, 1, true)
	end
end

-- Bosses and loot (#74) --------------------------------------------------------

-- A boss fight ended: kills and wipes go into the open sessions. The boss
-- name may be secret right then; the kill still counts.
local function OnEncounterEnd(_, _, encounterName, _, _, success)
	if issecretvalue(success) then
		return
	end
	local boss = not issecretvalue(encounterName) and encounterName ~= "" and encounterName or nil
	Players.store:Encounter(boss, success == 1)
end

local CHOICE_OF_STATE
local function Choice(state)
	if not CHOICE_OF_STATE then
		local State = ns.RollLogic.State
		CHOICE_OF_STATE = {
			[State.NeedMainSpec] = "need",
			[State.NeedOffSpec] = "need",
			[State.Greed] = "greed",
			[State.Transmog] = "transmog",
			[State.Pass] = "pass",
		}
	end
	return CHOICE_OF_STATE[state]
end

local function RollKey(roll)
	local name = roll.fullName or roll.name
	return name and name ~= "" and Ambiguate(name, "none") or nil
end

-- A decided group loot roll from the roll history (Modules/Rolls), passed
-- once per drop: every other player's choice and the winner's item.
function ns.PlayersRecordLoot(record)
	if not Players.active then
		return
	end
	local store, now = Players.store, time()
	for _, roll in ipairs(record.rolls or {}) do
		local name, choice = RollKey(roll), Choice(roll.state)
		if name and choice and not roll.isSelf then
			store:AddRoll(name, roll.class, choice, now)
		end
	end
	local winner = record.winner
	local name = winner and not winner.isSelf and RollKey(winner)
	if name and record.link then
		store:AddWin(name, winner.class, {
			link = record.link,
			encounter = record.encounter ~= "" and record.encounter or nil,
			instance = record.instance,
			time = record.time or now,
		}, now)
	end
	ns.PlayersWindow.Refresh()
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
	local button = CreateFrame("Button", "StevioUI_PlayersButton", parking)
	button:SetSize(size, size)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_HaveGroup")
	ns.CropIcon(icon)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetScript("OnClick", ns.PlayersWindow.Toggle)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(T("Players", "Spieler"))
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	ns.NotchButtons.AddOwn(button)
end

-- API for other modules --------------------------------------------------------

-- Opens the player database on a player ("Name-Realm" or "Name"), e.g. from
-- the chat's name menu; false while the module is off.
function ns.OpenPlayerNote(fullName)
	if not Players.active then
		return false
	end
	local name = Ambiguate(fullName, "none")
	Players.store:Ensure(name, nil, time())
	ns.PlayersWindow.Open(name)
	return true
end

-- Players used to live in the notes (StevioUINotes.players, before #74):
-- they move over once, with the logout time their open sessions need.
local function TakeOverNotes()
	local notes = StevioUINotes
	if type(notes) ~= "table" or type(notes.players) ~= "table" then
		return
	end
	-- The logout time only belongs to the sessions moved into a new table.
	if StevioUIPlayers == nil then
		StevioUIPlayers = { loggedOut = notes.loggedOut }
	end
	StevioUIPlayers.players = StevioUIPlayers.players or {}
	for name, player in pairs(notes.players) do
		if StevioUIPlayers.players[name] == nil then
			StevioUIPlayers.players[name] = player
		end
	end
	notes.players, notes.loggedOut = nil, nil
end

function Players:OnEnable()
	TakeOverNotes()
	self.store = Store.New(StevioUIPlayers, { rejoinGrace = config.rejoinGrace })
	StevioUIPlayers = self.store.db
	-- Sessions still open at the last logout ended then, not now: the time
	-- offline isn't spent in their place. After a /reload in the same group
	-- they continue (rejoinGrace). Without a recorded logout (a crash) they
	-- end at the next roster check, as before.
	local loggedOut = self.store.db.loggedOut
	self.store.db.loggedOut = nil
	if loggedOut then
		for _, name in ipairs(self.store:OpenNames()) do
			EndSession(name, loggedOut)
		end
	end
	ns.RegisterEvent("PLAYER_LOGOUT", function()
		Players.store.db.loggedOut = time()
	end)
	self.store:Prune(time(), config.keepUnratedDays)

	ns.RegisterEvent("GROUP_ROSTER_UPDATE", Sync)
	ns.RegisterEvent("PLAYER_ROLES_ASSIGNED", Sync)
	ns.RegisterEvent("PLAYER_ENTERING_WORLD", OnZoneChanged)
	ns.RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChanged)
	ns.RegisterEvent("ENCOUNTER_END", OnEncounterEnd)
	ns.RegisterEvent("PLAYER_TARGET_CHANGED", function()
		CheckSeen("target")
	end)
	ns.RegisterEvent("UPDATE_MOUSEOVER_UNIT", function()
		CheckSeen("mouseover")
	end)
	ns.RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
		CheckSeen(unit)
	end)
	ns.RegisterEvent("CHAT_MSG_WHISPER", OnWhisper)
	OnZoneChanged()

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, AddUnitLines)

	CreateNotchButton()
end

-- /sui players toggles the window; /sui players <name> opens that player.
ns.RegisterModuleCommand("players", "players", function(input)
	local name = input:match("^%s*(%S+)")
	if name then
		ns.OpenPlayerNote(name)
	else
		ns.PlayersWindow.Toggle()
	end
end)
