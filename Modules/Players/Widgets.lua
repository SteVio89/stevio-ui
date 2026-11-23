local _, ns = ...

-- Building blocks of the player database's window and popup: star ratings,
-- role buttons and session rows, plus the texts shared with tooltips and chat
-- lines. The generic ones (buttons, inputs, lists) are the notes' widgets.

local PW = {}
ns.PlayerWidgets = PW

local Store = ns.PlayersStore
local W = ns.NotesWidgets
local T = ns.T

PW.STAR_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

local ROLE_NAMES = {
	TANK = { "Tank", "Tank" },
	HEALER = { "Healer", "Heiler" },
	DAMAGER = { "DPS", "DPS" },
}

function PW.RoleName(role)
	local names = ROLE_NAMES[role]
	return names and T(names[1], names[2]) or "–"
end

-- "★ 4.3 (3)" with the star as a texture, since the game fonts have none.
function PW.Rating(entry)
	if not entry then
		return "–"
	end
	return ("|T%s:0|t %s (%d)"):format(PW.STAR_TEXTURE, Store.FormatAverage(entry.average), entry.count)
end

-- "★ 3.8 (4) · Healer 4.3 (3) · DPS 2.0 (1)", or nil when nothing is rated.
function PW.SummaryText(player)
	local summary = Store.Summary(player)
	if not summary.overall then
		return nil
	end
	local parts = { PW.Rating(summary.overall) }
	for _, role in ipairs(Store.ROLES) do
		local entry = summary[role]
		if entry then
			parts[#parts + 1] = ("%s %s (%d)"):format(
				PW.RoleName(role),
				Store.FormatAverage(entry.average),
				entry.count
			)
		end
	end
	return table.concat(parts, " · ")
end

local CHOICE_NAMES = {
	need = { "Need", "Bedarf" },
	greed = { "Greed", "Gier" },
	transmog = { "Transmog", "Transmog" },
	pass = { "Pass", "Passen" },
}

function PW.ChoiceName(choice)
	return T(CHOICE_NAMES[choice][1], CHOICE_NAMES[choice][2])
end

-- "12 groups · 18h 20m together · 9 bosses · 2 wipes" (Store.Stats).
function PW.StatsText(stats)
	local parts = {
		T("%d groups", "%d Gruppen"):format(stats.groups),
		T("%s together", "%s zusammen"):format(Store.FormatDuration(stats.seconds)),
	}
	if stats.kills > 0 then
		parts[#parts + 1] = T("%d bosses", "%d Bosse"):format(stats.kills)
	end
	if stats.wipes > 0 then
		parts[#parts + 1] = T("%d wipes", "%d Wipes"):format(stats.wipes)
	end
	return table.concat(parts, " · ")
end

-- "Won 5 items · Need 40% · Greed 50% · Pass 10% (20 rolls)", or nil when
-- there is no loot to tell about.
function PW.LootText(stats)
	if stats.wins == 0 and stats.rollCount == 0 then
		return nil
	end
	local parts = { T("Won %d items", "%d Gegenstände gewonnen"):format(stats.wins) }
	if stats.rollCount > 0 then
		for _, choice in ipairs(Store.CHOICES) do
			local count = stats.rolls[choice]
			if count > 0 then
				parts[#parts + 1] = ("%s %d%%"):format(PW.ChoiceName(choice), Store.Percent(count, stats.rollCount))
			end
		end
		parts[#parts] = parts[#parts] .. T(" (%d rolls)", " (%d Würfe)"):format(stats.rollCount)
	end
	return table.concat(parts, " · ")
end

-- Why a player is marked: "guild <Name> (matches "pattern")", plus where
-- they were seen since when that is another guild. Nil when not marked.
function PW.BlockReason(player)
	local blocked = player.blocked
	if not blocked then
		return nil
	end
	local text = T('guild <%s> (matches "%s")', 'Gilde <%s> (passt zu "%s")'):format(
		blocked.guild or "?",
		blocked.pattern or "?"
	)
	if player.guild and player.guild ~= blocked.guild then
		text = text .. T(", since seen in <%s>", ", seitdem gesehen in <%s>"):format(player.guild)
	end
	return text
end

-- Five stars; a click sets the rating, a click on the current one clears it.
-- `onChange(stars or nil)`.
function PW.Stars(parent, size, onChange)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(Store.MAX_STARS * (size + 2), size)
	frame.buttons = {}
	frame.value = nil

	function frame:SetValue(value)
		self.value = value
		for index, button in ipairs(self.buttons) do
			local lit = value and index <= value
			button.icon:SetDesaturated(not lit)
			button.icon:SetAlpha(lit and 1 or 0.3)
		end
	end

	for index = 1, Store.MAX_STARS do
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(size, size)
		button:SetPoint("LEFT", (index - 1) * (size + 2), 0)
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button.icon:SetTexture(PW.STAR_TEXTURE)
		button:SetScript("OnClick", function()
			local value = frame.value ~= index and index or nil
			frame:SetValue(value)
			onChange(value)
		end)
		frame.buttons[index] = button
	end
	frame:SetValue(nil)
	return frame
end

-- A button showing a role; clicks cycle none, tank, healer, DPS.
-- `onChange(role or nil)`.
function PW.RoleButton(parent, width, onChange)
	local button = W.Button(parent, "", width)
	function button:SetRole(role)
		self.role = role
		self:SetText(PW.RoleName(role))
	end
	button:SetScript("OnClick", function(self)
		self:SetRole(Store.NextRole(self.role))
		onChange(self.role)
	end)
	button:SetRole(nil)
	return button
end

-- One session of a player: a label (date and place, or the name), role,
-- stars and comment. Edits go straight into the session; `onChange()` runs
-- after. Hovering the label shows the lines `Set` got as `tooltip(session)`.
function PW.SessionRow(parent, labelWidth, onChange)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(24)

	row.label = ns.CreateFontString(row)
	row.label:SetPoint("LEFT", 2, 0)
	row.label:SetWidth(labelWidth)
	row.label:SetWordWrap(false)
	local hover = CreateFrame("Frame", nil, row)
	hover:SetAllPoints(row.label)
	hover:SetScript("OnEnter", function(self)
		local lines = row.tooltip and row.tooltip(row.session)
		if not lines or #lines == 0 then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		for index, line in ipairs(lines) do
			if index == 1 then
				GameTooltip:SetText(line)
			else
				GameTooltip:AddLine(line, 1, 1, 1, true)
			end
		end
		GameTooltip:Show()
	end)
	hover:SetScript("OnLeave", GameTooltip_Hide)

	row.role = PW.RoleButton(row, 64, function(role)
		row.session.role = role
		onChange(row)
	end)
	row.role:SetPoint("LEFT", row.label, "RIGHT", 6, 0)

	row.stars = PW.Stars(row, 16, function(stars)
		Store.Rate(row.session, stars)
		onChange(row)
	end)
	row.stars:SetPoint("LEFT", row.role, "RIGHT", 8, 0)

	row.comment = W.Input(row, 100, function(text)
		Store.SetComment(row.session, text)
		onChange(row)
	end)
	row.comment:SetPoint("LEFT", row.stars, "RIGHT", 12, 0)
	row.comment:SetPoint("RIGHT", -4, 0)

	function row:Set(session, label, tooltip)
		self.session, self.tooltip = session, tooltip
		self.label:SetText(label)
		self.role:SetRole(session.role)
		self.stars:SetValue(session.stars)
		self.comment:SetText(session.comment or "")
		self.comment:SetCursorPosition(0)
	end
	return row
end
