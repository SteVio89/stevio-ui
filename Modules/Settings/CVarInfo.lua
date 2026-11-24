local _, ns = ...

-- What the "Graphics & game" page knows about the CVars of the profile: a
-- readable name, an explanation, a group and a control (switch for "0"/"1",
-- select with named levels, slider with a range). CVars without an entry show
-- under "Other" with their technical name. Also the raid variants ("RAIDfarclip"
-- for "farclip"), which follow their base CVar unless that is switched off.
-- Kept free of WoW API calls so it can be tested outside the game
-- (tests/settings_cvars_test.lua).

local Info = {}
ns.CVarInfo = Info

Info.GROUPS = {
	{
		key = "graphics",
		title = { "Graphics", "Grafik" },
		subtitle = { "World and surroundings", "Welt und Umgebung" },
	},
	{
		key = "game",
		title = { "Game & controls", "Spiel & Bedienung" },
		subtitle = { "How the game feels", "wie sich das Spiel anfühlt" },
	},
	{ key = "accessibility", title = { "Accessibility & hints", "Barrierefreiheit & Hinweise" } },
	{ key = "other", title = { "Other", "Weitere" }, subtitle = { "Without a description", "Ohne Beschreibung" } },
	{
		key = "raid",
		title = { "Raid", "Schlachtzug" },
		subtitle = { "Own values in raids", "Eigene Werte im Schlachtzug" },
	},
}

