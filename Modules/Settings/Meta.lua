local _, ns = ...

-- Metadata of the config values for the settings window: which section of
-- its module page a value sits in, which control edits it, its range and unit,
-- and whether it is technical ("advanced", folded away at the end of the
-- page). Values without metadata still show, with a control derived from the
-- value (Meta.Derive). Kept free of WoW API calls so it can be tested outside
-- the game (tests/settings_meta_test.lua).
--
-- Keys are paths below ns.config without the "config" root, or below
-- ns.layout with a "layout." prefix, joined by dots: "group.nameFontSize",
-- "layout.group". List entries are "*" ("units.frames.*.width"); a key with
-- the index itself wins over the "*" one. Fields:
--   section   section key of the module page (Pages.lua), inherited by children
--   control   switch | slider | stepper | segmented | select | color | text | list
--             | flags (a table of booleans as chips) | position (a Layout.lua point)
--   min, max, step, unit ("px", "%", "s"), percent (0-1 shown as %)
--   options   { { value, { english, german } } } for segmented and select
--   advanced  only under "Advanced", inherited by children
--   live      takes effect at once; everything else after a reload
--   hidden    never shown (the window draws it elsewhere, or it must not change)

local Overrides = ns.Overrides

local Meta = {}
ns.SettingsMeta = Meta

local M = {}
ns.ConfigMeta = M

-- Builders -------------------------------------------------------------------

local function Slider(section, min, max, step, unit)
	return { section = section, control = "slider", min = min, max = max, step = step or 1, unit = unit }
end

local function Percent(section, min, max, step)
	return { section = section, control = "slider", min = min or 0, max = max or 1, step = step or 0.01, percent = true }
end

local function Stepper(section, min, max, step, unit)
	return { section = section, control = "stepper", min = min, max = max, step = step or 1, unit = unit }
end

local function Switch(section)
	return { section = section, control = "switch" }
end

local function Color(section)
	return { section = section, control = "color" }
end

local function In(section)
	return { section = section }
end

local ADVANCED = { advanced = true }

-- Anchor points of Layout.lua positions with readable names.
Meta.ANCHORS = {
	{ "TOPLEFT", { "Top left", "Oben links" } },
	{ "TOP", { "Top centre", "Oben Mitte" } },
	{ "TOPRIGHT", { "Top right", "Oben rechts" } },
	{ "LEFT", { "Left centre", "Links Mitte" } },
	{ "CENTER", { "Centre", "Mitte" } },
	{ "RIGHT", { "Right centre", "Rechts Mitte" } },
	{ "BOTTOMLEFT", { "Bottom left", "Unten links" } },
	{ "BOTTOM", { "Bottom centre", "Unten Mitte" } },
	{ "BOTTOMRIGHT", { "Bottom right", "Unten rechts" } },
}

local QUALITIES = {
	{ 0, { "Poor", "Schlecht" } },
	{ 1, { "Common", "Gewöhnlich" } },
	{ 2, { "Uncommon", "Selten" } },
	{ 3, { "Rare", "Rar" } },
	{ 4, { "Epic", "Episch" } },
}

-- Unit frames -------------------------------------------------------------------

M["units.frames"] = In("frames")
M["units.frames.*.unit"] = ADVANCED
M["units.frames.*.width"] = Slider("frames", 60, 400, 2, "px")
M["units.frames.*.healthHeight"] = Slider("frames", 4, 40, 1, "px")
M["units.frames.*.powerHeight"] = Slider("frames", 0, 20, 1, "px")
M["units.frames.*.healthTextSize"] = Slider("frames", 6, 20, 1, "px")
M["units.frames.*.showName"] = Switch("frames")
M["units.frames.*.showCombat"] = Switch("frames")
M["units.frames.*.gap"] = { advanced = true, control = "slider", min = 0, max = 60, step = 1, unit = "px" }
M["units.frames.*.anchorTo"] = ADVANCED
M["units.frames.*.align"] = {
	advanced = true,
	control = "segmented",
	options = { { "LEFT", { "Left", "Links" } }, { "RIGHT", { "Right", "Rechts" } } },
}
M["units.combatIconSize"] = Slider("frames", 8, 32, 1, "px")
M["units.pollInterval"] = ADVANCED
M["units.castBar"] = In("castBar")
M["units.castBar.height"] = Slider("castBar", 6, 30, 1, "px")
M["units.castBar.fontSize"] = Slider("castBar", 6, 20, 1, "px")
M["units.castBar.gap"] = Slider("castBar", 0, 24, 1, "px")
M["units.castBar.focusHeight"] = Slider("castBar", 4, 24, 1, "px")
M["units.castBar.focusFontSize"] = Slider("castBar", 6, 16, 1, "px")
M["units.classPower"] = In("classPower")
M["units.classPower.height"] = Slider("classPower", 2, 12, 1, "px")
M["units.classPower.gap"] = Slider("classPower", 0, 20, 1, "px")
M["units.classPower.spacing"] = Slider("classPower", 0, 10, 1, "px")
M["units.classPower.max"] = ADVANCED
M["units.targetAuras"] = In("targetAuras")
M["units.targetAuras.max"] = Stepper("targetAuras", 1, 16)
M["units.targetAuras.size"] = Slider("targetAuras", 10, 40, 1, "px")
M["units.targetAuras.spacing"] = Slider("targetAuras", 0, 10, 1, "px")
M["units.targetAuras.filter"] = ADVANCED

