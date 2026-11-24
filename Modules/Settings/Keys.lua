local _, ns = ...

-- The keybindings page's decisions: readable key names ("Shift A",
-- "Leertaste", "Num 0"), which actions show under which filter, where an own
-- key takes one the profile gives to another action (a conflict), and which
-- keys belong to keyboard healing. Kept free of WoW API calls so it can be
-- tested outside the game (tests/settings_keys_test.lua).

local Overrides = ns.Overrides

local Keys = {}
ns.SettingsKeys = Keys

local MODIFIERS = {
	SHIFT = { "Shift", "Shift" },
	CTRL = { "Ctrl", "Strg" },
	ALT = { "Alt", "Alt" },
	META = { "Cmd", "Cmd" },
}

local NAMES = {
	SPACE = { "Space", "Leertaste" },
	ENTER = { "Enter", "Eingabe" },
	ESCAPE = { "Esc", "Esc" },
	TAB = { "Tab", "Tab" },
	BACKSPACE = { "Backspace", "Rücktaste" },
	INSERT = { "Insert", "Einfg" },
	DELETE = { "Delete", "Entf" },
	HOME = { "Home", "Pos1" },
	END = { "End", "Ende" },
	PAGEUP = { "Page up", "Bild hoch" },
	PAGEDOWN = { "Page down", "Bild runter" },
	UP = { "Up", "Hoch" },
	DOWN = { "Down", "Runter" },
	LEFT = { "Left", "Links" },
	RIGHT = { "Right", "Rechts" },
	PRINTSCREEN = { "Print", "Druck" },
	NUMLOCK = { "Num", "Num" },
	NUMPADMINUS = { "Num -", "Num -" },
	NUMPADPLUS = { "Num +", "Num +" },
	NUMPADDIVIDE = { "Num /", "Num /" },
	NUMPADMULTIPLY = { "Num *", "Num *" },
	NUMPADDECIMAL = { "Num ,", "Num ," },
	MOUSEWHEELUP = { "Wheel up", "Mausrad hoch" },
	MOUSEWHEELDOWN = { "Wheel down", "Mausrad runter" },
	LeftButton = { "Left click", "Linksklick" },
	RightButton = { "Right click", "Rechtsklick" },
	MiddleButton = { "Middle click", "Mittelklick" },
}

