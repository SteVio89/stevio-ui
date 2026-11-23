local _, ns = ...

-- A player's page in the players window (#86): who they are, your verdict
-- and rating, a marked guild, tags, numbers, ratings by role, rolls, the
-- note, every group together (role, bosses, loot, stars, comment) and who
-- else was often in the same groups. Edits are saved at once.

local Page = {}
ns.PlayersPage = Page

local Store = ns.PlayersStore
local PW = ns.PlayerWidgets
local K = ns.PlayersKit
local T = ns.T

local GAP = 12
local MAX_SUGGESTIONS = 4
local MAX_PARTNERS = 8
local CHECK_ICON = "Interface\\RAIDFRAME\\ReadyCheck-Ready"
local CROSS_ICON = "Interface\\RAIDFRAME\\ReadyCheck-NotReady"
local FORGET_DIALOG = "STEVIOUI_FORGET_PLAYER"
local COPY_DIALOG = "STEVIOUI_COPY_PLAYER_NAME"

local HISTORY_FILTERS = {
	{ "all", "All", "Alle" },
	{ "loot", "With loot", "Mit Beute" },
	{ "unrated", "Unrated", "Unbewertet" },
}

local function Window()
	return ns.PlayersWindow
end

local function Store_()
	return Window().Store()
end

-- Something on the page changed what the list shows (rating, note, ...).
local function Changed(full)
	Window().RefreshList()
	if full then
		Window().RenderContent()
	end
end

StaticPopupDialogs[FORGET_DIALOG] = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, name)
		Store_():Forget(name)
		Window().Select(nil)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