-- Group grid -----------------------------------------------------------------------

M["group.nameFontSize"] = Slider("layout", 8, 16, 1, "px")
M["group.powerHeight"] = Slider("layout", 0, 8, 1, "px")
M["group.spacing"] = Slider("layout", 0, 10, 1, "px")
M["group.rowsUpToGroup"] = Stepper("layout", 1, 8)
M["group.roleIconSize"] = Slider("layout", 6, 20, 1, "px")
M["group.debuffsMax"] = {
	section = "auras",
	control = "segmented",
	options = { { 1, { "1", "1" } }, { 2, { "2", "2" } }, { 3, { "3", "3" } }, { 4, { "4", "4" } } },
}
M["group.iconSize"] = Slider("auras", 8, 24, 1, "px")
M["group.ownAuraSize"] = Slider("auras", 6, 16, 1, "px")
M["group.ownAurasMax"] = Stepper("auras", 0, 8)
M["group.dispelColor"] = Color("colors")
M["group.aggroColor"] = Color("colors")
M["group.targetColor"] = Color("colors")
M["group.myHealColor"] = Color("colors")
M["group.otherHealColor"] = Color("colors")
M["group.absorbColor"] = Color("colors")
M["group.deadTrackColor"] = Color("colors")
M["group.outOfRangeAlpha"] = Percent("visibility", 0.1, 1, 0.01)
M["group.darkNameColor"] = ADVANCED
M["group.darkNameLuminance"] = ADVANCED
M["group.dispellableFilter"] = ADVANCED
M["group.otherFilter"] = ADVANCED
M["group.ownAuraFilter"] = ADVANCED

-- Keyboard healing -----------------------------------------------------------------

M["keyboardHealing.cursorColor"] = Color("cursor")
M["keyboardHealing.cursorSize"] = Slider("cursor", 1, 8, 1, "px")
M["keyboardHealing.idleCursorColor"] = Color("cursor")
M["keyboardHealing.idleCursorSize"] = Slider("cursor", 1, 8, 1, "px")
-- The keys are shown (locked) on the keybindings page.
M["keyboardHealing.keys"] = ADVANCED

-- Mark toolbar ---------------------------------------------------------------------

M["marks.buttonSize"] = Slider("bar", 16, 40, 1, "px")
M["marks.buttonGap"] = Slider("bar", 0, 10, 1, "px")
M["marks.padding"] = Slider("bar", 0, 16, 1, "px")
M["marks.unusableAlpha"] = Percent("bar", 0.1, 1, 0.01)

-- Tooltip --------------------------------------------------------------------------

M["tooltip.gapAboveMinimap"] = Slider("tooltip", 0, 40, 1, "px")
M["tooltip.themedBackdrop"] = Switch("tooltip")
M["tooltip.unitFrames"] = Switch("tooltip")

-- Action bars ----------------------------------------------------------------------

