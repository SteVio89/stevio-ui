local _, ns = ...

-- "Profile & backup": the profile at a glance (when you agreed, when it was
-- last applied, what it sets), the backup with a restore, every deviation of
-- yours from the code, sharing your settings as text, and resetting
-- everything.

local K = ns.PlayersKit
local C = ns.SettingsControls
local UI = ns.SettingsUI
local Pages = ns.ConfigPages
local Meta = ns.SettingsMeta
local Keys = ns.SettingsKeys
local Info = ns.CVarInfo
local Share = ns.SettingsShare
local Deviations = ns.SettingsDeviations
local Window = ns.SettingsWindow
local config = ns.config.settings
local T = ns.T

local GAP = 16
local PAD = 16
local SHOWN_DEVIATIONS = 6

local RESTORE_DIALOG = "STEVIOUI_RESTORE_BACKUP"

StaticPopupDialogs[RESTORE_DIALOG] = {
	text = T(
		"Restore the backup? Keybindings, game settings, action bars and the Edit Mode layout go back to how they were before stevio-ui, and stevio-ui is disabled.",
		"Sicherung wiederherstellen? Tastenbelegung, Spieleinstellungen, Aktionsleisten und das Bearbeitungsmodus-Layout gehen auf den Stand vor stevio-ui zurück, und stevio-ui wird deaktiviert."
	),
	button1 = YES,
	button2 = NO,
	OnAccept = function()
		SlashCmdList.STEVIOUI("restore")
	end,
	showAlert = true,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- state: showAll (deviations), exportKeys, exportCVars, importText
local state = { exportKeys = false, exportCVars = false, importText = "" }

local function When(stamp)
	if not stamp then
		return T("unknown", "unbekannt")
	end
	local today = date("%Y-%m-%d") == date("%Y-%m-%d", stamp)
	if today then
		return T("today, %s", "heute, %s"):format(date("%H:%M", stamp))
	end
	return date(T("%m/%d/%y, %H:%M", "%d.%m.%y, %H:%M"), stamp)
end

local function Count(map)
	local count = 0
	for _ in pairs(map or {}) do
		count = count + 1
	end
	return count
end

local function Card(parent)
	return K.Box(parent, K.CardColors())
end

local function Title(parent)
	return K.Text(parent, 13, "textStrong")
end

-- Profile card --------------------------------------------------------------------

local function CreateProfileCard(page)
	local card = Card(page)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(24, 24)
	card.icon:SetPoint("TOPLEFT", PAD, -PAD)
	card.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
	card.title = Title(card)
	card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 2)
	card.title:SetText(T("Profile active", "Profil aktiv"))
	card.when = K.Text(card, 10, "textMuted")
	card.when:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
	card.tiles = {}
	for index = 1, 3 do
		local tile = K.Box(card, { 1, 1, 1, 0.03 }, { 1, 1, 1, 0.08 })
		tile:SetHeight(54)
		tile.label = K.Text(tile, 9, "textMuted")
		tile.label:SetPoint("TOPLEFT", 10, -10)
		tile.value = K.Text(tile, 17, "textStrong")
		tile.value:SetPoint("TOPLEFT", tile.label, "BOTTOMLEFT", 0, -6)
		card.tiles[index] = tile
	end
	card.note = K.Text(card, 10, "textMuted")
	card.note:SetWordWrap(true)
	card.note:SetText(
		T(
			"Applied at every login. Your own changes are kept.",
			"Wird bei jedem Login angewendet. Deine eigenen Änderungen bleiben dabei bestehen."
		)
	)
	card.apply = C.Button(card, T("Apply again now", "Jetzt erneut anwenden"), function()
		SlashCmdList.STEVIOUI("apply")
		C_Timer.After(0.5, Window.RequestRender)
	end, 24)
	card.what = C.Button(card, T("What is set?", "Was wird gesetzt?"), function(self)
		K.Menu(self, {
			{
				T("Keybindings", "Tastenbelegung"),
				function()
					Window.Open("bindings", "all")
				end,
			},
			{
				T("Graphics & game", "Grafik & Spiel"),
				function()
					Window.Open("cvars", "all")
				end,
			},
		})
	end, 24)
	card.what:SetPoint("LEFT", card.apply, "RIGHT", 8, 0)
	return card
