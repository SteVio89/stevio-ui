local _, ns = ...

-- The pages of the settings window (Window.lua): the modules with their
-- category, a one-sentence description and their sections, in sidebar
-- order. Kept free of WoW API calls so it can be tested outside the game.

local Pages = {}
ns.ConfigPages = Pages

-- Sidebar groups of the module pages, in order. "system" holds the
-- profile's own pages (keybindings, graphics, profile & backup).
Pages.CATEGORIES = {
	{ key = "combat", title = { "Combat & units", "Kampf & Einheiten" } },
	{ key = "bars", title = { "Bars & auras", "Leisten & Auren" } },
	{ key = "social", title = { "Communication", "Kommunikation" } },
	{ key = "loot", title = { "Loot", "Beute" } },
	{ key = "map", title = { "Map & travel", "Karte & Reisen" } },
	{ key = "system", title = { "System", "System" } },
}

-- Every module page ends with these two (Meta.lua puts Layout.lua positions
-- into "position" and everything marked advanced into "advanced").
local POSITION = { key = "position", title = { "Position", "Position" } }

local function S(key, en, de, subEn, subDe)
	return { key = key, title = { en, de }, subtitle = subEn and { subEn, subDe } or nil }
end

-- Module pages in sidebar order: config key, category, description, the
-- sections in page order and the Layout.lua positions the module places.
-- The title is the module's config label (Labels.lua) unless `title` names
-- one. `tests` are buttons that try the module in the game (slash commands),
-- `preview` names a live preview beside the page (PageModule.lua).
Pages.MODULES = {
	{
		"units",
		category = "combat",
		description = {
			"Player, target, focus, pet and target of target, with cast bars.",
			"Spieler, Ziel, Fokus, Begleiter und Ziel des Ziels, mit Zauberleisten.",
		},
		sections = {
			S("frames", "Frames", "Fenster", "Size of each unit frame", "Größe jedes Einheitenfensters"),
			S("castBar", "Cast bar", "Zauberleiste", "Spell name left, time right", "Zaubername links, Zeit rechts"),
			S("classPower", "Combo points", "Combopunkte", "Segments under the player", "Segmente unter dem Spieler"),
			S(
				"targetAuras",
				"Own debuffs on the target",
				"Eigene Debuffs am Ziel",
				"Your DoTs in a row above the target",
				"Deine DoTs in einer Reihe über dem Ziel"
			),
			POSITION,
		},
		layout = { "player", "target", "focus", "targetAuras" },
	},
	{
		"group",
		-- Labels.group is "Group", which is too vague for a page of its own.
		title = { "Group grid", "Gruppenraster" },
		category = "combat",
		description = {
			"Group and raid of up to 40 players in one grid above the action bars. Up to group 5 the groups stack as rows; larger raids get one column per group.",
			"Gruppe und Schlachtzug bis 40 Spieler in einem Raster über den Aktionsleisten. Bis Gruppe 5 stapeln sich die Gruppen als Reihen, bei größeren Schlachtzügen bekommt jede Gruppe eine Spalte.",
		},
		sections = {
			S(
				"layout",
				"Layout",
				"Aufbau",
				"Sizes within a cell (80 × 50)",
				"Größen innerhalb einer Zelle (80 × 50)"
			),
			S(
				"auras",
				"Auras",
				"Auren",
				"Debuffs right, own HoTs bottom left",
				"Debuffs rechts, eigene HoTs unten links"
			),
			S(
				"colors",
				"Colours",
				"Farben",
				"Click a swatch to pick a colour",
				"Klick auf ein Feld öffnet die Farbauswahl"
			),
			S("visibility", "Visibility", "Sichtbarkeit"),
			POSITION,
		},
		layout = { "group" },
		preview = "group",
		tests = {
			title = {
				"Fills the grid with test players, also without a group.",
				"Füllt das Raster mit Testspielern, auch ohne Gruppe.",
			},
			{ "5", "test 5" },
			{ "10", "test 10" },
			{ "25", "test 25" },
			{ "40", "test 40" },
			{ { "Off", "Aus" }, "test" },
		},
	},
	{
		"keyboardHealing",
		category = "combat",
		description = {
			"The arrow keys move through the grid; spells work as usual.",
			"Mit den Pfeiltasten durchs Raster; Zauber wirken wie gewohnt.",
		},
		sections = {
			S("cursor", "Cursor", "Cursor", "The frame around the chosen cell", "Der Rahmen um die gewählte Zelle"),
		},
	},
	{
		"marks",
		category = "combat",
		description = {
			"Target markers with one click, above the minimap.",
			"Zielmarkierungen mit einem Klick, über der Minikarte.",
		},
		sections = { S("bar", "Toolbar", "Leiste"), POSITION },
		layout = { "marks" },
	},
	{
		"tooltip",
		category = "combat",
		description = {
			"A fixed tooltip position next to the minimap.",
			"Feste Tooltip-Position neben der Minikarte.",
		},
		sections = { S("tooltip", "Tooltip", "Tooltip") },
	},
	{
		"actionBars",
		category = "bars",
		description = {
			"Bars, action sets, stances, menu and bags.",
			"Leisten, Aktions-Sets, Haltungen, Menü und Taschen.",
		},
		sections = {
			S("buttons", "Buttons", "Knöpfe", "Look of every action button", "Aussehen aller Aktionsknöpfe"),
			S(
				"sets",
				"Action sets",
				"Aktions-Sets",
				"Switchable sets for the same bars",
				"Umschaltbare Belegungen derselben Leisten"
			),
			S("menu", "Menu & bags", "Menü & Taschen"),
			POSITION,
		},
		layout = { "actionBars", "actionSets", "stanceBar", "petBar", "menubar", "bags" },
	},
	{
		"auras",
		category = "bars",
		description = {
			"Buffs and debuffs, compact at the top right.",
			"Buffs und Debuffs kompakt oben rechts.",
		},
		sections = {
			S("buffs", "Buffs", "Buffs"),
			S("debuffs", "Debuffs", "Debuffs"),
			POSITION,
		},
		layout = { "buffs", "debuffs" },
	},
	{
		"chat",
		category = "social",
		description = {
			"A chat window of its own with a channel list and an edge badge.",
			"Eigenes Chatfenster mit Kanalliste und Randmarke.",
		},
		sections = {
			S(
				"window",
				"Window",
				"Fenster",
				"Size and see-through background",
				"Größe und durchscheinender Hintergrund"
			),
			S("text", "Text", "Schrift"),
			S(
				"popup",
				"Pop-up & preview",
				"Einblenden & Vorschau",
				"While the chat is hidden",
				"Solange der Chat versteckt ist"
			),
			S(
				"input",
				"Input",
				"Eingabe",
				"The input line and what sits below it",
				"Die Eingabezeile und was darunter sitzt"
			),
			S(
				"main",
				"Main channel",
				"Hauptkanal",
				"Several channels read in one place",
				"Mehrere Kanäle an einer Stelle lesen"
			),
			S("colors", "Colours", "Farben"),
			POSITION,
		},
		layout = { "chat", "chatBadge" },
	},
	{
		"notch",
		category = "social",
		description = {
			"Info that grows out of the notch while the mouse is at the top of the screen.",
			"Infos, die aus der Notch wachsen, wenn die Maus oben ist.",
		},
		sections = {
			S("island", "Island", "Insel", "Size and shape", "Größe und Form"),
			S("content", "Content", "Inhalt", "Rows, bars and the value grid", "Zeilen, Balken und das Werteraster"),
			S("buttons", "Buttons", "Knöpfe", "Minimap buttons of other addons", "Minikarten-Knöpfe anderer Addons"),
			S("colors", "Colours", "Farben"),
		},
	},
	{
		"notes",
		category = "social",
		description = {
			"Notes on items and in general, by Alt+right-click.",
			"Notizen zu Gegenständen und allgemein, per Alt+Rechtsklick.",
		},
		sections = { S("general", "Notes", "Notizen"), S("window", "Window", "Fenster") },
	},
	{
		"players",
		category = "social",
		description = {
			"A database of the players you grouped with: ratings and rolls.",
			"Datenbank deiner Mitspieler mit Bewertungen und Würfen.",
		},
		sections = {
			S("database", "Database", "Datenbank", "What is kept and for how long", "Was wie lange aufbewahrt wird"),
			S("rating", "Rating & reminders", "Bewertung & Hinweise"),
			S("marked", "Marked players", "Markierte Spieler"),
			S("colors", "Colours", "Farben"),
		},
	},
	{
		"rolls",
		category = "loot",
		description = {
			"Roll cards instead of Blizzard's popup, with a history.",
			"Würfelkarten statt Blizzard-Popup, mit Verlauf.",
		},
		sections = {
			S("behaviour", "Behaviour", "Verhalten"),
			S("cards", "Cards", "Karten", "Below the notch, newest on top", "Unter der Notch, neueste oben"),
		},
		tests = {
			title = { "Shows sample roll cards.", "Zeigt Beispiel-Würfelkarten." },
			{ { "Simulate a roll", "Wurf simulieren" }, "roll" },
			{ { "Preview", "Vorschau" }, "rolls" },
		},
	},
	{
		"lootTicker",
		category = "loot",
		description = {
			"Your own loot, gold and currencies as a short list.",
			"Eigene Beute, Gold und Währungen als kurze Liste.",
		},
		sections = {
			S("content", "What is shown", "Was gezeigt wird"),
			S("look", "Look", "Aussehen"),
			S("timing", "Timing", "Zeiten", "How long a line stays", "Wie lange eine Zeile bleibt"),
			POSITION,
		},
		layout = { "lootTicker" },
		tests = {
			title = { "Shows sample loot lines.", "Zeigt Beispiel-Beutezeilen." },
			{ { "Preview", "Vorschau" }, "loot" },
		},
	},
	{
		"fastLoot",
		category = "loot",
		description = {
			"Picks everything up at once, without a loot window.",
			"Alles auf einmal einsammeln, ohne Beutefenster.",
		},
		sections = { S("general", "Fast loot", "Schnelles Plündern") },
	},
	{
		"questRewards",
		category = "loot",
		description = {
			"Helps choosing the quest reward.",
			"Hilft bei der Wahl der Questbelohnung.",
		},
		sections = { S("general", "Quest rewards", "Questbelohnungen") },
	},
	{
		"minimap",
		category = "map",
		description = {
			"A square map without a frame, with zone and clock.",
			"Eckige Karte ohne Rahmen, Zone und Uhr daran.",
		},
		sections = {
			S("map", "Map", "Karte"),
			S("header", "Header", "Kopfzeile", "Zone and clock along the top edge", "Zone und Uhr an der Oberkante"),
			POSITION,
		},
		layout = { "minimap" },
	},
	{
		"tracker",
		category = "map",
		description = {
			"The quest list on the right, shown and hidden from the edge badge.",
			"Questliste rechts, ein- und ausklappbar über die Randmarke.",
		},
		sections = { S("tracker", "Quest list", "Questliste"), POSITION },
		layout = { "tracker", "trackerBadge" },
	},
	{
		"taxi",
		category = "map",
		description = {
			"Reachable destinations as a list next to the flight map.",
			"Erreichbare Ziele als Liste neben der Flugkarte.",
		},
		sections = { S("list", "List", "Liste") },
	},
	{
		"settings",
		category = "system",
		description = {
			"The profile: keybindings, game settings and action bars from the code.",
			"Das Profil: Tastenbelegung, Spieleinstellungen und Aktionsleisten aus dem Code.",
		},
		sections = { S("general", "Other settings", "Weitere Einstellungen") },
	},
}