M["actionBars.iconSize"] = Slider("buttons", 50, 200, 10, "%")
M["actionBars.iconPadding"] = Slider("buttons", 0, 10, 1, "px")
M["actionBars.highlightAlpha"] = Percent("buttons", 0, 1, 0.05)
M["actionBars.pushedAlpha"] = Percent("buttons", 0, 1, 0.05)
M["actionBars.iconCrop"] = ADVANCED
M["actionBars.sets"] = { section = "sets", control = "list" }
M["actionBars.sharedBars"] = { section = "sets", control = "list" }
M["actionBars.setButtonWidth"] = ADVANCED
M["actionBars.setButtonHeight"] = ADVANCED
M["actionBars.menubarSize"] = Slider("menu", 70, 200, 5, "%")
M["layout.actionBars.*.bar"] = ADVANCED
M["layout.actionBars.*.vertical"] = ADVANCED

-- Auras ----------------------------------------------------------------------------

M["auras.buffs"] = In("buffs")
M["auras.buffs.iconSize"] = Slider("buffs", 50, 200, 10, "%")
M["auras.buffs.iconsPerRow"] = Slider("buffs", 2, 32, 1)
M["auras.debuffs"] = In("debuffs")
M["auras.debuffs.iconSize"] = Slider("debuffs", 50, 200, 10, "%")
M["auras.debuffs.iconsPerRow"] = Slider("debuffs", 2, 16, 1)

-- Chat -----------------------------------------------------------------------------

M["chat.widthFraction"] = Percent("window", 0.2, 0.6, 0.01)
M["chat.height"] = Slider("window", 120, 800, 10, "px")
M["chat.activeAlpha"] = Percent("window", 0, 1, 0.05)
M["chat.openAlpha"] = Percent("window", 0, 1, 0.05)
M["chat.sidebarWidth"] = Slider("window", 80, 250, 5, "px")
M["chat.historyLimit"] = Stepper("window", 50, 1000, 50)
M["chat.fontSize"] = Slider("text", 10, 24, 1, "px")
M["chat.sidebarFontSize"] = Slider("text", 10, 20, 1, "px")
M["chat.dateFormat"] = { section = "text", control = "text" }
M["chat.scrollStep"] = Stepper("text", 1, 10)
M["chat.autoShowDuration"] = Slider("popup", 0, 30, 1, "s")
M["chat.preview"] = In("popup")
M["chat.preview.enabled"] = Switch("popup")
M["chat.preview.maxRows"] = Stepper("popup", 1, 10)
M["chat.preview.holdTime"] = Slider("popup", 1, 30, 1, "s")
M["chat.preview.fadeOutTime"] = Slider("popup", 0, 5, 0.5, "s")
M["chat.inputGap"] = Slider("input", 0, 24, 1, "px")
M["chat.alertGap"] = Slider("input", 0, 20, 1, "px")
M["chat.main"] = In("main")
M["chat.main.enabled"] = Switch("main")
M["chat.main.channels"] = { section = "main", control = "flags" }
M["chat.main.key"] = ADVANCED
M["chat.main.kind"] = ADVANCED
M["chat.main.chatType"] = ADVANCED
M["chat.cityChannels"] = { section = "main", control = "list" }
M["chat.inputBackgroundColor"] = Color("colors")
M["chat.inputBorderColor"] = Color("colors")
M["chat.dividerColor"] = Color("colors")
M["chat.scrollThumbColor"] = Color("colors")
M["chat.deleteColor"] = Color("colors")
M["chat.buttonBorderColor"] = Color("colors")
M["chat.fadeTime"] = ADVANCED
M["chat.rowHeight"] = ADVANCED
M["chat.headerHeight"] = ADVANCED
M["chat.inputClipGap"] = ADVANCED
M["chat.showBlizzardChat"] = ADVANCED
M["chat.blizzardChatGap"] = ADVANCED
M["chat.editBoxGap"] = ADVANCED
M["chat.alertHeight"] = ADVANCED
M["chat.print"] = ADVANCED
M["chat.events"] = ADVANCED
M["chat.notices"] = ADVANCED
M["chat.kindOrder"] = ADVANCED
M["chat.badge"] = ADVANCED

-- Notch ----------------------------------------------------------------------------