end

local function RenderProfileCard(card, width)
	local saved = StevioUIState or {}
	card.when:SetText(
		T("agreed %s · last applied %s", "zugestimmt %s · zuletzt angewendet %s"):format(
			When(saved.consentTime),
			When(saved.lastApplied)
		)
	)
	local profile = config.profile
	local bars, barsOn = 0, 0
	for _, on in ipairs(profile.actionBars or {}) do
		bars = bars + 1
		barsOn = barsOn + (on and 1 or 0)
	end
	local cvars = 0
	for name in pairs(profile.cvars or {}) do
		if not ns.IsIgnoredCVar(name) then
			cvars = cvars + 1
		end
	end
	local tiles = {
		{ T("BARS", "LEISTEN"), profile.actionBars and T("%d of %d", "%d von %d"):format(barsOn, bars) or "–" },
		{ T("KEYS", "TASTEN"), profile.bindings and tostring(Count(profile.bindings)) or "–" },
		{ T("GAME", "SPIEL"), profile.cvars and tostring(cvars) or "–" },
	}
	local tileWidth = (width - 2 * PAD - 2 * 8) / 3
	for index, tile in ipairs(card.tiles) do
		tile.label:SetText(tiles[index][1])
		tile.value:SetText(tiles[index][2])
		tile:ClearAllPoints()
		tile:SetPoint("TOPLEFT", PAD + (index - 1) * (tileWidth + 8), -62)
		tile:SetWidth(tileWidth)
	end
	card.note:ClearAllPoints()
	card.note:SetPoint("TOPLEFT", PAD, -128)
	card.note:SetWidth(width - 2 * PAD)
	local y = 128 + card.note:GetStringHeight() + 12
	card.apply:ClearAllPoints()
	card.apply:SetPoint("TOPLEFT", PAD, -y)
	return y + 24 + PAD
end

-- Backup card -----------------------------------------------------------------------

local BACKUP_PARTS = {
	{ "Action bars on/off", "Aktionsleisten an/aus" },
	{ "Keybindings (account)", "Tastenbelegung (Account)" },
	{ "All game settings", "Alle Spieleinstellungen" },
	{ "Edit Mode layout", "Layout des Bearbeitungsmodus" },
}

local function CreateBackupCard(page)
	local card = Card(page)
	card.icon = card:CreateTexture(nil, "ARTWORK")
	card.icon:SetSize(22, 22)
	card.icon:SetPoint("TOPLEFT", PAD, -PAD)
	card.icon:SetTexture("Interface\\Icons\\INV_Shield_06")
	ns.CropIcon(card.icon)
	card.title = Title(card)
	card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, 1)
	card.sub = K.Text(card, 10, "textMuted")
	card.sub:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
	card.sub:SetText(T("made before the first takeover", "vor der ersten Übernahme erstellt"))
	card.parts = {}
	for index, part in ipairs(BACKUP_PARTS) do
		local line = K.Text(card, 11, "text")
		line:SetPoint("TOPLEFT", PAD + 4, -(58 + (index - 1) * 18))
		line:SetText("·  " .. T(part[1], part[2]))
		card.parts[index] = line
	end
	card.note = K.Text(card, 10, "textMuted")
	card.note:SetWordWrap(true)
	card.note:SetText(
		T(
			"Restoring only resets what stevio-ui manages. Everything else stays as it is.",
			"Wiederherstellen setzt nur zurück, was stevio-ui verwaltet. Alles andere bleibt, wie es ist."
		)
	)
	card.restore = C.Button(card, T("Restore backup …", "Sicherung wiederherstellen …"), function()
		StaticPopup_Show(RESTORE_DIALOG)
	end, 24)
	return card
end

