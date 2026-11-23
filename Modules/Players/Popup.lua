local _, ns = ...

-- Rating groups: a small window listing a group's players with role, stars,
-- comment and verdict. It opens after leaving a group, and from the
-- overview's "Rate now" for every unrated group of the last week, one after
-- the other (#86). Ratings are saved as they are clicked; "Later" moves on
-- to the next group, the players stay unrated in the players window.

local Popup = {}
ns.PlayersPopup = Popup

local W = ns.NotesWidgets
local PW = ns.PlayerWidgets
local K = ns.PlayersKit
local T = ns.T

local ROW_HEIGHT = 28
local WIDTH = 820

local frame
-- The groups still to show and the one shown: { entries = { { name, class, session } } }.
local queue, position = {}, 0

local function Store()
	return ns.Players.store
end

local function CreatePopup()
	frame = CreateFrame("Frame", "StevioUI_PlayersPopup", UIParent)
	frame:SetWidth(WIDTH)
	frame:SetPoint("TOP", 0, -140)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	ns.CreatePanel(frame, { color = ns.PanelColor() })
	tinsert(UISpecialFrames, frame:GetName())

	frame.title = ns.CreateFontString(frame, 14)
	frame.title:SetPoint("TOPLEFT", 12, -10)
	frame.place = ns.CreateFontString(frame)
	frame.place:SetPoint("LEFT", frame.title, "RIGHT", 10, 0)
	frame.place:SetPoint("RIGHT", -120, 0)
	frame.place:SetTextColor(unpack(ns.config.notes.colors.dim))

	frame.close = W.Button(frame, "", 100)
	frame.close:SetPoint("TOPRIGHT", -8, -6)
	frame.close:SetScript("OnClick", function()
		Popup.Next()
	end)

	frame.rows = {}
end

local function OnRated()
	frame.close:SetText(position < #queue and T("Next", "Weiter") or T("Done", "Fertig"))
	ns.PlayersWindow.Refresh()
end

-- A session row plus the small verdict switch of its player.
local function CreateRow(index)
	local row = PW.SessionRow(frame, 150, OnRated)
	row:SetPoint("TOPLEFT", 8, -36 - (index - 1) * ROW_HEIGHT)
	row:SetPoint("RIGHT", -8, 0)
	row.verdict = K.Segmented(row, {
		{ "like", T("Play again", "Gerne wieder"), "like" },
		{ "neutral", T("Neutral", "Neutral") },
		{ "avoid", T("Avoid", "Meiden"), "avoid" },
	}, function(key)
		Store():SetVerdict(row.name, key ~= "neutral" and key or nil, time())
		OnRated()
	end, 22)
	row.verdict:SetPoint("RIGHT", -4, 0)
	row.comment:SetPoint("RIGHT", row.verdict, "LEFT", -10, 0)
	return row
end

local function ShowGroup(group)
	local entries = group.entries
	frame.close:SetText(T("Later", "Später"))
	local title = T("Rate your group", "Bewerte deine Gruppe")
	if #queue > 1 then
		title = title .. (" (%d/%d)"):format(position, #queue)
	end
	frame.title:SetText(title)
	local first = entries[1] and entries[1].session
	local place = first and PW.SessionPlace(first) or ""
	if first and first.start then
		place = ("%s · %s"):format(W.Date(first.start), place)
	end
	frame.place:SetText(place)

	for index, entry in ipairs(entries) do
		local row = frame.rows[index] or CreateRow(index)
		frame.rows[index] = row
		row.name = entry.name
		row:Set(entry.session, W.ClassColored(entry.name, entry.class))
		local player = Store():Player(entry.name)
		row.verdict:Select(player and player.verdict or "neutral")
		row:Show()
	end
	for index = #entries + 1, #frame.rows do
		frame.rows[index]:Hide()
	end
	frame:SetHeight(36 + #entries * ROW_HEIGHT + 10)
	frame:Show()
end

-- Shows the next group of the queue, or closes the popup after the last.
function Popup.Next()
	position = position + 1
	local group = queue[position]
	if group then
		ShowGroup(group)
	else
		queue, position = {}, 0
		frame:Hide()
	end
end

-- groups: { { entries = { { name, class, session } } } }, shown one after
-- the other (Store:UnratedGroups).
function Popup.ShowQueue(groups)
	if #groups == 0 then
		return
	end
	if not frame then
		CreatePopup()
	end
	queue, position = groups, 0
	Popup.Next()
end

-- entries: { name, class, session } of the players of the group just left.
function Popup.Show(entries)
	Popup.ShowQueue({ { entries = entries } })
end