M["notch.extraWidth"] = Slider("island", 0, 200, 2, "px")
M["notch.padding"] = Slider("island", 0, 20, 1, "px")
M["notch.cornerRadius"] = Slider("island", 0, 24, 1, "px")
M["notch.rowHeight"] = Slider("content", 10, 24, 1, "px")
M["notch.rowGap"] = Slider("content", 0, 12, 1, "px")
M["notch.groupGap"] = Slider("content", 0, 24, 1, "px")
M["notch.gridColumns"] = Stepper("content", 1, 5)
M["notch.barHeight"] = Slider("content", 2, 10, 1, "px")
M["notch.restedAlpha"] = Percent("content", 0, 1, 0.05)
M["notch.durabilityWarn"] = Percent("content", 0.05, 1, 0.05)
M["notch.durabilityCritical"] = Percent("content", 0.05, 1, 0.05)
M["notch.minimapButtons"] = Switch("buttons")
M["notch.buttonSize"] = Slider("buttons", 12, 32, 1, "px")
M["notch.buttonGap"] = Slider("buttons", 0, 16, 1, "px")
M["notch.colors"] = In("colors")
M["notch.coinColors"] = ADVANCED
M["notch.coinSize"] = ADVANCED
M["notch.separatorColor"] = ADVANCED
M["notch.barGap"] = ADVANCED
M["notch.gridRowHeight"] = ADVANCED
M["notch.gridRowGap"] = ADVANCED
M["notch.hoverBelow"] = ADVANCED
M["notch.islandMargin"] = ADVANCED
M["notch.hideDelay"] = ADVANCED
M["notch.pollInterval"] = ADVANCED
M["notch.updateInterval"] = ADVANCED
M["notch.buttonScanDelay"] = ADVANCED
M["notch.fallback"] = ADVANCED

-- Notes ------------------------------------------------------------------------------

M["notes.showInTooltip"] = Switch("general")
M["notes.window"] = In("window")
M["notes.window.width"] = Slider("window", 500, 1400, 10, "px")
M["notes.window.height"] = Slider("window", 300, 900, 10, "px")
M["notes.colors"] = ADVANCED

-- Players ------------------------------------------------------------------------------

M["players.keepUnratedDays"] = Slider("database", 7, 365, 1)
M["players.rejoinGrace"] = Slider("database", 0, 900, 30, "s")
M["players.popupAfterGroup"] = Switch("rating")
M["players.popupMaxPlayers"] = Stepper("rating", 2, 40)
M["players.joinReminder"] = Switch("rating")
M["players.showInTooltip"] = Switch("rating")
M["players.lootInTooltip"] = Switch("rating")
M["players.blockedGuilds"] = { section = "marked", control = "list" }
M["players.blockWarnings"] = Switch("marked")
M["players.colors"] = In("colors")
M["players.window"] = ADVANCED

-- Loot rolls -----------------------------------------------------------------------------

M["rolls.replaceBlizzardRolls"] = Switch("behaviour")
M["rolls.topRolls"] = Stepper("behaviour", 0, 10)
M["rolls.holdAfterWinner"] = Slider("behaviour", 0, 60, 1, "s")
M["rolls.passedAlpha"] = Percent("behaviour", 0.1, 1, 0.05)
M["rolls.width"] = Slider("cards", 200, 500, 10, "px")
M["rolls.fontSize"] = Slider("cards", 10, 20, 1, "px")
M["rolls.iconSize"] = Slider("cards", 14, 32, 1, "px")
M["rolls.notchGap"] = Slider("cards", 0, 30, 1, "px")
M["rolls.cardGap"] = Slider("cards", 0, 20, 1, "px")
M["rolls.padding"] = ADVANCED
M["rolls.stripeWidth"] = ADVANCED
M["rolls.timerHeight"] = ADVANCED
M["rolls.slideTime"] = ADVANCED
M["rolls.fadeOutTime"] = ADVANCED
M["rolls.resultTimeout"] = ADVANCED
M["rolls.history"] = ADVANCED

-- Loot ticker ----------------------------------------------------------------------------

M["lootTicker.minQuality"] = { section = "content", control = "select", options = QUALITIES }
M["lootTicker.showMoney"] = Switch("content")
M["lootTicker.showCurrency"] = Switch("content")
M["lootTicker.mergeRepeats"] = Switch("content")
M["lootTicker.maxRows"] = Slider("look", 4, 40, 1)
M["lootTicker.width"] = Slider("look", 200, 500, 10, "px")
M["lootTicker.iconSize"] = Slider("look", 12, 32, 1, "px")
M["lootTicker.fontSize"] = Slider("look", 10, 20, 1, "px")
M["lootTicker.rowGap"] = Slider("look", 0, 10, 1, "px")
M["lootTicker.holdTime"] = Slider("timing", 1, 60, 1, "s")
M["lootTicker.fadeOutTime"] = Slider("timing", 0, 10, 0.5, "s")
M["lootTicker.fadeInTime"] = ADVANCED
M["lootTicker.slideTime"] = ADVANCED