-- The style page ("Darstellung"); its theme cards are drawn by PageModule.lua.
Pages.STYLE = {
	"style",
	title = { "Appearance", "Darstellung" },
	description = {
		"Colours, text and edge badges of every element.",
		"Farben, Schrift und Randmarken aller Elemente.",
	},
	sections = {
		S("colors", "Theme colours", "Farben des Themes", "Only for the active theme", "Nur für das aktive Theme"),
		S("text", "Text", "Schrift"),
		S("states", "Unit states", "Einheitenzustände", "Health bar colours", "Farben der Lebensbalken"),
		S("badge", "Edge badges", "Randmarken", "Toggles at the screen edge", "Schalter am Bildschirmrand"),
	},
}

local byKey = {}
for _, module in ipairs(Pages.MODULES) do
	byKey[module[1]] = module
end
byKey.style = Pages.STYLE

function Pages.Module(key)
	return byKey[key]
end

function Pages.Title(module)
	if module.title then
		return ns.T(module.title[1], module.title[2])
	end
	return (ns.ConfigLabel(module[1]))
end

function Pages.Description(module)
	return ns.T(module.description[1], module.description[2])
end

function Pages.CategoryTitle(key)
	for _, category in ipairs(Pages.CATEGORIES) do
		if category.key == key then
			return ns.T(category.title[1], category.title[2])
		end
	end
	return key