StaticPopupDialogs[COPY_DIALOG] = {
	text = "%s",
	button1 = OKAY,
	hasEditBox = 1,
	OnShow = function(dialog, name)
		local edit = dialog:GetEditBox()
		edit:SetText(name)
		edit:HighlightText()
		edit:SetFocus()
	end,
	EditBoxOnEnterPressed = function(edit)
		edit:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(edit)
		edit:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Places `frames` left to right from (x, y) in `parent`, wrapping at
-- `width`; returns the height used.
local function Flow(parent, frames, x, y, width, gap, lineHeight)
	local startX, lineX, lineY = x, x, y
	for _, frame in ipairs(frames) do
		if lineX > startX and lineX + frame:GetWidth() > width then
			lineX, lineY = startX, lineY + lineHeight
		end
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", parent, "TOPLEFT", lineX, -lineY)
		lineX = lineX + frame:GetWidth() + gap
	end
	return lineY - y + lineHeight
end

-- A small chip with an icon (✓ boss, ✕ wipes) or a plain text.
local function IconChip(parent)
	local chip = K.Box(parent)
	chip:SetHeight(20)
	chip.icon = chip:CreateTexture(nil, "ARTWORK")
	chip.icon:SetSize(12, 12)
	chip.icon:SetPoint("LEFT", 6, 0)
	chip.text = K.Text(chip, 11, "text")
	function chip:Set(text, colorName, icon)
		local color = K.Color(colorName or "text")
		self:SetColors(
			{ color[1], color[2], color[3], colorName and 0.12 or 0.04 },
			{ color[1], color[2], color[3], colorName and 0.35 or 0.12 }
		)
		self.text:SetText(text)
		self.text:SetTextColor(color[1], color[2], color[3])
		self.text:ClearAllPoints()
		self.icon:SetShown(icon ~= nil)
		if icon then
			self.icon:SetTexture(icon)
			self.text:SetPoint("LEFT", self.icon, "RIGHT", 4, 0)
			self:SetWidth(self.text:GetStringWidth() + 32)
		else
			self.text:SetPoint("LEFT", 8, 0)
			self:SetWidth(self.text:GetStringWidth() + 16)
		end
	end
	return chip
end

-- Header ------------------------------------------------------------------------------

local function PlayerLines(player)
	local class = player.class and LOCALIZED_CLASS_NAMES_MALE[player.class]
	local guild = player.guild and ("‹%s›"):format(player.guild) or T("guild unknown", "Gilde unbekannt")
	local first = class and (class .. " · " .. guild) or guild
	local second = T("First seen %s · last %s", "Zuerst gesehen %s · zuletzt %s"):format(
		ns.NotesWidgets.Date(player.firstSeen),
		ns.NotesWidgets.Date(player.lastSeen)
	)
	return first, second
end

local function Whisper(name)
	local send = ChatFrameUtil and ChatFrameUtil.SendTell or ChatFrame_SendTell
	send(name)
end

local function CreateHeader(page)
	local header = CreateFrame("Frame", nil, page)
	header.avatar = K.Avatar(header, 64)
	header.avatar:SetPoint("TOPLEFT")
	header.name = K.Text(header, 22, "textStrong")
	header.name:SetPoint("TOPLEFT", header.avatar, "TOPRIGHT", 20, -2)
	header.line1 = K.Text(header, 12, "text")
	header.line1:SetPoint("TOPLEFT", header.name, "BOTTOMLEFT", 0, -8)
	header.line2 = K.Text(header, 11, "textMuted")
	header.line2:SetPoint("TOPLEFT", header.line1, "BOTTOMLEFT", 0, -6)

	header.whisper = K.Button(header, T("Whisper", "Flüstern"), 26)
	header.whisper:SetPoint("TOPLEFT", header.line2, "BOTTOMLEFT", 0, -12)
	header.whisper:SetScript("OnClick", function()
		Whisper(page.player.name)
	end)
	header.invite = K.Button(header, T("Invite", "Einladen"), 26)
	header.invite:SetPoint("LEFT", header.whisper, "RIGHT", 8, 0)
	header.invite:SetScript("OnClick", function()
		C_PartyInfo.InviteUnit(page.player.name)
	end)
	header.more = K.Button(header, "...", 26)
	header.more:SetPoint("LEFT", header.invite, "RIGHT", 8, 0)
	header.more:SetScript("OnClick", function(self)
		local name = page.player.name
		K.Menu(self, {
			{
				T("Copy name", "Namen kopieren"),
				function()
					StaticPopup_Show(COPY_DIALOG, T("Ctrl+C copies the name.", "Strg+C kopiert den Namen."), nil, name)
				end,
			},
			{
				T("Forget", "Vergessen"),
				function()
					StaticPopup_Show(
						FORGET_DIALOG,
						T(
							"Forget %s with all groups, ratings and notes?",
							"%s mit allen Gruppen, Bewertungen und Notizen vergessen?"
						):format(name),
						nil,
						name
					)
				end,
			},
		})
	end)

	header.stars = K.Stars(header, 13, nil, 3)
	header.stars:SetPoint("TOPRIGHT", 0, -6)
	header.count = K.Text(header, 11, "textMuted", "RIGHT")
	header.count:SetPoint("TOPRIGHT", header.stars, "BOTTOMRIGHT", 0, -6)
	header.average = K.Text(header, 34, "textStrong", "RIGHT")
	header.average:SetPoint("TOPRIGHT", header.stars, "TOPLEFT", -10, 2)
	header.verdict = K.Segmented(header, {
		{ "like", T("Play again", "Gerne wieder"), "like" },
		{ "neutral", T("Neutral", "Neutral") },
		{ "avoid", T("Avoid", "Meiden"), "avoid" },
	}, function(key)
		Store_():SetVerdict(page.player.name, key ~= "neutral" and key or nil, Window().Now())
		Changed()
	end, 32)
	header.verdict:SetPoint("TOPRIGHT", 0, -48)

	function header:Update(player)
		self.avatar:Set(player.name, player.class)
		self.name:SetText(K.ColoredName(player.name, player.class))
		local first, second = PlayerLines(player)
		self.line1:SetText(first)
		self.line2:SetText(second)
		local overall = Store.Summary(player).overall
		if overall then
			local low = overall.average <= Store.ATTENTION_STARS
			self.average:SetText(Store.FormatAverage(overall.average))
			self.average:SetTextColor(K.RGB(low and "avoid" or "textStrong"))
			self.stars:SetValue(overall.average)
			self.count:SetText(T("from %d ratings", "aus %d Bewertungen"):format(overall.count))
		else
			self.average:SetText("–")
			self.average:SetTextColor(K.RGB("textFaint"))
			self.stars:SetValue(nil)
			self.count:SetText(T("not rated yet", "noch nicht bewertet"))
		end
		self.verdict:Select(player.verdict or "neutral")
	end
	return header
end

-- The red bar of a marked player.
local function CreateMarkedBar(page)
	local red = K.Color("avoid")
	local bar = K.Box(page, { red[1], red[2], red[3], 0.10 }, { red[1], red[2], red[3], 0.45 })
	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetSize(16, 16)
	icon:SetPoint("LEFT", 16, 0)
	icon:SetTexture(K.ICON_WARNING)
	bar.text = K.Text(bar, 12, "text")
	bar.text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
	bar.button = K.Button(bar, T("Remove mark", "Markierung entfernen"), 26)
	bar.button:SetPoint("RIGHT", -12, 0)
	bar.text:SetPoint("RIGHT", bar.button, "LEFT", -10, 0)
	bar.button:SetScript("OnClick", function()
		Store_():Unblock(page.player.name)
		Changed(true)
	end)
	function bar:Update(player)
		local blocked = player.blocked
		local text = K.Hex("avoid")
			.. T("Marked", "Markiert")
			.. "|r – "
			.. T(
				"guild ‹%s› matches the pattern “%s”. Marked on %s.",
				"Gilde ‹%s› passt auf das Muster „%s“. Markiert am %s."
			):format(blocked.guild or "?", blocked.pattern or "?", ns.NotesWidgets.Date(blocked.time))
		if player.guild and player.guild ~= blocked.guild then
			text = text .. T(" Since seen in ‹%s›.", " Seitdem gesehen in ‹%s›."):format(player.guild)
		end
		self.text:SetText(text)
	end
	return bar
end

-- Tags: chips with ✕, suggestions with +, and an input for an own tag.
local function CreateTags(page, width)
	local tags = CreateFrame("Frame", nil, page)
	tags.label = K.Text(tags, 10, "textMuted")
	tags.label:SetPoint("TOPLEFT", 0, -7)
	tags.label:SetText(T("TAGS", "TAGS"))
	tags.chips = K.Pool(function()
		local chip = K.Box(tags)
		chip:SetHeight(22)
		chip.text = K.Text(chip, 11, "text")
		chip.text:SetPoint("LEFT", 8, 0)
		chip.remove = ns.CreateCloseButton(chip, 14, function(self)
			Store_():RemoveTag(page.player.name, self:GetParent().tag)
			Changed(true)
		end)
		chip.remove:SetPoint("LEFT", chip.text, "RIGHT", 2, 0)
		return chip
	end)
	tags.suggestions = K.Pool(function()
		local chip = K.Chip(tags, 22)
		chip:SetScript("OnClick", function(self)
			Store_():AddTag(page.player.name, self.tag, Window().Now())
			Changed(true)
		end)
		return chip
	end)
	tags.add = K.Chip(tags, 22)
	tags.add:SetChip("+ " .. T("Own tag", "Eigener Tag"))
	tags.input = K.Input(tags, T("Tag, Enter adds", "Tag, Enter fügt hinzu"), nil, 22)
	tags.input:SetWidth(180)
	tags.input:Hide()
	tags.input.edit:SetMaxLetters(Store.MAX_TAG_LENGTH)
	tags.add:SetScript("OnClick", function()
		tags.add:Hide()
		tags.input:SetText("")
		tags.input:Show()
		tags.input.edit:SetFocus()
		page:Relayout()
	end)
	local function CloseInput()
		tags.input:Hide()
		tags.add:Show()
		page:Relayout()
	end
	tags.input.edit:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		self:ClearFocus()
		tags.input:Hide()
		tags.add:Show()
		if Store_():AddTag(page.player.name, text, Window().Now()) then
			Changed(true)
		else
			page:Relayout()
		end
	end)
	tags.input.edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		CloseInput()
	end)
	tags.input.edit:SetScript("OnEditFocusLost", function()
		if tags.input:IsShown() and tags.input.edit:GetText() == "" then
			CloseInput()
		end
	end)

	function tags:Update(player)
		local frames = {}
		-- Red for players to avoid, else the accent.
		local colorName = (player.verdict == "avoid" or player.blocked) and "avoid" or "accent"
		local color = K.Color(colorName)
		for index, tag in ipairs(player.tags or {}) do
			local chip = self.chips:Get(index)
			chip.tag = tag
			chip:SetColors({ color[1], color[2], color[3], 0.14 }, { color[1], color[2], color[3], 0.4 })
			chip.text:SetTextColor(K.RGB(colorName == "avoid" and "avoid" or "pillText"))
			chip.text:SetText(tag)
			chip:SetWidth(chip.text:GetStringWidth() + 30)
			frames[#frames + 1] = chip
		end
		self.chips:HideFrom(#(player.tags or {}) + 1)
		local suggestions = Store_():TagSuggestions(player, MAX_SUGGESTIONS)
		for index, tag in ipairs(suggestions) do
			local chip = self.suggestions:Get(index)
			chip.tag = tag
			chip:SetChip("+ " .. tag)
			chip.label:SetTextColor(K.RGB("textMuted"))
			frames[#frames + 1] = chip
		end
		self.suggestions:HideFrom(#suggestions + 1)
		frames[#frames + 1] = self.input:IsShown() and self.input or self.add
		return Flow(self, frames, 56, 0, width, 8, 30)
	end
	return tags
end

local function CreateTiles(page, width)
	local row = CreateFrame("Frame", nil, page)
	row.tiles = {}
	local tileWidth = (width - 4 * GAP) / 5
	for index = 1, 5 do
		local tile = K.Tile(row)
		tile:SetPoint("TOPLEFT", (index - 1) * (tileWidth + GAP), 0)
		tile:SetWidth(tileWidth)
		row.tiles[index] = tile
	end
	function row:Update(player)
		local stats = Store.Stats(player, Window().Now())
		local tiles = self.tiles
		tiles[1]:Set(T("Groups", "Gruppen"), stats.groups)
		tiles[2]:Set(T("Time together", "Zeit zusammen"), Store.FormatDuration(stats.seconds))
		tiles[3]:Set(T("Bosses", "Bosse"), stats.kills)
		tiles[4]:Set(T("Wipes", "Wipes"), stats.wipes)
		tiles[5]:Set(
			T("Items", "Items"),
			stats.wins,
			stats.winsNeed > 0 and T("%d of them with Need", "davon %d mit Bedarf"):format(stats.winsNeed) or nil
		)
	end
	return row
end

-- "Rating by role": a bar of the average out of 5 per role.
local function CreateRolesCard(page)
	local card = K.Card(page, T("Rating by role", "Bewertung nach Rolle"))
	card.rows = {}
	for index, role in ipairs(Store.ROLES) do
		local row = CreateFrame("Frame", nil, card)
		row:SetHeight(18)
		row:SetPoint("TOPLEFT", 16, -42 - (index - 1) * 28)
		row:SetPoint("RIGHT", -16, 0)
		row.name = K.Text(row, 12, "text")
		row.name:SetPoint("LEFT")
		row.name:SetText(PW.RoleName(role))
		row.value = K.Text(row, 12, "textStrong", "RIGHT")
		row.value:SetPoint("RIGHT")
		row.value:SetWidth(60)
		row.bar = K.Bar(row, 6)
		row.bar:SetPoint("LEFT", 80, 0)
		row.bar:SetPoint("RIGHT", row.value, "LEFT", -20, 0)
		row.role = role
		card.rows[index] = row
	end
	card.note = K.Text(card, 10, "textMuted")
	card.note:SetPoint("TOPLEFT", 16, -42 - 3 * 28 - 4)
	card.note:SetText(
		T("Only rated groups count. In brackets: how many.", "Nur bewertete Gruppen zählen. In Klammern: Anzahl.")
	)
	function card:Update(player)
		local summary = Store.Summary(player)
		for _, row in ipairs(self.rows) do
			local entry = summary[row.role]
			if entry then
				local low = entry.average <= Store.ATTENTION_STARS
				row.bar:SetFraction(entry.average / Store.MAX_STARS, K.RGB(low and "avoid" or "star"))
				row.value:SetText(("%s (%d)"):format(Store.FormatAverage(entry.average), entry.count))
				row.value:SetTextColor(K.RGB("textStrong"))
			else
				row.bar:SetFraction(0)
				row.value:SetText("–")
				row.value:SetTextColor(K.RGB("textFaint"))
			end
		end
		return 42 + 3 * 28 + 30
	end
	return card
end

-- "Roll behaviour": the shares as a bar and legend with counts, a warning
-- for Need outliers, or an empty state.
local function CreateRollsCard(page)
	local card = K.Card(page, T("Roll behaviour", "Würfelverhalten"))
	card.bar = K.StackedBar(card, 10)
	card.bar:SetPoint("TOPLEFT", 16, -42)
	card.bar:SetPoint("RIGHT", -16, 0)
	card.legend = {}
	for index, choice in ipairs(Store.CHOICES) do
		local entry = CreateFrame("Frame", nil, card)
		entry:SetHeight(16)
		entry.swatch = K.Texture(entry, "ARTWORK")
		entry.swatch:SetSize(9, 9)
		entry.swatch:SetPoint("LEFT")
		entry.swatch:SetVertexColor(K.RGB(choice))
		entry.name = K.Text(entry, 11, "text")
		entry.name:SetPoint("LEFT", entry.swatch, "RIGHT", 6, 0)
		entry.name:SetText(PW.ChoiceName(choice))
		entry.count = K.Text(entry, 11, "textMuted", "RIGHT")
		entry.count:SetPoint("RIGHT")
		entry.count:SetWidth(24)
		entry.share = K.Text(entry, 11, "textStrong", "RIGHT")
		entry.share:SetPoint("RIGHT", entry.count, "LEFT", -6, 0)
		entry.choice = choice
		local column, line = (index - 1) % 2, math.floor((index - 1) / 2)
		entry:SetPoint("TOPLEFT", card.bar, "BOTTOMLEFT", 0, -14 - line * 22)
		entry.column = column
		card.legend[index] = entry
	end
	local low = K.Color("low")
	card.warning = K.Box(card, { low[1], low[2], low[3], 0.10 }, nil)
	card.warning:SetPoint("TOPLEFT", card.bar, "BOTTOMLEFT", 0, -64)
	card.warning:SetPoint("RIGHT", -16, 0)
	card.warning:SetHeight(44)
	local icon = card.warning:CreateTexture(nil, "ARTWORK")
	icon:SetSize(14, 14)
	icon:SetPoint("TOPLEFT", 10, -9)
	icon:SetTexture(K.ICON_WARNING)
	card.warning.text = K.Text(card.warning, 11, "low")
	card.warning.text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
	card.warning.text:SetPoint("RIGHT", -10, 0)
	card.warning.text:SetWordWrap(true)

	card.empty = CreateFrame("Frame", nil, card)
	card.empty:SetPoint("TOPLEFT", 16, -40)
	card.empty:SetPoint("BOTTOMRIGHT", -16, 16)
	local dice = card.empty:CreateTexture(nil, "ARTWORK")
	dice:SetSize(24, 24)
	dice:SetPoint("TOP", 0, -10)
	dice:SetTexture(K.ICON_DICE)
	dice:SetDesaturated(true)
	dice:SetAlpha(0.7)
	local title = K.Text(card.empty, 12, "textStrong", "CENTER")
	title:SetPoint("TOP", dice, "BOTTOM", 0, -10)
	title:SetText(T("No rolls recorded yet", "Noch keine Würfe erfasst"))
	local sub = K.Text(card.empty, 10, "textMuted", "CENTER")
	sub:SetPoint("TOP", title, "BOTTOM", 0, -8)
	sub:SetPoint("LEFT")
	sub:SetPoint("RIGHT")
	sub:SetWordWrap(true)
	sub:SetText(
		T(
			"Once you roll for loot together, Need, Greed and Pass show up here.",
			"Sobald ihr gemeinsam um Beute würfelt, siehst du hier Bedarf, Gier und Passen."
		)
	)

	function card:Update(player, width)
		local shares = Store.RollShares(player.rolls)
		local hasRolls = shares.total > 0
		self.empty:SetShown(not hasRolls)
		self.bar:SetShown(hasRolls)
		self.aside:SetText(hasRolls and T("%d rolls", "%d Würfe"):format(shares.total) or "")
		local columnWidth = (width - 32 - 24) / 2
		local parts = {}
		for index, entry in ipairs(self.legend) do
			local share = shares[entry.choice]
			parts[index] = { share.count, entry.choice }
			entry:SetShown(hasRolls)
			entry:SetWidth(columnWidth)
			entry:ClearAllPoints()
			entry:SetPoint(
				"TOPLEFT",
				self.bar,
				"BOTTOMLEFT",
				entry.column * (columnWidth + 24),
				-14 - math.floor((index - 1) / 2) * 22
			)
			entry.share:SetText(("%d %%"):format(Store.Percent(share.count, shares.total)))
			entry.count:SetText(share.count)
		end
		self.bar:SetParts(parts)
		local averages = Store_():RollAverages()
		local outlier = hasRolls and Store.NeedOutlier(player, averages)
		self.warning:SetShown(outlier)
		if outlier then
			self.warning.text:SetText(
				T(
					"Need on %d %% of the rolls. Your fellow players average %d %%.",
					"Bedarf bei %d %% der Würfe. Im Schnitt deiner Mitspieler sind es %d %%."
				):format(
					Store.Percent(shares.need.count, shares.total),
					Store.Percent(averages.need.count, averages.total)
				)
			)
			return 42 + 64 + 44 + 16
		end
		return hasRolls and 42 + 10 + 14 + 44 + 16 or 150
	end
	return card
end

-- The note: edited in place, with the date of the last change.
local function CreateNote(page)
	local card = K.Card(page, T("Note", "Notiz"))
	local edit = CreateFrame("EditBox", nil, card)
	edit:SetPoint("TOPLEFT", 16, -40)
	edit:SetPoint("RIGHT", -16, 0)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetTextColor(K.RGB("textStrong"))
	edit.placeholder = K.Text(card, 12, "textFaint")
	edit.placeholder:SetPoint("TOPLEFT", edit, "TOPLEFT", 0, 0)
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnTextChanged", function(self, userInput)
		self.placeholder:SetShown(self:GetText() == "" and not self:HasFocus())
		if userInput then
			local player = Store_():SetPlayerNote(page.player.name, self:GetText(), Window().Now())
			card:UpdateEdited(player)
			Changed()
		end
	end)
	edit:SetScript("OnEditFocusGained", function(self)
		self.placeholder:Hide()
	end)
	edit:SetScript("OnEditFocusLost", function(self)
		self.placeholder:SetShown(self:GetText() == "")
	end)
	-- More lines push the history down.
	edit:SetScript("OnSizeChanged", function(_, _, height)
		if card.lastHeight and math.abs(card.lastHeight - height) > 1 then
			page:Relayout()
		end
		card.lastHeight = height
	end)
	card:EnableMouse(true)
	card:SetScript("OnMouseDown", function()
		edit:SetFocus()
	end)
	card.edit = edit

	function card:UpdateEdited(player)
		self.aside:SetText(
			player.noteTime and T("edited %s", "bearbeitet %s"):format(ns.NotesWidgets.Date(player.noteTime)) or ""
		)
	end
	function card:Update(player, changedPlayer)
		if changedPlayer or not edit:HasFocus() then
			edit:SetText(player.note or "")
			edit:SetCursorPosition(0)
		end
		edit.placeholder:SetText(
			T("A general note about %s – click to write …", "Allgemeine Notiz zu %s – klicken zum Schreiben …"):format(
				player.name:match("^[^-]+")
			)
		)
		edit.placeholder:SetShown(edit:GetText() == "" and not edit:HasFocus())
		self:UpdateEdited(player)
		return 40 + math.max(20, edit:GetHeight()) + 24
	end
	return card
end

-- History -------------------------------------------------------------------------------

local function SessionTitle(session)
	if session.open then
		return T("Grouped now", "Gerade in der Gruppe"), nil
	end
	local instances = session.instances or {}
	if session.instance and #instances > 0 then
		local rest = {}
		for index = 2, #instances do
			rest[#rest + 1] = instances[index]
		end
		return instances[1], #rest > 0 and table.concat(rest, ", ") or nil
	elseif session.where then
		return session.where, T("open world", "offene Welt")
	end
	return "?", nil
end

local function SessionSeconds(session, now)
	local stop = session.stop or (session.open and now) or session.start
	return math.max(0, (stop or 0) - (session.start or 0))
end

-- One group together: date, place, duration, role, bosses, loot, comment
-- and stars.
local function CreateSessionCard(page)
	local card = K.Box(page, K.CardColors())
	card.date = K.Text(card, 15, "textStrong")
	card.date:SetPoint("TOPLEFT", 20, -18)
	card.day = K.Text(card, 10, "textMuted")
	card.day:SetPoint("TOPLEFT", card.date, "BOTTOMLEFT", 0, -6)

	card.stars = K.Stars(card, 15, function(stars)
		Store.Rate(card.session, stars)
		Changed(true)
	end, 6)
	card.stars:SetPoint("TOPRIGHT", -20, -16)
	card.rated = K.Text(card, 10, "textMuted", "RIGHT")
	card.rated:SetPoint("TOPRIGHT", card.stars, "BOTTOMRIGHT", 0, -8)

	card.title = K.Text(card, 13, "textStrong")
	card.title:SetPoint("TOPLEFT", 112, -18)
	card.title:SetPoint("RIGHT", card.stars, "LEFT", -12, 0)

	card.chipArea = CreateFrame("Frame", nil, card)
	card.chipArea:SetPoint("TOPLEFT", 112, -42)
	card.chipArea:SetPoint("RIGHT", card.stars, "LEFT", -12, 0)
	card.chipArea:SetHeight(20)
	card.duration = K.Text(card.chipArea, 11, "text")
	card.role = K.Chip(card.chipArea, 20)
	card.role:SetScript("OnClick", function()
		card.session.role = Store.NextRole(card.session.role)
		Changed(true)
	end)
	card.role.tooltip = T("Click to change the role", "Klicken wechselt die Rolle")
	card.bosses = K.Pool(function()
		return IconChip(card.chipArea)
	end)

	card.winsLabel = K.Text(card, 11, "textMuted")
	card.winsLabel:SetText(T("Won", "Gewonnen"))
	card.wins = K.Pool(function()
		local chip = K.Box(card, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.14 }, "Button")
		chip:SetHeight(22)
		chip.text = K.Text(chip, 11, "text")
		chip.text:SetPoint("LEFT", 8, 0)
		chip:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.win.link)
			GameTooltip:Show()
		end)
		chip:SetScript("OnLeave", GameTooltip_Hide)
		-- Shift-click links the item, like everywhere else.
		chip:SetScript("OnClick", function(self)
			HandleModifiedItemClick(self.win.link)
		end)
		return chip
	end)

	card.stroke = K.Texture(card, "ARTWORK", 1, 1, 1, 0.2)
	card.stroke:SetWidth(2)
	card.comment = CreateFrame("EditBox", nil, card)
	card.comment:SetHeight(20)
	card.comment:SetAutoFocus(false)
	card.comment:SetFontObject(ChatFontNormal)
	card.comment:SetTextColor(K.RGB("textStrong"))
	card.comment.placeholder = K.Text(card, 12, "textFaint")
	card.comment.placeholder:SetPoint("LEFT", card.comment, "LEFT")
	card.comment.placeholder:SetText(T("Add a comment …", "Kommentar hinzufügen …"))
	card.comment:SetScript("OnEscapePressed", card.comment.ClearFocus)
	card.comment:SetScript("OnEnterPressed", card.comment.ClearFocus)
	card.comment:SetScript("OnTextChanged", function(self, userInput)
		local empty = self:GetText() == ""
		self.placeholder:SetShown(empty and not self:HasFocus())
		card.stroke:SetShown(not empty)
		if userInput then
			Store.SetComment(card.session, self:GetText())
		end
	end)
	card.comment:SetScript("OnEditFocusGained", function(self)
		self.placeholder:Hide()
	end)
	card.comment:SetScript("OnEditFocusLost", function(self)
		self.placeholder:SetShown(self:GetText() == "")
	end)

	-- Fills the card; returns its height.
	function card:Set(player, session)
		self.session = session
		local now = Window().Now()
		self.date:SetText(date("%d.%m.", session.start))
		self.day:SetText(("%s · %s"):format(PW.Weekday(session.start), date("%Y", session.start)))
		local title, sub = SessionTitle(session)
		self.title:SetText(title .. (sub and (K.Hex("textMuted") .. " · " .. sub .. "|r") or ""))
		self.stars:SetValue(session.stars)
		if session.stars then
			self.rated:SetText(T("rated", "bewertet"))
			self.rated:SetTextColor(K.RGB("textMuted"))
		else
			self.rated:SetText(T("not rated yet", "noch nicht bewertet"))
			self.rated:SetTextColor(K.RGB("accent"))
		end

		local chips = {}
		self.duration:SetText(Store.FormatDuration(SessionSeconds(session, now)))
		self.duration:SetWidth(self.duration:GetStringWidth() + 2)
		self.duration:SetHeight(20)
		chips[#chips + 1] = self.duration
		self.role:SetChip(session.role and PW.RoleName(session.role) or T("Role?", "Rolle?"))
		chips[#chips + 1] = self.role
		local count = 0
		for _, boss in ipairs(session.kills or {}) do
			count = count + 1
			local chip = self.bosses:Get(count)
			chip:Set(boss, "like", CHECK_ICON)
			chips[#chips + 1] = chip
		end
		if (session.wipes or 0) > 0 then
			count = count + 1
			local chip = self.bosses:Get(count)
			chip:Set(
				session.wipes == 1 and T("1 wipe", "1 Wipe") or T("%d wipes", "%d Wipes"):format(session.wipes),
				"avoid",
				CROSS_ICON
			)
			chips[#chips + 1] = chip
		end
		self.bosses:HideFrom(count + 1)
		local areaWidth = page.width - 112 - 20 - self.stars:GetWidth() - 12
		local chipHeight = Flow(self.chipArea, chips, 0, 0, areaWidth, 8, 26)
		self.chipArea:SetHeight(chipHeight)
		local y = 42 + chipHeight + 8

		local wins = Store_():SessionWins(player, session)
		self.winsLabel:SetShown(#wins > 0)
		if #wins > 0 then
			local frames = {}
			for index, win in ipairs(wins) do
				local chip = self.wins:Get(index)
				chip.win = win
				local text = win.link
				if win.choice then
					text = text .. " " .. K.Hex("textMuted") .. PW.ChoiceName(win.choice) .. "|r"
				end
				chip.text:SetText(text)
				chip:SetWidth(chip.text:GetStringWidth() + 16)
				frames[#frames + 1] = chip
			end
			self.winsLabel:ClearAllPoints()
			self.winsLabel:SetPoint("TOPLEFT", 112, -y - 5)
			local winsHeight = Flow(self, frames, 112 + 70, y, page.width - 20, 8, 28)
			y = y + winsHeight + 6
		end
		self.wins:HideFrom(#wins + 1)

		self.comment:ClearAllPoints()
		self.comment:SetPoint("TOPLEFT", 124, -y)
		self.comment:SetPoint("RIGHT", -20, 0)
		self.stroke:ClearAllPoints()
		self.stroke:SetPoint("TOPLEFT", 112, -y + 1)
		self.stroke:SetHeight(20)
		if not self.comment:HasFocus() then
			self.comment:SetText(session.comment or "")
			self.comment:SetCursorPosition(0)
		end
		local empty = (session.comment or "") == ""
		self.comment.placeholder:SetShown(empty and not self.comment:HasFocus())
		self.stroke:SetShown(not empty)
		return y + 20 + 18
	end
	return card
end

local function KeepSession(player, session, filter)
	if filter == "unrated" then
		return not session.stars
	elseif filter == "loot" then
		return #Store_():SessionWins(player, session) > 0
	end
	return true
end

local function CreateHistoryHeader(page)
	local header = CreateFrame("Frame", nil, page)
	header.title = K.Text(header, 15, "textStrong")
	header.title:SetPoint("LEFT")
	header.title:SetText(T("History", "Verlauf"))
	header.count = K.Text(header, 11, "textMuted")
	header.count:SetPoint("LEFT", header.title, "RIGHT", 10, -1)
	header.chips = {}
	local previous
	for index = #HISTORY_FILTERS, 1, -1 do
		local filter = HISTORY_FILTERS[index]
		local chip = K.Chip(header, 24)
		chip.filter = filter[1]
		chip.text = T(filter[2], filter[3])
		chip:SetScript("OnClick", function(self)
			Window().state.history = self.filter
			Window().RenderContent()
		end)
		if previous then
			chip:SetPoint("RIGHT", previous, "LEFT", -8, 0)
		else
			chip:SetPoint("RIGHT")
		end
		previous = chip
		header.chips[#header.chips + 1] = chip
	end
	function header:Update(player)
		local filter = Window().state.history
		for _, chip in ipairs(self.chips) do
			chip:SetChip(chip.text, nil, chip.filter == filter)
		end
		local groups = #player.sessions
		self.count:SetText(groups == 1 and T("1 group", "1 Gruppe") or T("%d groups", "%d Gruppen"):format(groups))
	end
	return header
end

-- "Often in the same group": chips with name and count.
local function CreatePartners(page, width)
	local partners = CreateFrame("Frame", nil, page)
	partners.label = K.Text(partners, 10, "textMuted")
	partners.label:SetPoint("TOPLEFT", 0, -7)
	partners.label:SetText(T("OFTEN IN THE SAME GROUP", "OFT IN DERSELBEN GRUPPE"))
	partners.chips = K.Pool(function()
		local chip = K.Chip(partners, 22)
		chip:SetScript("OnClick", function(self)
			Window().Select(self.player.name)
		end)
		return chip
	end)
	function partners:Update(player)
		local list = Store_():Partners(player, MAX_PARTNERS)
		local frames = {}
		for index, entry in ipairs(list) do
			local chip = self.chips:Get(index)
			chip.player = entry.player
			local r, g, b = K.ClassRGB(entry.player.class)
			chip:SetChip(ns.Hex({ r, g, b }) .. entry.player.name .. "|r", entry.count .. "×")
			frames[#frames + 1] = chip
		end
		self.chips:HideFrom(#list + 1)
		if #list == 0 then
			return 0
		end
		return Flow(self, frames, self.label:GetStringWidth() + 16, 0, width, 8, 30)
	end
	return partners
end

-- Page -------------------------------------------------------------------------------------

function Page.Create(parent, width)
	local page = CreateFrame("Frame", nil, parent)
	page.width = width
	local half = (width - GAP) / 2
	page.header = CreateHeader(page)
	page.marked = CreateMarkedBar(page)
	page.tags = CreateTags(page, width)
	page.tiles = CreateTiles(page, width)
	page.roles = CreateRolesCard(page)
	page.rolls = CreateRollsCard(page)
	page.note = CreateNote(page)
	page.historyHeader = CreateHistoryHeader(page)
	page.sessions = K.Pool(function()
		return CreateSessionCard(page)
	end)
	page.empty = K.Text(page, 12, "textFaint")
	page.partners = CreatePartners(page, width)

	-- Lays the page out for `player`; returns its height. `changedPlayer`
	-- is true when another player was selected (the note is replaced even
	-- while focused).
	function page:Render(player)
		local changedPlayer = self.player ~= player
		self.player = player
		local stack = K.Stack(self)
		self.header:Update(player)
		stack:Place(self.header, 104, 18)

		self.marked:SetShown(player.blocked ~= nil)
		if player.blocked then
			self.marked:Update(player)
			stack:Place(self.marked, 48, 18)
		end

		stack:Place(self.tags, self.tags:Update(player), 14)

		self.tiles:Update(player)
		stack:Place(self.tiles, 90, 18)

		local rolesHeight = self.roles:Update(player)
		local rollsHeight = self.rolls:Update(player, half)
		local height = math.max(rolesHeight, rollsHeight)
		local y = stack.y
		self.roles:ClearAllPoints()
		self.roles:SetPoint("TOPLEFT", 0, -y)
		self.roles:SetSize(half, height)
		self.rolls:ClearAllPoints()
		self.rolls:SetPoint("TOPLEFT", half + GAP, -y)
		self.rolls:SetSize(half, height)
		stack.y = y + height + 18

		stack:Place(self.note, self.note:Update(player, changedPlayer), 28)

		self.historyHeader:Update(player)
		stack:Place(self.historyHeader, 26, 14)
		local filter = Window().state.history
		local count = 0
		for index = #player.sessions, 1, -1 do
			local session = player.sessions[index]
			if KeepSession(player, session, filter) then
				count = count + 1
				local card = self.sessions:Get(count)
				stack:Place(card, card:Set(player, session), 12)
			end
		end
		self.sessions:HideFrom(count + 1)
		self.empty:SetShown(count == 0)
		if count == 0 then
			self.empty:SetText(
				#player.sessions == 0 and T("No groups together yet.", "Noch keine gemeinsame Gruppe.")
					or T("No groups for this filter.", "Keine Gruppen für diesen Filter.")
			)
			self.empty:ClearAllPoints()
			self.empty:SetPoint("TOPLEFT", 0, -stack.y)
			stack.y = stack.y + 30
		end

		stack.y = stack.y + 10
		local partnersHeight = self.partners:Update(player)
		self.partners:SetShown(partnersHeight > 0)
		if partnersHeight > 0 then
			stack:Place(self.partners, partnersHeight, 0)
		end
		self:SetHeight(stack.y)
		return stack.y
	end

	-- Lays the page out again (a tag input opened, the note grew).
	function page:Relayout()
		if self.player and self:IsShown() then
			Window().RenderContent()
		end
	end
	return page
end