-- Smaller modules ----------------------------------------------------------------------

M["fastLoot.revealDelay"] = Slider("general", 0.1, 2, 0.1, "s")
M["questRewards.coinSize"] = Slider("general", 8, 32, 1, "px")
M["minimap.sizeScale"] = Percent("map", 0.4, 1, 0.05)
M["minimap.gapToTarget"] = Slider("map", 0, 60, 1, "px")
M["minimap.iconScale"] = Percent("map", 0.5, 1.5, 0.05)
M["minimap.showZone"] = Switch("header")
M["minimap.showClock"] = Switch("header")
M["minimap.headerHeight"] = ADVANCED
M["minimap.vehicleLeaveGap"] = ADVANCED
M["tracker.height"] = Slider("tracker", 400, 1000, 10, "px")
M["tracker.shownOnLogin"] = Switch("tracker")
M["taxi.width"] = Slider("list", 150, 400, 5, "px")
M["taxi.rowHeight"] = Slider("list", 12, 30, 1, "px")
M["taxi.padding"] = Slider("list", 0, 16, 1, "px")
M["settings.consoleKey"] = { section = "general", control = "text" }
M["settings.ignoredCVars"] = ADVANCED
-- The switch on the graphics page; it is applied at once.
M["settings.mirrorRaidCVars"] = { hidden = true, live = true }

-- Style ----------------------------------------------------------------------------------

-- The theme is picked with the cards at the top of the page.
M["style.theme"] = { hidden = true }
M["style.themes"] = In("colors")
M["style.fontSize"] = Slider("text", 8, 16, 1, "px")
M["style.textShadow"] = Switch("text")
M["style.font"] = ADVANCED
M["style.fontFlags"] = ADVANCED
M["style.texture"] = ADVANCED
M["style.borderColor"] = Color("states")
M["style.deadColor"] = Color("states")
M["style.offlineColor"] = Color("states")
M["style.tappedColor"] = Color("states")
M["style.fallbackHealthColor"] = Color("states")
M["style.badge"] = In("badge")
M["style.badge.width"] = Slider("badge", 1, 10, 1, "px")
M["style.badge.height"] = Slider("badge", 16, 120, 2, "px")
M["style.badge.hiddenColor"] = Color("badge")
M["style.badge.shownColor"] = Color("badge")
M["style.badge.glowWidth"] = ADVANCED

-- Lookup -----------------------------------------------------------------------------------