end

-- The modules of a category, in sidebar order.
function Pages.InCategory(key)
	local list = {}
	for _, module in ipairs(Pages.MODULES) do
		if module.category == key then
			list[#list + 1] = module
		end
	end
	return list
end

-- The section `key` of a module, or nil.
function Pages.Section(module, key)
	for _, section in ipairs(module.sections) do
		if section.key == key then
			return section
		end
	end
end

-- The module page a saved value belongs to: "config/<module>/..." or a
-- Layout.lua position one of them places. Nil for none.
function Pages.ModuleForPath(encoded)
	local root, first = encoded:match("^(%a+)/([^/]+)")
	if root == "config" then
		return byKey[first] and first or nil
	elseif root == "layout" then
		for _, module in ipairs(Pages.MODULES) do
			for _, key in ipairs(module.layout or {}) do
				if key == first then
					return module[1]
				end
			end
		end
	end
end

-- Layout.lua positions no module page shows. A safety net for future layout
-- keys: today every position has a page.
function Pages.UnclaimedLayout(layout)
	local claimed = {}
	for _, module in ipairs(Pages.MODULES) do
		for _, key in ipairs(module.layout or {}) do
			claimed[key] = true
		end
	end
	local keys = {}
	for key in pairs(layout) do
		if not claimed[key] then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end