local function Levels(count, first)
	local options = {}
	for value = 0, count do
		local label = { ("Level %d"):format(value), ("Stufe %d"):format(value) }
		if value == 0 and first then
			label = first
		end
		options[#options + 1] = { tostring(value), label }
	end
	return options
end

local OFF = { "Off", "Aus" }

local function Switch(group, en, de, helpEn, helpDe)
	return { group = group, name = { en, de }, help = { helpEn, helpDe }, control = "switch" }
end

local function Select(group, en, de, helpEn, helpDe, options)
	return { group = group, name = { en, de }, help = { helpEn, helpDe }, control = "select", options = options }
end

local function Slider(group, en, de, helpEn, helpDe, min, max, step, extra)
	local info = {
		group = group,
		name = { en, de },
		help = { helpEn, helpDe },
		control = "slider",
		min = min,
		max = max,
		step = step,
	}
	for key, value in pairs(extra or {}) do
		info[key] = value
	end
	return info
end

-- A number without a known range: typed in.
local function Value(group, en, de, helpEn, helpDe)
	return { group = group, name = { en, de }, help = { helpEn, helpDe }, control = "text" }
end

Info.CVARS = {
	-- Graphics
	farclip = Slider(
		"graphics",
		"View distance",
		"Sichtweite",
		"How far the world is drawn. Less helps weaker computers.",
		"Wie weit die Welt gezeichnet wird. Weniger hilft auf schwächeren Rechnern.",
		1000,
		10000,
		100
	),
	horizonClip = Value(
		"graphics",
		"Horizon distance",
		"Horizontweite",
		"Up to where the distant horizon is drawn.",
		"Bis wohin der ferne Horizont gezeichnet wird."
	),
	horizonStart = Value(
		"graphics",
		"Horizon start",
		"Horizontbeginn",
		"From where the simplified horizon replaces the world.",
		"Ab wo der vereinfachte Horizont die Welt ersetzt."
	),
	shadowMode = Select(
		"graphics",
		"Shadows",
		"Schatten",
		"Quality of the shadows of figures and buildings.",
		"Qualität der Schatten von Figuren und Gebäuden.",
		Levels(4)
	),
	shadowNumCascades = Value(
		"graphics",
		"Shadow cascades",
		"Schattenstufen",
		"How many distance steps the shadows have.",
		"Wie viele Entfernungsstufen die Schatten haben."
	),
	shadowBlendCascades = Switch(
		"graphics",
		"Soft shadow steps",
		"Weiche Schattenstufen",
		"Blends the shadow steps into each other.",
		"Blendet die Schattenstufen ineinander über."
	),
	SSAO = Select(
		"graphics",
		"Ambient occlusion",
		"Umgebungsverdeckung",
		"Soft shadows in corners and gaps (SSAO).",
		"Weiche Schatten in Ecken und Spalten (SSAO).",
		Levels(4, OFF)
	),
	sunShafts = Select(
		"graphics",
		"Sun shafts",
		"Sonnenstrahlen",
		"Rays of light from a low sun.",
		"Lichtstrahlen bei tief stehender Sonne.",
		Levels(2, OFF)
	),
	particleDensity = Slider(
		"graphics",
		"Particle density",
		"Partikeldichte",
		"Amount of spell effects, sparks and smoke.",
		"Menge an Zaubereffekten, Funken und Rauch.",
		10,
		100,
		10,
		{ unit = "%" }
	),
	particleMTDensity = Slider(
		"graphics",
		"Particle detail",
		"Partikeldetails",
		"Detail of particles calculated in parallel.",
		"Detail der parallel berechneten Partikel.",
		10,
		100,
		10,
		{ unit = "%" }
	),
	textureFilteringMode = Select(
		"graphics",
		"Texture filter",
		"Texturfilter",
		"Sharpness of ground textures at a flat angle.",
		"Schärfe von Bodentexturen in flachem Winkel.",
		{
			{ "0", { "Bilinear", "Bilinear" } },
			{ "1", { "Trilinear", "Trilinear" } },
			{ "2", { "2× anisotropic", "2× anisotrop" } },
			{ "3", { "4× anisotropic", "4× anisotrop" } },
			{ "4", { "8× anisotropic", "8× anisotrop" } },
			{ "5", { "16× anisotropic", "16× anisotrop" } },
		}
	),
	groundEffectDensity = Value(
		"graphics",
		"Ground clutter density",
		"Bodendetails Dichte",
		"How much grass and small plants grow.",
		"Wie viel Gras und kleine Pflanzen wachsen."
	),
	groundEffectDist = Value(
		"graphics",
		"Ground clutter distance",
		"Bodendetails Weite",
		"Up to where grass and small plants are drawn.",
		"Bis wohin Gras und kleine Pflanzen gezeichnet werden."
	),
	entityLodDist = Value(
		"graphics",
		"Figure detail distance",
		"Figurendetails Weite",
		"From where figures are drawn simpler.",
		"Ab wo Figuren einfacher gezeichnet werden."
	),
	entityShadowFadeScale = Value(
		"graphics",
		"Figure shadow distance",
		"Figurenschatten Weite",
		"Up to where figures cast shadows.",
		"Bis wohin Figuren Schatten werfen."
	),
	wmoLodDist = Value(
		"graphics",
		"Building detail distance",
		"Gebäudedetails Weite",
		"From where buildings are drawn simpler.",
		"Ab wo Gebäude einfacher gezeichnet werden."
	),
	lodObjectCullSize = Value(
		"graphics",
		"Small object cutoff",
		"Kleine Objekte ausblenden",
		"Objects smaller than this disappear in the distance.",
		"Kleinere Objekte verschwinden in der Ferne."
	),
	lodObjectFadeScale = Value(
		"graphics",
		"Object fade distance",
		"Objekte ausblenden ab",
		"How far away objects fade out.",
		"Wie weit entfernt Objekte ausgeblendet werden."
	),
	lodObjectMinSize = Value(
		"graphics",
		"Smallest object",
		"Kleinstes Objekt",
		"Objects below this size are never drawn.",
		"Objekte unter dieser Größe werden nie gezeichnet."
	),
	TerrainLodDiv = Value(
		"graphics",
		"Terrain detail",
		"Geländedetails",
		"How finely the ground is shaped in the distance.",
		"Wie fein der Boden in der Ferne geformt ist."
	),
	waterDetail = Select(
		"graphics",
		"Water",
		"Wasser",
		"Detail of water surfaces.",
		"Detail von Wasseroberflächen.",
		Levels(3)
	),
	rippleDetail = Select(
		"graphics",
		"Ripples",
		"Wellen",
		"Ripples on water.",
		"Wellen auf dem Wasser.",
		Levels(2, OFF)
	),
	reflectionMode = Select(
		"graphics",
		"Reflections",
		"Spiegelungen",
		"Reflections on water.",
		"Spiegelungen auf dem Wasser.",
		Levels(3, OFF)
	),
	refraction = Switch(
		"graphics",
		"Refraction",
		"Lichtbrechung",
		"Light bending in water and glass.",
		"Lichtbrechung in Wasser und Glas."
	),
	pbrLiquidDetail = Select(
		"graphics",
		"Liquid detail",
		"Flüssigkeiten",
		"Detail of lava, slime and other liquids.",
		"Detail von Lava, Schleim und anderen Flüssigkeiten.",
		Levels(3)
	),
	projectedTextures = Switch(
		"graphics",
		"Projected textures",
		"Projizierte Texturen",
		"Spell effects drawn onto the ground.",
		"Zaubereffekte, die auf den Boden gezeichnet werden."
	),
	volumeFogLevel = Select(
		"graphics",
		"Volumetric fog",
		"Volumennebel",
		"Fog with depth in the air.",
		"Nebel mit Tiefe in der Luft.",
		Levels(3, OFF)
	),
	weatherDensity = Select(
		"graphics",
		"Weather",
		"Wetter",
		"Amount of rain and snow.",
		"Menge an Regen und Schnee.",
		Levels(3, OFF)
	),
	OutlineEngineMode = Switch(
		"graphics",
		"Outlines",
		"Umrisse",
		"Outlines around figures under the mouse and your target.",
		"Umrisse um Figuren unter der Maus und dein Ziel."
	),
	giQuality = Select(
		"graphics",
		"Global illumination",
		"Globale Beleuchtung",
		"Light that bounces off surfaces.",
		"Licht, das von Flächen zurückgeworfen wird.",
		Levels(3, OFF)
	),
	graphicsLightMode = Select(
		"graphics",
		"Lighting",
		"Beleuchtung",
		"Quality of lights in the world.",
		"Qualität der Lichter in der Welt.",
		Levels(2)
	),
	spellClutter = Select(
		"graphics",
		"Spell clutter",
		"Zauber-Gewimmel",
		"How many spell effects of others are shown.",
		"Wie viele Zaubereffekte anderer gezeigt werden.",
		Levels(3)
	),
	spellVisualDensityFilterSetting = Select(
		"graphics",
		"Spell density",
		"Zauberdichte",
		"How dense spell effects get in large fights.",
		"Wie dicht Zaubereffekte in großen Kämpfen werden.",
		Levels(3)
	),

	-- Game & controls
	autoLootDefault = Switch(
		"game",
		"Auto loot",
		"Automatisch plündern",
		"Loot without a click. With the loot key held it is the other way round.",
		"Beute ohne Klick einsammeln. Mit gedrückter Plündern-Taste umgekehrt."
	),
	SoftTargetInteract = Select(
		"game",
		"Interact key",
		"Interaktionstaste",
		"Talk, loot and use with F without aiming. Without this setting F does nothing.",
		"Mit F sprechen, plündern und benutzen, ohne genau zu zielen. Ohne diese Einstellung tut F nichts.",
		{
			{ "0", OFF },
			{ "1", { "Gamepad", "Gamepad" } },
			{ "2", { "Mouse and keyboard", "Maus und Tastatur" } },
			{ "3", { "Always", "Immer" } },
		}
	),
	softTargettingInteractKeySound = Switch(
		"game",
		"Interact sound",
		"Interaktionston",
		"A sound when something can be used with the interact key.",
		"Ein Ton, wenn etwas mit der Interaktionstaste benutzt werden kann."
	),
	combinedBags = Switch(
		"game",
		"Combine bags",
		"Taschen zusammenfassen",
		"All bags in one window.",
		"Alle Taschen in einem Fenster."
	),
	countdownForCooldowns = Switch(
		"game",
		"Cooldown as number",
		"Abklingzeit als Zahl",
		"Remaining cooldown as a number on action buttons.",
		"Restzeit als Zahl auf Aktionstasten."
	),
	nameplateShowEnemies = Switch(
		"game",
		"Enemy nameplates",
		"Feindliche Namensplaketten",
		"Health bars above enemies.",
		"Lebensbalken über Gegnern."
	),
	lockActionBars = Switch(
		"game",
		"Lock action bars",
		"Aktionsleisten sperren",
		"Prevents dragging spells off the bars by accident.",
		"Verhindert versehentliches Herausziehen von Zaubern."
	),
	mouseSpeed = Slider(
		"game",
		"Mouse speed",
		"Mausgeschwindigkeit",
		"Sensitivity when looking around with the mouse.",
		"Empfindlichkeit beim Umschauen mit der Maus.",
		0.5,
		4,
		0.1
	),
	cooldownViewerEnabled = Switch(
		"game",
		"Cooldown manager",
		"Abklingzeiten-Manager",
		"Blizzard's bars of important cooldowns.",
		"Blizzards Leisten wichtiger Abklingzeiten."
	),
	damageMeterEnabled = Switch(
		"game",
		"Damage meter",
		"Schadensanzeige",
		"Blizzard's damage meter.",
		"Blizzards Schadensanzeige."
	),
	damageMeterResetOnNewInstance = Switch(
		"game",
		"Reset meter in instances",
		"Anzeige in Instanzen leeren",
		"Empties the damage meter when entering a dungeon.",
		"Leert die Schadensanzeige beim Betreten eines Dungeons."
	),
	raidFramesDisplayClassColor = Switch(
		"game",
		"Raid frames in class colours",
		"Schlachtzugsfenster in Klassenfarben",
		"For Blizzard's raid frames (stevio-ui has its own grid).",
		"Für Blizzards Schlachtzugsfenster (stevio-ui hat ein eigenes Raster)."
	),
	raidFramesDisplayOnlyDispellableDebuffs = Switch(
		"game",
		"Only dispellable debuffs",
		"Nur bannbare Debuffs",
		"Blizzard's raid frames show only debuffs you can dispel.",
		"Blizzards Schlachtzugsfenster zeigen nur Debuffs, die du bannen kannst."
	),
	raidOptionDisplayPets = Switch(
		"game",
		"Pets in raid frames",
		"Begleiter in Schlachtzugsfenstern",
		"Shows pets in Blizzard's raid frames.",
		"Zeigt Begleiter in Blizzards Schlachtzugsfenstern."
	),
	occludedSilhouettePlayer = Switch(
		"game",
		"Silhouette behind walls",
		"Umriss hinter Wänden",
		"Your character shows as an outline when hidden behind something.",
		"Deine Figur erscheint als Umriss, wenn sie verdeckt ist."
	),

	-- Accessibility
	Sound_EnableErrorSpeech = Switch(
		"accessibility",
		"Error speech",
		"Fehler-Sprachausgabe",
		'Your character says "Not enough mana" and the like out loud.',
		"Die Figur sagt „Nicht genug Mana“ und Ähnliches laut."
	),
	userFontScale = Slider(
		"accessibility",
		"Font size",
		"Schriftgröße",
		"Scales Blizzard's fonts in the game.",
		"Skaliert Blizzards Schriften im Spiel.",
		0.85,
		1.5,
		0.05,
		{ percent = true }
	),
	userFontScaleGlue = Slider(
		"accessibility",
		"Font size outside the game",
		"Schriftgröße außerhalb",
		"The same for the login and character screens.",
		"Dasselbe für Login- und Charakterbildschirm.",
		0.85,
		1.5,
		0.05,
		{ percent = true }
	),
	showPhotosensitivityWarning = Switch(
		"accessibility",
		"Photosensitivity warning",
		"Warnung zu Lichtempfindlichkeit",
		"The notice when the game starts.",
		"Der Hinweis beim Start des Spiels."
	),
	accessibilityScreenNarrationEnabled = Switch(
		"accessibility",
		"Screen narration",
		"Bildschirmvorlesen",
		"Reads menus and texts out loud.",
		"Liest Menüs und Texte vor."
	),
	showScreenNarrationDialog = Switch(
		"accessibility",
		"Narration notice",
		"Hinweis Vorlesen",
		"Asks about screen narration at the start.",
		"Fragt beim Start nach dem Bildschirmvorlesen."
	),
}

-- Raid variants ----------------------------------------------------------------

-- The base CVar of a raid variant ("RAIDfarclip" -> "farclip"), if `names`
-- (a set) holds it. CVar names are case-insensitive ("RAIDWaterDetail" is
-- the raid variant of "waterDetail"); the spelling in `names` is returned.
function Info.RaidBase(name, names)
	local base = name:match("^RAID(.+)$")
	if not base then
		return nil
	end
	if names[base] ~= nil then
		return base
	end
	local lower = base:lower()
	for known in pairs(names) do
		if known:lower() == lower then
			return known
		end
	end
end

-- `cvars` (name -> value) with every raid variant set to its base's value:
-- "the same values in raids".
function Info.Mirror(cvars)
	local mirrored = {}
	for name, value in pairs(cvars) do
		mirrored[name] = value
	end
	for name in pairs(cvars) do
		local base = Info.RaidBase(name, cvars)
		if base then
			mirrored[name] = cvars[base]
		end
	end
	return mirrored
end

-- Rows -------------------------------------------------------------------------------

-- The value a control writes: "1"/"0" for a switch, a number without
-- trailing zeros, text as it is.
function Info.ToCVar(value)
	if value == true then
		return "1"
	elseif value == false then
		return "0"
	elseif type(value) == "number" then
		local text = ("%.4f"):format(value):gsub("0+$", ""):gsub("%.$", "")
		return text
	end
	return tostring(value)
end

-- What a control shows for a CVar's `value` (text): a boolean for a switch,
-- a number for a slider.
function Info.FromCVar(info, value)
	if info.control == "switch" then
		return value ~= "0" and value ~= nil and value ~= ""
	elseif info.control == "slider" then
		return tonumber(value) or info.min
	end
	return value
end

-- The rows of the page in group order. `profile` and `overrides` are the
-- CVar maps (an override `false` is not used for CVars); `isIgnored(name)`
-- leaves client-state CVars out; `mirror` hides the raid variants;
-- `filter` is "all", "own" or a group key; `query` matches name, help and
-- technical name. Returns the groups { key, rows } with rows { name, info,
-- value, profileValue, own, raidOf } and the counts per filter.
function Info.Rows(profile, overrides, opts)
	local names = {}
	for name in pairs(profile) do
		names[name] = true
	end
	for name in pairs(overrides) do
		names[name] = true
	end
	local query = opts.query and ns.SettingsSearch.Lower(opts.query:match("^%s*(.-)%s*$")) or ""
	local counts = { all = 0, own = 0 }
	for _, group in ipairs(Info.GROUPS) do
		counts[group.key] = 0
	end
	local byGroup = {}
	local sorted = {}
	for name in pairs(names) do
		sorted[#sorted + 1] = name
	end
	table.sort(sorted, function(a, b)
		return a:lower() < b:lower()
	end)
	for _, name in ipairs(sorted) do
		if not opts.isIgnored(name) then
			local raidOf = Info.RaidBase(name, names)
			if not (raidOf and opts.mirror) then
				local info = Info.CVARS[raidOf or name]
				local group = raidOf and "raid" or (info and info.group) or "other"
				local override = overrides[name]
				local row = {
					name = name,
					info = info,
					raidOf = raidOf,
					group = group,
					profileValue = profile[name],
					value = override or profile[name],
					own = override ~= nil,
				}
				local label = info and ns.T(info.name[1], info.name[2]) or name
				local help = info and ns.T(info.help[1], info.help[2]) or ""
				local matches = query == ""
					or ns.SettingsSearch.Lower(label):find(query, 1, true)
					or ns.SettingsSearch.Lower(help):find(query, 1, true)
					or name:lower():find(query, 1, true)
				if matches then
					counts.all = counts.all + 1
					counts[group] = counts[group] + 1
					counts.own = counts.own + (row.own and 1 or 0)
					local shown = opts.filter == "all" or opts.filter == group or (opts.filter == "own" and row.own)
					if shown then
						byGroup[group] = byGroup[group] or {}
						table.insert(byGroup[group], row)
					end
				end
			end
		end
	end
	local groups = {}
	for _, group in ipairs(Info.GROUPS) do
		if byGroup[group.key] then
			groups[#groups + 1] = { key = group.key, group = group, rows = byGroup[group.key] }
		end
	end
	return groups, counts
end

-- How many raid variants follow their base while mirroring.
function Info.RaidCount(profile, overrides)
	local names = {}
	for name in pairs(profile) do
		names[name] = true
	end
	for name in pairs(overrides) do
		names[name] = true
	end
	local count = 0
	for name in pairs(names) do
		if Info.RaidBase(name, names) then
			count = count + 1
		end
	end
	return count
end