-- "group.nameFontSize" for { "config", "group", "nameFontSize" }; `wildcard`
-- puts "*" for list indices.
function Meta.Key(path, wildcard)
	local parts = {}
	for i = path[1] == "config" and 2 or 1, #path do
		local key = path[i]
		if type(key) == "number" then
			parts[#parts + 1] = wildcard and "*" or tostring(key)
		else
			parts[#parts + 1] = key
		end
	end
	return table.concat(parts, ".")
end

local EMPTY = {}

-- The metadata of `path` (an empty table when there is none).
function Meta.Lookup(path)
	return M[Meta.Key(path)] or M[Meta.Key(path, true)] or EMPTY
end

-- A table of point, x and y: a Layout.lua position.
local function IsPosition(value)
	return type(value) == "table"
		and type(value.point) == "string"
		and type(value.x) == "number"
		and type(value.y) == "number"
end
Meta.IsPosition = IsPosition

-- The control for a value without metadata.
function Meta.Derive(key, value)
	local kind = type(value)
	if kind == "boolean" then
		return "switch"
	elseif kind == "number" then
		return "stepper"
	elseif kind == "string" then
		return "text"
	elseif kind ~= "table" then
		return "text"
	elseif ns.EditorModel.IsColor(key, value) then
		return "color"
	elseif IsPosition(value) then
		return "position"
	elseif Overrides.IsList(value) then
		for _, entry in ipairs(value) do
			if type(entry) == "table" then
				return "entries"
			end
		end
		return "list"
	end
	return "group"
end

-- Label and help of a path: a path-specific entry in Labels.lua first, then
-- the key's own.
-- The colors of both themes share their texts ("style.themes.*.panel").
function Meta.Text(path)
	local wildcard = Meta.Key(path, true)
	if path[2] == "style" and path[3] == "themes" and #path == 5 then
		wildcard = "style.themes.*." .. path[5]
	end
	return ns.ConfigPathLabel(Meta.Key(path), wildcard, path[#path])
end

-- Items ------------------------------------------------------------------------------------

-- The label of list entry `index`: "Frames 2 · target" when the entry names a
-- unit, bar or category.
local function EntryLabel(listLabel, index, entry)
	local name = type(entry) == "table" and (entry.unit or entry.bar or entry.category)
	if type(name) == "string" then
		return ("%s %d · %s"):format(listLabel, index, name)
	end
	return ("%s %d"):format(listLabel, index)
end

local function JoinGroup(group, label)
	if group then
		return group .. " › " .. label
	end
	return label
end

local Visit

local function VisitChildren(items, path, value, ctx)
	for _, childKey in ipairs(ns.EditorModel.SortedKeys(value)) do
		Visit(items, Overrides.Child(path, childKey), value[childKey], ctx)
	end
end

-- Adds the items below `path` to `items`. ctx: section, advanced, group (the
-- labels of the tables in between) and label (an entry's own label).
function Visit(items, path, value, ctx, label)
	local encoded = Overrides.Encode(path)
	local meta = Meta.Lookup(path)
	if ns.EditorModel.HIDDEN[encoded] or meta.hidden then
		return
	end
	local key = path[#path]
	local ownLabel, help = Meta.Text(path)
	label = label or ownLabel
	local control = meta.control or Meta.Derive(key, value)
	local section = meta.section or ctx.section
	local advanced = meta.advanced or ctx.advanced or false

	if control == "group" then
		-- A table with a section of its own is that section; its title names it.
		local group = ctx.group
		if not meta.section then
			group = JoinGroup(group, label)
		end
		VisitChildren(items, path, value, { section = section, advanced = advanced, group = group })
		return
	elseif control == "entries" then
		for index, entry in ipairs(value) do
			Visit(
				items,
				Overrides.Child(path, index),
				entry,
				{ section = section, advanced = advanced, group = ctx.group },
				EntryLabel(label, index, entry)
			)
		end
		return
	end

	items[#items + 1] = {
		path = path,
		encoded = encoded,
		metaKey = Meta.Key(path),
		key = key,
		meta = meta,
		control = control,
		section = section,
		advanced = advanced,
		group = ctx.group,
		label = label,
		help = help,
	}

	if control == "position" then
		-- Everything but the point and offsets (bar names, relative points)
		-- is technical.
		for _, childKey in ipairs(ns.EditorModel.SortedKeys(value)) do
			if childKey ~= "point" and childKey ~= "x" and childKey ~= "y" then
				Visit(
					items,
					Overrides.Child(path, childKey),
					value[childKey],
					{ section = section, advanced = true, group = JoinGroup(ctx.group, label) }
				)
			end
		end
	end
end

-- The settings of a module page in display order: its config (without
-- `enabled`, the page's header switch), then its Layout.lua positions.
-- `module` is an entry of Pages.MODULES or Pages.STYLE; `roots` holds config
-- and layout. On the style page only the active theme's colors show.
function Meta.Items(roots, module)
	local items = {}
	local name = module[1]
	local config = roots.config[name]
	local default = module.sections[1] and module.sections[1].key
	if config then
		for _, key in ipairs(ns.EditorModel.SortedKeys(config)) do
			if key ~= "enabled" then
				local path = { "config", name, key }
				if name == "style" and key == "themes" then
					local theme = config.themes[config.theme] and config.theme or "dusk"
					local themePath = Overrides.Child(path, theme)
					VisitChildren(items, themePath, config.themes[theme], { section = "colors" })
				else
					Visit(items, path, config[key], { section = default })
				end
			end
		end
	end
	for _, key in ipairs(module.layout or {}) do
		if roots.layout[key] ~= nil then
			Visit(items, { "layout", key }, roots.layout[key], { section = "position" })
		end
	end
	return items
end

-- Whether the live value of `item` differs from the code's default. A
-- position compares only what its control edits.
function Meta.IsChanged(item, roots, defaults)
	local live, default = Overrides.Get(roots, item.path), Overrides.Get(defaults, item.path)
	if item.control == "position" and type(live) == "table" and type(default) == "table" then
		return live.point ~= default.point or live.x ~= default.x or live.y ~= default.y
	end
	return not Overrides.Equal(live, default)
end

-- How many of `items` differ from the default.
function Meta.ChangedCount(items, roots, defaults)
	local count = 0
	for _, item in ipairs(items) do
		if Meta.IsChanged(item, roots, defaults) then
			count = count + 1
		end
	end
	return count
end

-- Values --------------------------------------------------------------------------------

local function Round(value, step)
	step = step or 1
	return math.floor(value / step + 0.5) * step
end

local function Number(value)
	if value == math.floor(value) then
		return tostring(value)
	end
	-- At most two decimals, without trailing zeros.
	return (("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", ""))
end
Meta.Number = Number

-- The name of `value` in `options`, or nil.
function Meta.OptionLabel(options, value)
	for _, option in ipairs(options or {}) do
		if option[1] == value then
			return ns.T(option[2][1], option[2][2])
		end
	end
end

function Meta.AnchorLabel(point)
	return Meta.OptionLabel(Meta.ANCHORS, point) or point
end

-- "#RRGGBB", with " · 35 %" for a color that is see-through.
function Meta.ColorText(color)
	local function Byte(component)
		return math.floor(component * 255 + 0.5)
	end
	local text = ("#%02X%02X%02X"):format(Byte(color[1]), Byte(color[2]), Byte(color[3]))
	if color[4] and color[4] < 1 then
		text = ("%s · %d %%"):format(text, Round(color[4] * 100))
	end
	return text
end

-- A value as the window writes it: "38 %", "12 px", "on", "#3D8CFF".
function Meta.FormatValue(value, meta, control)
	meta = meta or EMPTY
	local kind = type(value)
	if kind == "boolean" then
		return value and ns.T("on", "an") or ns.T("off", "aus")
	elseif kind == "number" then
		local label = Meta.OptionLabel(meta.options, value)
		if label then
			return label
		elseif meta.percent then
			return ("%d %%"):format(Round(value * 100))
		elseif meta.unit then
			return ("%s %s"):format(Number(value), meta.unit)
		end
		return Number(value)
	elseif kind == "string" then
		return Meta.OptionLabel(meta.options, value) or value
	elseif kind ~= "table" then
		return tostring(value)
	elseif control == "color" or (control == nil and ns.EditorModel.IsColor("value", value)) then
		return Meta.ColorText(value)
	elseif IsPosition(value) then
		return ("%s %s, %s"):format(Meta.AnchorLabel(value.point), Number(value.x), Number(value.y))
	elseif Overrides.IsList(value) then
		local parts = {}
		for index, entry in ipairs(value) do
			parts[index] = type(entry) == "table" and "…" or tostring(entry)
		end
		return #parts > 0 and table.concat(parts, ", ") or "–"
	end
	-- A table of switches (flags): the names of those that are on.
	local on = {}
	for _, key in ipairs(ns.EditorModel.SortedKeys(value)) do
		if value[key] == true then
			on[#on + 1] = (ns.ConfigLabel(key))
		end
	end
	return #on > 0 and table.concat(on, ", ") or "–"
end

-- A number from the slider or input clamped to the range and snapped to the step.
function Meta.Clamp(value, meta)
	if meta.min then
		value = math.max(meta.min, value)
	end
	if meta.max then
		value = math.min(meta.max, value)
	end
	if meta.step then
		value = Round(value - (meta.min or 0), meta.step) + (meta.min or 0)
		-- Steps like 0.05 leave float noise behind.
		value = tonumber(("%.4f"):format(value))
	end
	return value
end

-- Checks ------------------------------------------------------------------------------

-- Metadata keys that match no value below `roots` (config and layout), sorted:
-- left behind when a config key was renamed or removed.
function Meta.UnknownKeys(roots)
	local known = {}
	local function Walk(path, value)
		known[Meta.Key(path)] = true
		known[Meta.Key(path, true)] = true
		if type(value) == "table" then
			for key, child in pairs(value) do
				Walk(Overrides.Child(path, key), child)
			end
		end
	end
	for key, value in pairs(roots.config) do
		Walk({ "config", key }, value)
	end
	for key, value in pairs(roots.layout) do
		Walk({ "layout", key }, value)
	end
	local unknown = {}
	for key in pairs(M) do
		if not known[key] then
			unknown[#unknown + 1] = key
		end
	end
	table.sort(unknown)
	return unknown
end
