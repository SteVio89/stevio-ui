local _, ns = ...

-- The overview page of the players window (#86): numbers over everyone you
-- grouped with in the chosen period (Store:Overview), the groups still to
-- rate, roll behaviour, who you spend most time with and who to watch out
-- for. Every name opens that player's page.

local Overview = {}
ns.PlayersOverview = Overview

local Store = ns.PlayersStore
local PW = ns.PlayerWidgets
local K = ns.PlayersKit
local T = ns.T

local GAP = 12
local CHOICE_COLORS = { need = "need", greed = "greed", transmog = "transmog", pass = "pass" }
local PERIODS = { { 7, "7 days", "7 Tage" }, { 30, "30 days", "30 Tage" }, { false, "All", "Alles" } }
local MAX_ATTENTION = 4
local MAX_OUTLIERS = 3

local function Window()
	return ns.PlayersWindow
end

-- A clickable player name that opens their page.
local function NameButton(parent, size)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(16)
	button.text = K.Text(button, size or 12, "text")
	button.text:SetPoint("LEFT")
	function button:SetPlayer(player)
		self.player = player
		self.text:SetText(K.ColoredName(player.name, player.class))
		self:SetWidth(self.text:GetStringWidth())
	end
	button:SetScript("OnClick", function(self)
		Window().Select(self.player.name)
	end)
	button:SetScript("OnEnter", function(self)
		self.text:SetAlpha(0.8)
	end)
	button:SetScript("OnLeave", function(self)
		self.text:SetAlpha(1)
	end)
	return button
end

-- Parts ---------------------------------------------------------------------------

local function CreateHeader(page)
	local header = CreateFrame("Frame", nil, page)
	header.title = K.Text(header, 24, "textStrong")
	header.title:SetPoint("TOPLEFT")
	header.title:SetText(T("Overview", "Übersicht"))
	header.sub = K.Text(header, 12, "textMuted")
	header.sub:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 0, -8)
	header.sub:SetText(T("Everyone you were in a group with.", "Alle, mit denen du in einer Gruppe warst."))
	local items = {}
	for _, period in ipairs(PERIODS) do
		items[#items + 1] = { period[1], T(period[2], period[3]), false }
	end
	header.period = K.Segmented(header, items, function(key)
		Window().state.period = key or nil
		Window().RenderContent()
	end, 32)
	header.period:SetPoint("TOPRIGHT", 0, 0)
	return header
end

-- The bar asking to rate the groups of the last week.
local function CreateHint(page)
	local accent = K.Color("accent")
	local hint = K.Box(page, { accent[1], accent[2], accent[3], 0.16 }, { accent[1], accent[2], accent[3], 0.6 })
	local badge = K.Circle(hint, "ARTWORK")
	badge:SetSize(36, 36)
	badge:SetPoint("LEFT", 18, 0)
	badge:SetVertexColor(accent[1], accent[2], accent[3], 0.35)
	local star = hint:CreateTexture(nil, "OVERLAY")
	star:SetSize(16, 16)
	star:SetPoint("CENTER", badge)
	star:SetTexture(K.ICON_STAR)
	hint.text = K.Text(hint, 13, "textStrong")
	hint.text:SetPoint("TOPLEFT", badge, "TOPRIGHT", 16, -1)
	hint.sub = K.Text(hint, 11, "text")
	hint.sub:SetPoint("TOPLEFT", hint.text, "BOTTOMLEFT", 0, -6)
	hint.sub:SetText(
		T(
			"Quick to do: one group after the other, stars and a sentence are enough.",
			"Geht schnell: eine Gruppe nach der anderen, Sterne und ein Satz reichen."
		)
	)
	hint.button = K.Button(hint, T("Rate now", "Jetzt bewerten"), 32)
	hint.button:SetPoint("RIGHT", -18, 0)
	hint.button:SetActive(true)
	hint.button:SetScript("OnLeave", nil)
	hint.button.bg:SetVertexColor(accent[1], accent[2], accent[3], 0.9)
	hint.button:SetScript("OnClick", function()
		local store, now = Window().Store(), Window().Now()
		local since = Store.PeriodStart(PW.DayStart(now), Store.UNRATED_DAYS)
		ns.PlayersPopup.ShowQueue(store:UnratedGroups(now, since))
	end)
	return hint
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
	return row
end

-- "Your ratings": players per rounded average, 5 stars down to 1.
local function CreateRatingsCard(parent)
	local card = K.Card(parent, T("Your ratings", "Deine Bewertungen"))
	card.rows = {}
	for index = 1, 5 do
		local stars = 6 - index
		local row = CreateFrame("Frame", nil, card)
		row:SetHeight(18)
		row:SetPoint("TOPLEFT", 16, -40 - (index - 1) * 24)
		row:SetPoint("RIGHT", -16, 0)
		row.stars = K.Stars(row, 10, nil, 2)
		row.stars:SetPoint("LEFT")
		row.stars:SetValue(stars)
		row.count = K.Text(row, 12, "textStrong", "RIGHT")
		row.count:SetPoint("RIGHT")
		row.count:SetWidth(30)
		row.bar = K.Bar(row, 11)
		row.bar:SetPoint("LEFT", row.stars, "RIGHT", 16, 0)
		row.bar:SetPoint("RIGHT", row.count, "LEFT", -16, 0)
		row.bar:EnableMouse(true)
		card.rows[index] = row
	end
	card.note = K.Text(card, 10, "textMuted")
	card.note:SetPoint("TOPLEFT", 16, -40 - 5 * 24 - 4)
	card.note:SetText(T("Players by their average, rounded.", "Anzahl Spieler nach ihrem Durchschnitt, gerundet."))
	function card:Update(overview)
		local most = 1
		for _, count in ipairs(overview.distribution) do
			most = math.max(most, count)
		end
		for index, row in ipairs(self.rows) do
			local stars = 6 - index
			local count = overview.distribution[stars]
			row.count:SetText(count)
			row.bar:SetFraction(count / most, K.RGB("accent"))
			row.bar.tooltip = T("%d players around %d stars", "%d Spieler um %d Sterne"):format(count, stars)
		end
	end
	return card
end

local function ChoiceLegend(card)
	card.legend = {}
	for index, choice in ipairs(Store.CHOICES) do
		local entry = K.Legend(card)
		entry.choice = choice
		card.legend[index] = entry
	end
end

-- Places the legend entries in rows of `perRow` below `anchor`.
local function LayoutLegend(card, anchor, perRow, columnWidth)
	for index, entry in ipairs(card.legend) do
		local column, line = (index - 1) % perRow, math.floor((index - 1) / perRow)
		entry:ClearAllPoints()
		entry:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", column * columnWidth, -14 - line * 22)
	end
end

-- "Roll behaviour of everyone": the shares as one bar, a legend and the
-- Need outliers.
local function CreateRollsCard(parent)
	local card = K.Card(parent, T("Roll behaviour of everyone", "Würfelverhalten aller"))
	card.bar = K.StackedBar(card, 10)
	card.bar:SetPoint("TOPLEFT", 16, -42)
	card.bar:SetPoint("RIGHT", -16, 0)
	ChoiceLegend(card)
	LayoutLegend(card, card.bar, 3, 105)
	card.outlierTitle = K.Text(card, 11, "textMuted")
	card.outlierTitle:SetPoint("TOPLEFT", card.bar, "BOTTOMLEFT", 0, -82)
	card.outlierTitle:SetText(
		T("Need conspicuously often", "Auffällig viel Bedarf")
			.. K.Hex("textFaint")
			.. T(" (from 10 rolls, 1.5× average)", " (ab 10 Würfen, 1,5× Schnitt)")
			.. "|r"
	)
	card.outliers = K.Pool(function()
		local row = CreateFrame("Frame", nil, card)
		row:SetHeight(20)
		row.name = NameButton(row)
		row.name:SetPoint("LEFT")
		row.rolls = K.Text(row, 11, "textMuted", "RIGHT")
		row.rolls:SetPoint("RIGHT")
		row.rolls:SetWidth(70)
		row.share = K.Text(row, 12, "low", "RIGHT")
		row.share:SetPoint("RIGHT", row.rolls, "LEFT", -6, 0)
		return row
	end)
	card.empty = K.Text(card, 11, "textFaint")
	card.empty:SetPoint("TOPLEFT", card.outlierTitle, "BOTTOMLEFT", 0, -8)
	card.empty:SetText(T("Nobody so far.", "Bisher niemand."))
	function card:Update(store)
		local averages = store:RollAverages()
		self.aside:SetText(T("%d rolls", "%d Würfe"):format(averages.total))
		local parts = {}
		for index, choice in ipairs(Store.CHOICES) do
			parts[index] = { averages[choice].count, CHOICE_COLORS[choice] }
			self.legend[index]:Set(
				CHOICE_COLORS[choice],
				("%s  %s%d %%|r"):format(
					PW.ChoiceName(choice),
					K.Hex("textStrong"),
					Store.Percent(averages[choice].count, averages.total)
				)
			)
		end
		self.bar:SetParts(parts)
		local outliers = store:NeedOutliers(averages)
		for index = 1, math.min(MAX_OUTLIERS, #outliers) do
			local entry = outliers[index]
			local row = self.outliers:Get(index)
			row:SetPoint("TOPLEFT", self.outlierTitle, "BOTTOMLEFT", 0, -6 - (index - 1) * 22)
			row:SetPoint("RIGHT", self, "RIGHT", -16, 0)
			row.name:SetPlayer(entry.player)
			row.share:SetText(("%d %%"):format(math.floor(entry.share * 100 + 0.5)))
			row.rolls:SetText(T("%d rolls", "%d Würfe"):format(entry.total))
		end
		self.outliers:HideFrom(math.min(MAX_OUTLIERS, #outliers) + 1)
		self.empty:SetShown(#outliers == 0)
		return 42 + 10 + 82 + 14 + math.max(1, math.min(MAX_OUTLIERS, #outliers)) * 22 + 16
	end
	return card
end

-- "Most time with": the top 5 by time together, as bars.
local function CreateTopCard(parent)
	local card = K.Card(parent, T("Most time with", "Am meisten Zeit mit"))
	card.rows = K.Pool(function(index)
		local row = CreateFrame("Frame", nil, card)
		row:SetHeight(18)
		row:SetPoint("TOPLEFT", 16, -42 - (index - 1) * 26)
		row:SetPoint("RIGHT", -16, 0)
		row.name = NameButton(row)
		row.name:SetPoint("LEFT")
		row.time = K.Text(row, 12, "textStrong", "RIGHT")
		row.time:SetPoint("RIGHT")
		row.time:SetWidth(60)
		row.bar = K.Bar(row, 8)
		row.bar:SetPoint("LEFT", row, "LEFT", 170, 0)
		row.bar:SetPoint("RIGHT", row.time, "LEFT", -20, 0)
		row.bar.track:Hide()
		return row
	end)
	card.empty = K.Text(card, 11, "textFaint")
	card.empty:SetPoint("TOPLEFT", 16, -44)
	card.empty:SetText(T("No groups in this period.", "Keine Gruppen in diesem Zeitraum."))
	function card:Update(overview)
		local most = overview.top[1] and overview.top[1].seconds or 1
		for index, entry in ipairs(overview.top) do
			local row = self.rows:Get(index)
			row.name:SetPlayer(entry.player)
			row.time:SetText(Store.FormatDuration(entry.seconds))
			row.bar:SetFraction(entry.seconds / most, K.RGB("accent"))
		end
		self.rows:HideFrom(#overview.top + 1)
		self.empty:SetShown(#overview.top == 0)
		return 42 + math.max(1, #overview.top) * 26 + 10
	end
	return card
end

local REASONS = {
	blocked = function(player)
		local parts = {}
		if player.verdict == "avoid" then
			parts[#parts + 1] = T("Avoid", "Meiden")
		end
		parts[#parts + 1] = T("marked <%s>", "markiert <%s>"):format(player.blocked.guild or "?")
		return parts
	end,
	avoid = function()
		return { T("Avoid", "Meiden") }
	end,
	low = function()
		return {}
	end,
}

-- "Careful": marked, avoided and low rated players.
local function CreateAttentionCard(parent)
	local card = K.Card(parent, T("Careful", "Achtung"))
	card.rows = K.Pool(function(index)
		local row = CreateFrame("Frame", nil, card)
		row:SetHeight(48)
		row:SetPoint("TOPLEFT", 16, -34 - (index - 1) * 48)
		row:SetPoint("RIGHT", -16, 0)
		row.dot = K.Circle(row, "ARTWORK")
		row.dot:SetSize(7, 7)
		row.dot:SetPoint("LEFT", 2, 0)
		row.name = NameButton(row)
		row.name:SetPoint("TOPLEFT", 18, -8)
		row.reason = K.Text(row, 11, "textMuted")
		row.reason:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.when = K.Text(row, 11, "textMuted", "RIGHT")
		row.when:SetPoint("RIGHT")
		row.line = K.Texture(row, "ARTWORK", 1, 1, 1, 0.06)
		row.line:SetPoint("BOTTOMLEFT")
		row.line:SetPoint("BOTTOMRIGHT")
		row.line:SetHeight(1)
		return row
	end)
	card.empty = K.Text(card, 11, "textFaint")
	card.empty:SetPoint("TOPLEFT", 16, -44)
	card.empty:SetText(T("Nobody to watch out for.", "Niemand, vor dem du dich hüten musst."))
	function card:Update(overview)
		local count = math.min(MAX_ATTENTION, #overview.attention)
		for index = 1, count do
			local entry = overview.attention[index]
			local row = self.rows:Get(index)
			row.dot:SetVertexColor(K.RGB(entry.reason == "low" and "low" or "avoid"))
			row.name:SetPlayer(entry.player)
			local parts = REASONS[entry.reason](entry.player)
			if entry.overall then
				parts[#parts + 1] = T("%s stars", "%s Sterne"):format(Store.FormatAverage(entry.overall.average))
			elseif entry.reason ~= "low" then
				parts[#parts + 1] = T("not rated yet", "noch nicht bewertet")
			end
			row.reason:SetText(table.concat(parts, " · "))
			row.when:SetText(PW.When(entry.player.lastSeen, Window().Now()))
			row.line:SetShown(index < count)
		end
		self.rows:HideFrom(count + 1)
		self.empty:SetShown(count == 0)
		self.aside:SetText(#overview.attention > count and ("+%d"):format(#overview.attention - count) or "")
		return 34 + math.max(1, count) * 48 + 12
	end
	return card
end

-- "Groups per day": a column per day of the period.
local function CreateDaysCard(parent)
	local card = K.Card(parent, T("Groups per day", "Gruppen pro Tag"))
	card.area = CreateFrame("Frame", nil, card)
	card.area:SetPoint("TOPLEFT", 16, -44)
	card.area:SetPoint("BOTTOMRIGHT", -16, 34)
	card.baseline = K.Texture(card.area, "BACKGROUND", 1, 1, 1, 0.06)
	card.baseline:SetPoint("BOTTOMLEFT")
	card.baseline:SetPoint("BOTTOMRIGHT")
	card.baseline:SetHeight(1)
	card.columns = K.Pool(function()
		local column = CreateFrame("Frame", nil, card.area)
		column.fill = K.Texture(column, "ARTWORK")
		column.fill:SetPoint("BOTTOMLEFT")
		column.fill:SetPoint("BOTTOMRIGHT")
		column:EnableMouse(true)
		column:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.label)
			GameTooltip:AddLine(T("%d groups", "%d Gruppen"):format(self.count), 1, 1, 1)
			GameTooltip:Show()
		end)
		column:SetScript("OnLeave", GameTooltip_Hide)
		return column
	end)
	card.first = K.Text(card, 10, "textMuted")
	card.first:SetPoint("BOTTOMLEFT", 16, 14)
	card.middle = K.Text(card, 10, "textMuted", "CENTER")
	card.middle:SetPoint("BOTTOM", 0, 14)
	card.last = K.Text(card, 10, "textMuted", "RIGHT")
	card.last:SetPoint("BOTTOMRIGHT", -16, 14)
	function card:Update(overview, width, days)
		local perDay = overview.perDay
		local count = #perDay
		self.aside:SetText(
			days and T("last %d days", "letzte %d Tage"):format(days)
				or T("last %d days", "letzte %d Tage"):format(count)
		)
		local most = 1
		for _, value in ipairs(perDay) do
			most = math.max(most, value)
		end
		local areaWidth, areaHeight = width - 32, 150 - 44 - 34
		local slot = areaWidth / count
		local gap = math.max(1, math.min(6, slot * 0.25))
		local today = PW.DayStart(Window().Now())
		local accent = K.Color("accent")
		for index, value in ipairs(perDay) do
			local column = self.columns:Get(index)
			column:ClearAllPoints()
			column:SetPoint("BOTTOMLEFT", (index - 1) * slot + gap / 2, 0)
			column:SetSize(math.max(1, slot - gap), areaHeight)
			column.fill:SetHeight(math.max(1, areaHeight * value / most))
			column.fill:SetShown(value > 0)
			-- Today stands out a little.
			column.fill:SetVertexColor(accent[1], accent[2], accent[3], index == count and 1 or 0.7)
			-- Noon of that day, so a daylight saving change can't shift the date.
			local day = today - (count - index) * 86400 + 43200
			column.label = ("%s %s"):format(PW.Weekday(day), date("%d.%m.", day))
			column.count = value
		end
		self.columns:HideFrom(count + 1)
		self.first:SetText(date("%d.%m.", today - (count - 1) * 86400 + 43200))
		self.middle:SetText(date("%d.%m.", today - math.floor(count / 2) * 86400 + 43200))
		self.last:SetText(T("today", "heute"))
		return 150
	end
	return card
end

-- Page ---------------------------------------------------------------------------------

function Overview.Create(parent, width)
	local page = CreateFrame("Frame", nil, parent)
	page.header = CreateHeader(page)
	page.hint = CreateHint(page)
	page.tiles = CreateTiles(page, width)
	local half = (width - GAP) / 2
	page.ratings = CreateRatingsCard(page)
	page.rolls = CreateRollsCard(page)
	page.top = CreateTopCard(page)
	page.attention = CreateAttentionCard(page)
	page.days = CreateDaysCard(page)

	local function Pair(left, right, y, height)
		left:ClearAllPoints()
		left:SetPoint("TOPLEFT", 0, -y)
		left:SetSize(half, height)
		right:ClearAllPoints()
		right:SetPoint("TOPLEFT", half + GAP, -y)
		right:SetSize(half, height)
	end

	-- Lays the page out for the current period; returns its height.
	function page:Render()
		local window = Window()
		local store, now = window.Store(), window.Now()
		local days = window.state.period
		local overview = store:Overview(now, days, PW.DayStart(now))
		local stack = K.Stack(self)

		self.header.period:Select(days or false)
		stack:Place(self.header, 56, 20)

		self.hint:SetShown(overview.unratedGroups > 0)
		if overview.unratedGroups > 0 then
			self.hint.text:SetText(
				T(
					"%d groups of the last 7 days are not rated yet",
					"%d Gruppen der letzten 7 Tage sind noch unbewertet"
				):format(overview.unratedGroups)
			)
			stack:Place(self.hint, 72, 18)
		end

		local periodText = days and T("in %d days", "in %d Tagen"):format(days) or T("in total", "insgesamt")
		local tiles = self.tiles.tiles
		tiles[1]:Set(
			T("Players", "Spieler"),
			overview.players,
			T("%d new %s", "%d neu %s"):format(overview.newPlayers, periodText)
		)
		tiles[2]:Set(
			T("Groups", "Gruppen"),
			overview.groups,
			T("%d of them dungeons", "davon %d Dungeons"):format(overview.dungeons)
		)
		tiles[3]:Set(
			T("Time in groups", "Zeit in Gruppen"),
			Store.FormatDuration(overview.seconds),
			T("Ø %s per group", "Ø %s pro Gruppe"):format(Store.FormatDuration(overview.averageSeconds))
		)
		tiles[4]:Set(T("Bosses", "Bosse"), overview.kills, T("%d wipes", "%d Wipes"):format(overview.wipes))
		tiles[5]:Set(
			T("Rated", "Bewertet"),
			overview.rated,
			overview.averageStars
					and T("Ø %s stars", "Ø %s Sterne"):format(Store.FormatAverage(overview.averageStars))
				or T("no stars yet", "noch keine Sterne")
		)
		stack:Place(self.tiles, 90, 18)

		self.ratings:Update(overview)
		local rollsHeight = self.rolls:Update(store)
		local y = stack.y
		local height = math.max(214, rollsHeight)
		Pair(self.ratings, self.rolls, y, height)
		stack.y = y + height + 18

		local topHeight = self.top:Update(overview)
		local attentionHeight = self.attention:Update(overview)
		y = stack.y
		height = math.max(topHeight, attentionHeight, 120)
		Pair(self.top, self.attention, y, height)
		stack.y = y + height + 18

		stack:Place(self.days, self.days:Update(overview, width, days), 0)
		self:SetHeight(stack.y)
		return stack.y
	end
	return page
end