local function RenderBackupCard(card, width)
	local backup = StevioUIState and StevioUIState.backup
	if backup then
		card.title:SetText(
			backup.time
					and T("Backup of %s", "Sicherung vom %s"):format(
						date(T("%m/%d/%y, %H:%M", "%d.%m.%y, %H:%M"), backup.time)
					)
				or T("Backup (date unknown)", "Sicherung (Datum unbekannt)")
		)
	else
		card.title:SetText(T("No backup", "Keine Sicherung"))
	end
	for _, line in ipairs(card.parts) do
		line:SetShown(backup ~= nil)
	end
	local y = backup and (58 + #card.parts * 18 + 8) or 58
	card.note:ClearAllPoints()
	card.note:SetPoint("TOPLEFT", PAD, -y)
	card.note:SetWidth(width - 2 * PAD)
	y = y + card.note:GetStringHeight() + 12
	card.restore:SetShown(backup ~= nil)
	card.restore:ClearAllPoints()
	card.restore:SetPoint("TOPLEFT", PAD, -y)
	return y + 24 + PAD
end

-- Deviations ------------------------------------------------------------------------

local function CvarName(name)
	local base = name:match("^RAID(.+)$")
	local info = Info.CVARS[name] or (base and Info.CVARS[base])
	if not info then
		return name
	end
	local label = T(info.name[1], info.name[2])
	return base and ("%s (%s)"):format(label, T("raid", "Schlachtzug")) or label
end

local function CvarValue(name, value)
	local info = Info.CVARS[name] or Info.CVARS[name:match("^RAID(.+)$") or ""]
	if info and info.control == "switch" then
		return value == "0" and T("off", "aus") or T("on", "an")
	elseif info and info.control == "select" then
		return Meta.OptionLabel(info.options, value) or value
	end
	return value
end

local function ActionName(command)
	local name = GetBindingName(command)
	return name ~= "" and name or command
end

local function DeviationList()
	return Deviations.List({
		values = StevioUIConfig.values,
		defaults = ns.overrideDefaults,
		bindings = StevioUIConfig.bindings,
		profileBindings = config.profile.bindings,
		actionName = ActionName,
		keyName = Keys.DisplayName,
		cvars = StevioUIConfig.cvars,
		profileCVars = config.profile.cvars,
		cvarName = CvarName,
		cvarValue = CvarValue,
	})
end

local function ResetDeviation(entry)
	if entry.kind == "value" then
		UI.ResetPath(entry.key, entry.name)
	elseif entry.kind == "binding" then
		StevioUIConfig.bindings[entry.key] = nil
		ns.ApplyOverridesNow()
		Window.RequestRender()
	else
		UI.SetCVarOverride(entry.key, nil)
	end
end

local function CreateDeviationRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(26)
	row.line = K.Texture(row, "BACKGROUND", 1, 1, 1, 0.04)
	row.line:SetHeight(1)
	row.line:SetPoint("BOTTOMLEFT")
	row.line:SetPoint("BOTTOMRIGHT")
	row.area = K.Text(row, 11, "textMuted")
	row.area:SetPoint("LEFT")
	row.area:SetWidth(130)
	row.name = K.Text(row, 11, "text")
	row.name:SetPoint("LEFT", 140, 0)
	row.reset = C.Link(row, T("Reset", "Zurücksetzen"), function()
		ResetDeviation(row.entry)
	end, 11)
	row.reset:SetPoint("RIGHT")
	row.change = K.Text(row, 11, "textStrong", "RIGHT")
	row.change:SetPoint("RIGHT", row.reset, "LEFT", -24, 0)
	return row
end

local function CreateDeviationsCard(page)
	local card = Card(page)
	card.title = Title(card)
	card.title:SetPoint("TOPLEFT", PAD, -PAD)
	card.title:SetText(T("Your deviations", "Deine Abweichungen"))
	card.sub = K.Text(card, 11, "textMuted")
	card.sub:SetPoint("LEFT", card.title, "RIGHT", 10, 0)
	card.sub:SetText(T("What you changed against the defaults", "Was du gegenüber den Vorgaben geändert hast"))
	card.all = C.Link(card, "", function()
		state.showAll = not state.showAll
		Window.Render()
	end, 11)
	card.all:SetPoint("TOPRIGHT", -PAD, -PAD)
	card.rows = K.Pool(function()
		return CreateDeviationRow(card)
	end)
	card.empty = K.Text(card, 11, "textMuted")
	card.empty:SetPoint("TOPLEFT", PAD, -46)
	card.empty:SetText(T("Nothing changed: everything is as in the code.", "Nichts geändert: Alles ist wie im Code."))
	return card
end

local function RenderDeviationsCard(card, width)
	local list = DeviationList()
	local shown = state.showAll and #list or math.min(#list, SHOWN_DEVIATIONS)
	card.all:SetShown(#list > SHOWN_DEVIATIONS)
	card.all:SetLabel(
		state.showAll and T("Show fewer", "Weniger anzeigen") or T("Show all (%d)", "Alle anzeigen (%d)"):format(#list)
	)
	card.empty:SetShown(#list == 0)
	local faint = K.Hex("textFaint")
	for index = 1, shown do
		local entry = list[index]
		local row = card.rows:Get(index)
		row.entry = entry
		row.area:SetText(entry.area)
		row.name:SetText(entry.name)
		row.change:SetText(("%s%s|r  ›  %s"):format(faint, entry.old, entry.new))
		row.name:SetPoint("RIGHT", row.change, "LEFT", -12, 0)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", PAD, -(44 + (index - 1) * 26))
		row:SetWidth(width - 2 * PAD)
	end
	card.rows:HideFrom(shown + 1)
	return 44 + math.max(shown, 1) * 26 + PAD
end

-- Sharing -------------------------------------------------------------------------

-- A box with a multi-line text field that scrolls.
local function TextArea(parent, onChange)
	local box = K.Box(parent, { 0, 0, 0, 0.25 }, { 1, 1, 1, 0.10 })
	box:SetHeight(64)
	local scroll = CreateFrame("ScrollFrame", nil, box)
	scroll:SetPoint("TOPLEFT", 8, -6)
	scroll:SetPoint("BOTTOMRIGHT", -8, 6)
	local edit = CreateFrame("EditBox", nil, scroll)
	edit:SetMultiLine(true)
	edit:SetAutoFocus(false)
	edit:SetFontObject(ChatFontNormal)
	edit:SetTextColor(K.RGB("textMuted"))
	edit:SetScript("OnEscapePressed", edit.ClearFocus)
	edit:SetScript("OnTextChanged", function(self, userInput)
		if userInput and onChange then
			onChange(self:GetText())
		end
	end)
	scroll:SetScrollChild(edit)
	scroll:SetScript("OnSizeChanged", function(_, width)
		edit:SetWidth(width)
	end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 14)))
	end)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function()
		edit:SetFocus()
	end)
	box.edit = edit
	return box