-- "SHIFT-A" -> "Shift A", "NUMPAD0" -> "Num 0", "BUTTON4" -> "Maustaste 4".
function Keys.DisplayName(key)
	local parts = {}
	local rest = key
	while true do
		local modifier, after = rest:match("^(%u+)%-(.+)$")
		if modifier and MODIFIERS[modifier] then
			parts[#parts + 1] = ns.T(MODIFIERS[modifier][1], MODIFIERS[modifier][2])
			rest = after
		else
			break
		end
	end
	local name = NAMES[rest]
	if name then
		rest = ns.T(name[1], name[2])
	elseif rest:match("^NUMPAD%d$") then
		rest = "Num " .. rest:sub(-1)
	elseif rest:match("^BUTTON%d+$") then
		rest = ns.T("Mouse ", "Maustaste ") .. rest:match("%d+")
	end
	parts[#parts + 1] = rest
	return table.concat(parts, " ")
end

-- Keyboard healing's arrow keys (config.keyboardHealing.keys) while the
-- module is on: they can't be bound here. A set of keys.
function Keys.Locked(keyboardHealing)
	local locked = {}
	if keyboardHealing and keyboardHealing.enabled ~= false then
		for _, key in pairs(keyboardHealing.keys or {}) do
			locked[key] = true
		end
	end
	return locked
end

-- The command the key gives to another action than `command`, if any: what
-- binding `key` to `command` replaces.
function Keys.Taken(effective, key, command)
	local current = effective[key]
	if current and current ~= command then
		return current
	end
end

-- Keys bound to another action by the profile and to an own one by an
-- override: { key, profileCommand, ownCommand }, sorted by key.
function Keys.Conflicts(profile, overrides)
	local list = {}
	for key, command in pairs(overrides) do
		local profileCommand = profile[key]
		if command and profileCommand and command ~= profileCommand then
			list[#list + 1] = { key = key, profileCommand = profileCommand, ownCommand = command }
		end
	end
	table.sort(list, function(a, b)
		return a.key < b.key
	end)
	return list
end

-- The overrides to remove so `command` has its profile keys again: keys the
-- override gives to it and keys the profile gives it that an override took.
function Keys.ResetKeys(command, profile, overrides)
	local keys = {}
	for key, value in pairs(overrides) do
		if value == command or profile[key] == command then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	return keys
end

local function SortedKeys(keys)
	table.sort(keys, function(a, b)
		local lengthA, lengthB = select(2, a:gsub("%-", "")), select(2, b:gsub("%-", ""))
		if lengthA ~= lengthB then
			return lengthA < lengthB
		end
		return a < b
	end)
	return keys
end

-- The rows of the page by Blizzard's categories. `actions` is the client's
-- binding list in its order: { command, category, categoryName, name };
-- `filter` one of "all" (actions with a key or one in the profile), "own"
-- (changed by an override), "conflicts", "unbound" (no key); `query` matches
-- the action's name or a key. Returns the groups { name, rows } with rows
-- { command, name, keys, own, inProfile, conflicts }, and the counts per filter.
function Keys.Rows(actions, profile, overrides, filter, query)
	local effective = Overrides.Merge(profile, overrides)
	local keysOf, profileCommands, ownCommands = {}, {}, {}
	for key, command in pairs(effective) do
		keysOf[command] = keysOf[command] or {}
		table.insert(keysOf[command], key)
	end
	for _, command in pairs(profile) do
		profileCommands[command] = true
	end
	-- Both the action an override binds and the one it takes the key from count as changed.
	for key, command in pairs(overrides) do
		if command then
			ownCommands[command] = true
		end
		if profile[key] then
			ownCommands[profile[key]] = true
		end
	end
	local conflictsOf = {}
	for _, conflict in ipairs(Keys.Conflicts(profile, overrides)) do
		conflictsOf[conflict.ownCommand] = conflictsOf[conflict.ownCommand] or {}
		table.insert(conflictsOf[conflict.ownCommand], conflict)
	end

	query = query and ns.SettingsSearch.Lower(query:match("^%s*(.-)%s*$")) or ""
	local counts = { all = 0, own = 0, conflicts = 0, unbound = 0 }
	local groups, byCategory = {}, {}
	for _, action in ipairs(actions) do
		local command = action.command
		local keys = SortedKeys(keysOf[command] or {})
		local row = {
			command = command,
			name = action.name or command,
			keys = keys,
			own = ownCommands[command] == true,
			inProfile = profileCommands[command] == true,
			conflicts = conflictsOf[command] or {},
		}
		local listed = #keys > 0 or row.inProfile
		local matches = query == ""
			or ns.SettingsSearch.Lower(row.name):find(query, 1, true) ~= nil
			or command:lower():find(query, 1, true) ~= nil
		if not matches then
			for _, key in ipairs(keys) do
				if ns.SettingsSearch.Lower(Keys.DisplayName(key)):find(query, 1, true) or key:lower() == query then
					matches = true
				end
			end
		end
		if matches then
			counts.all = counts.all + (listed and 1 or 0)
			counts.own = counts.own + (row.own and 1 or 0)
			counts.conflicts = counts.conflicts + (#row.conflicts > 0 and 1 or 0)
			counts.unbound = counts.unbound + (#keys == 0 and 1 or 0)
		end
		local shown = (filter == "all" and listed)
			or (filter == "own" and row.own)
			or (filter == "conflicts" and #row.conflicts > 0)
			or (filter == "unbound" and #keys == 0)
		if matches and shown then
			local group = byCategory[action.categoryName]
			if not group then
				group = { name = action.categoryName, rows = {} }
				byCategory[action.categoryName] = group
				groups[#groups + 1] = group
			end
			table.insert(group.rows, row)
		end
	end
	return groups, counts
end