end

-- Takes over a checked import: options as overrides (reload bar), keys and
-- game settings applied at once.
local function ApplyImport(result)
	local entries = {}
	for _, value in ipairs(result.values) do
		entries[#entries + 1] = { path = value.path, value = value.value, label = (Meta.Text(value.path)) }
	end
	for key, command in pairs(result.bindings) do
		UI.SetBindingOverride(key, command or nil)
	end
	for name, value in pairs(result.cvars) do
		UI.SetCVarOverride(name, value)
	end
	UI.WriteMany(entries)
end

-- The first entries of an import, as "Chat: Opacity when read → 95 %".
local function PreviewLines(result)
	local lines = {}
	for _, value in ipairs(result.values) do
		local module = Pages.Module(Pages.ModuleForPath(value.encoded) or "")
		local meta = Meta.Lookup(value.path)
		lines[#lines + 1] = ("%s: %s › %s"):format(
			module and Pages.Title(module) or value.path[2],
			(Meta.Text(value.path)),
			Meta.FormatValue(value.value, meta, meta.control)
		)
	end
	for key, command in pairs(result.bindings) do
		lines[#lines + 1] = ("%s: %s › %s"):format(
			T("Key", "Taste"),
			command and ActionName(command) or "–",
			Keys.DisplayName(key)
		)
	end
	for name, value in pairs(result.cvars) do
		lines[#lines + 1] = ("%s › %s"):format(CvarName(name), CvarValue(name, value))
	end
	return lines
end

local function CopyHint()
	return IsMacClient and IsMacClient() and T("Cmd+C copies", "Cmd+C kopiert") or T("Ctrl+C copies", "Strg+C kopiert")
end

local function CreateShareCard(page)
	local card = Card(page)
	card.title = Title(card)
	card.title:SetPoint("TOPLEFT", PAD, -PAD)
	card.title:SetText(T("Share settings", "Einstellungen teilen"))
	card.sub = K.Text(card, 11, "textMuted")
	card.sub:SetPoint("LEFT", card.title, "RIGHT", 10, 0)
	card.sub:SetText(
		T(
			"Pass your own changes on as text or take some over",
			"Eigene Abweichungen als Text weitergeben oder übernehmen"
		)
	)

	card.exportTitle = K.Text(card, 11, "textStrong")
	card.exportTitle:SetText(T("Export", "Exportieren"))
	card.keys = K.Chip(card, 20)
	card.keys:SetScript("OnClick", function()
		state.exportKeys = not state.exportKeys
		Window.Render()
	end)
	card.cvars = K.Chip(card, 20)
	card.cvars:SetScript("OnClick", function()
		state.exportCVars = not state.exportCVars
		Window.Render()
	end)
	card.exportText = TextArea(card)
	card.copy = C.Button(card, T("Copy", "Kopieren"), function()
		card.exportText.edit:SetFocus()
		card.exportText.edit:HighlightText()
		card.copyHint:SetText(CopyHint())
	end, 24)
	card.copyHint = K.Text(card, 10, "textMuted")
	card.copyHint:SetPoint("LEFT", card.copy, "RIGHT", 10, 0)

	card.importTitle = K.Text(card, 11, "textStrong")
	card.importTitle:SetText(T("Import", "Importieren"))
	card.importText = TextArea(card, function(text)
		state.importText = text
		Window.RequestRender()
	end)
	card.preview = K.Text(card, 10, "text")
	card.preview:SetWordWrap(true)
	card.take = C.Button(card, T("Take over", "Übernehmen"), function()
		if card.result then
			ApplyImport(card.result)
			state.importText = ""
			card.importText.edit:SetText("")
			state.imported = true
			Window.RequestRender()
		end
	end, 24)
	card.take:SetActive(true)
	card.take:SetScript("OnLeave", function(self)
		self:SetActive(true)
	end)
	card.discard = C.Button(card, T("Discard", "Verwerfen"), function()
		state.importText = ""
		card.importText.edit:SetText("")
		Window.RequestRender()
	end, 24)
	card.discard:SetPoint("LEFT", card.take, "RIGHT", 8, 0)

	card.dev = K.Text(card, 10, "textMuted")
	card.dev:SetText(T("For developers:", "Für Entwickler:"))
	card.devLink = C.Link(
		card,
		T("Export the whole profile as Profile.lua", "Ganzes Profil als Profile.lua exportieren"),
		function()
			SlashCmdList.STEVIOUI("export")
		end
	)
	card.devLink:SetPoint("LEFT", card.dev, "RIGHT", 4, 0)
	card.devCommand = K.Text(card, 10, "textMuted")
	card.devCommand:SetPoint("LEFT", card.devLink, "RIGHT", 4, 0)
	card.devCommand:SetText("(/sui export)")
	return card
end

local function RenderShareCard(card, width)
	local half = (width - 2 * PAD - GAP) / 2
	local leftX, rightX = PAD, PAD + half + GAP
	local y = 50

	-- Export.
	card.exportTitle:ClearAllPoints()
	card.exportTitle:SetPoint("TOPLEFT", leftX, -y)
	card.keys:SetChip(T("with keys", "mit Tasten"), nil, state.exportKeys)
	card.cvars:SetChip(T("with game settings", "mit Spieleinstellungen"), nil, state.exportCVars)
	card.cvars:ClearAllPoints()
	card.cvars:SetPoint("TOPRIGHT", card, "TOPLEFT", leftX + half, -(y - 4))
	card.keys:ClearAllPoints()
	card.keys:SetPoint("RIGHT", card.cvars, "LEFT", -6, 0)
	local bindings = state.exportKeys and StevioUIConfig.bindings or nil
	local cvars = state.exportCVars and StevioUIConfig.cvars or nil
	local text = Share.Export(StevioUIConfig.values, bindings, cvars)
	if not card.exportText.edit:HasFocus() then
		card.exportText.edit:SetText(text)
		card.exportText.edit:SetCursorPosition(0)
	end
	card.exportText:ClearAllPoints()
	card.exportText:SetPoint("TOPLEFT", leftX, -(y + 22))
	card.exportText:SetWidth(half)
	card.copy:ClearAllPoints()
	card.copy:SetPoint("TOPLEFT", leftX, -(y + 22 + 64 + 10))
	card.copyHint:SetText(Share.Summary(Count(StevioUIConfig.values), Count(bindings), Count(cvars)))

	-- Import.
	card.importTitle:ClearAllPoints()
	card.importTitle:SetPoint("TOPLEFT", rightX, -y)
	card.importText:ClearAllPoints()
	card.importText:SetPoint("TOPLEFT", rightX, -(y + 22))
	card.importText:SetWidth(half)
	local result, problem
	if state.importText:find("%S") then
		result, problem = Share.Import(state.importText, {
			defaults = ns.overrideDefaults,
			isIgnored = ns.IsIgnoredCVar,
			cvarExists = function(name)
				return ns.SettableCVar(name) ~= nil
			end,
		})
	end
	card.result = result
	local previewY = y + 22 + 64 + 8
	card.preview:ClearAllPoints()
	card.preview:SetPoint("TOPLEFT", rightX, -previewY)
	card.preview:SetWidth(half)
	local previewText
	if problem then
		previewText = ns.Hex(ns.config.style.palette.warning) .. problem .. "|r"
	elseif result then
		local lines = PreviewLines(result)
		local count = #lines
		previewText = (
			count == 1 and T("Preview: 1 change", "Vorschau: 1 Änderung")
			or T("Preview: %d changes", "Vorschau: %d Änderungen"):format(count)
		)
		local first = {}
		for index = 1, math.min(3, count) do
			first[index] = lines[index]
		end
		if #first > 0 then
			previewText = previewText .. "\n" .. table.concat(first, " · ")
		end
		if count > 3 then
			previewText = previewText .. T(" and %d more", " und %d weitere"):format(count - 3)
		end
		if #result.skipped > 0 then
			previewText = previewText
				.. "\n"
				.. ns.Hex(ns.config.style.palette.warning)
				.. T("Skipped: %s", "Übersprungen: %s"):format(table.concat(result.skipped, ", "))
				.. "|r"
		end
	elseif state.imported then
		previewText =
			T("Taken over. Options take effect after a reload.", "Übernommen. Optionen wirken nach dem Neuladen.")
	else
		previewText = T("Paste a text starting with !SUI1! here.", "Füge hier einen Text ein, der mit !SUI1! beginnt.")
	end
	card.preview:SetText(previewText)
	local previewHeight = math.max(card.preview:GetStringHeight(), 14)
	card.take:SetShown(result ~= nil)
	card.discard:SetShown(state.importText ~= "")
	card.take:ClearAllPoints()
	card.take:SetPoint("TOPLEFT", rightX, -(previewY + previewHeight + 8))
	if not result then
		card.discard:ClearAllPoints()
		card.discard:SetPoint("TOPLEFT", rightX, -(previewY + previewHeight + 8))
	else
		card.discard:ClearAllPoints()
		card.discard:SetPoint("LEFT", card.take, "RIGHT", 8, 0)
	end

	local bottom = math.max(y + 22 + 64 + 10 + 24, previewY + previewHeight + 8 + 24) + 16
	card.dev:ClearAllPoints()
	card.dev:SetPoint("TOPLEFT", PAD, -bottom)
	return bottom + 14 + PAD
end

-- Reset everything --------------------------------------------------------------------

local function CreateDangerCard(page)
	local danger = ns.config.style.palette.danger
	local card = K.Box(page, { danger[1], danger[2], danger[3], 0.05 }, { danger[1], danger[2], danger[3], 0.6 })
	card.title = K.Text(card, 13)
	card.title:SetTextColor(unpack(danger))
	card.title:SetPoint("TOPLEFT", PAD, -PAD)
	card.title:SetText(T("Reset everything", "Alles zurücksetzen"))
	card.text = K.Text(card, 11, "textMuted")
	card.text:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -6)
	card.text:SetWordWrap(true)
	card.text:SetText(
		T(
			"Sets every stevio-ui option, your own keys and game settings back to the defaults and reloads. The backup is kept.",
			"Setzt alle stevio-ui-Optionen, eigenen Tasten und Spieleinstellungen auf die Vorgaben zurück und lädt neu. Die Sicherung bleibt erhalten."
		)
	)
	card.button = C.Button(card, T("Reset …", "Zurücksetzen …"), function()
		StaticPopup_Show(ns.RESET_CONFIG_DIALOG)
	end, 26)
	card.button:SetPoint("RIGHT", -PAD, 0)
	card.text:SetPoint("RIGHT", card.button, "LEFT", -24, 0)
	return card
end

-- Page --------------------------------------------------------------------------------

local function Create(parent)
	local page = CreateFrame("Frame", nil, parent)
	page.crumb = K.Text(page, 10, "textMuted")
	page.crumb:SetPoint("TOPLEFT")
	page.crumb:SetText(T("System ›", "System ›"))
	page.title = K.Text(page, 22, "textStrong")
	page.title:SetPoint("TOPLEFT", 0, -16)
	page.title:SetText(T("Profile & backup", "Profil & Sicherung"))
	page.description = K.Text(page, 12, "text")
	page.description:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", 0, -8)
	page.description:SetWordWrap(true)
	page.description:SetText(
		T(
			"The profile is stevio-ui's basic setup: action bars, keybindings and game settings. Before it was applied for the first time, stevio-ui backed up your previous settings.",
			"Das Profil ist die Grundausstattung von stevio-ui: Aktionsleisten, Tastenbelegung und Spieleinstellungen. Bevor es zum ersten Mal angewendet wurde, hat stevio-ui deine bisherigen Einstellungen gesichert."
		)
	)
	page.profile = CreateProfileCard(page)
	page.backup = CreateBackupCard(page)
	page.deviations = CreateDeviationsCard(page)
	page.share = CreateShareCard(page)
	page.otherTitle = C.Heading(page)
	page.rows = C.RowPools(page)
	page.danger = CreateDangerCard(page)
	return page
end

local function Render(page, focus, width)
	page.description:SetWidth(width - 80)
	local y = 16 + 30 + page.description:GetStringHeight() + 20

	local half = (width - GAP) / 2
	page.profile:ClearAllPoints()
	page.profile:SetPoint("TOPLEFT", 0, -y)
	page.profile:SetWidth(half)
	page.backup:ClearAllPoints()
	page.backup:SetPoint("TOPLEFT", half + GAP, -y)
	page.backup:SetWidth(half)
	local height = math.max(RenderProfileCard(page.profile, half), RenderBackupCard(page.backup, half))
	page.profile:SetHeight(height)
	page.backup:SetHeight(height)
	y = y + height + GAP

	page.deviations:ClearAllPoints()
	page.deviations:SetPoint("TOPLEFT", 0, -y)
	page.deviations:SetWidth(width)
	height = RenderDeviationsCard(page.deviations, width)
	page.deviations:SetHeight(height)
	y = y + height + GAP

	local shareTop = y
	page.share:ClearAllPoints()
	page.share:SetPoint("TOPLEFT", 0, -y)
	page.share:SetWidth(width)
	height = RenderShareCard(page.share, width)
	page.share:SetHeight(height)
	y = y + height + GAP + 8

	-- The profile module's own options (console key).
	local settings = Pages.Module("settings")
	page.rows:Begin()
	local items = {}
	for _, item in ipairs(UI.Items(settings)) do
		if not item.advanced then
			items[#items + 1] = item
		end
	end
	page.otherTitle:SetShown(#items > 0)
	if #items > 0 then
		local section = settings.sections[1]
		page.otherTitle:ClearAllPoints()
		page.otherTitle:SetPoint("TOPLEFT", 0, -y)
		page.otherTitle:SetWidth(width)
		page.otherTitle:Set(T(section.title[1], section.title[2]))
		y = y + 28
		for _, item in ipairs(items) do
			local row = page.rows:Get(C.Kind(item))
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			row:SetWidth(width)
			y = y + C.FillRow(row, item, { width = width })
		end
		y = y + GAP
	end
	page.rows:Finish()

	page.danger:ClearAllPoints()
	page.danger:SetPoint("TOPLEFT", 0, -y)
	page.danger:SetWidth(width)
	page.danger:SetHeight(72)
	y = y + 72

	if focus == "share" and not page.focused then
		page.focused = true
		-- After the window has taken the new page height.
		C_Timer.After(0, function()
			Window.ScrollTo(shareTop - 16)
		end)
	elseif focus ~= "share" then
		page.focused = nil
	end
	page:SetHeight(y)
	return y
end

Window.RegisterPage("profile", { Create = Create, Render = Render })
