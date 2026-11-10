local _, ns = ...

-- What the config editor (Editor.lua) shows and in which order. Kept free of
-- WoW API calls so it can be tested outside the game.

local Overrides = ns.Overrides

local Model = {}
ns.EditorModel = Model

-- Paths the editor never shows: the profile has pages of its own, and the
-- settings module builds this panel, so turning it off would lock it away.
Model.HIDDEN = {
	["config/settings/profile"] = true,
	["config/settings/enabled"] = true,
}

-- A list of 3 or 4 numbers between 0 and 1 (r, g, b and maybe alpha); the
-- config has no other lists like that.
function Model.IsColor(key, value)
	if not Overrides.IsList(value) or (#value ~= 3 and #value ~= 4) then
		return false
	end
	for _, component in ipairs(value) do
		if type(component) ~= "number" or component < 0 or component > 1 then
			return false
		end
	end
	return type(key) == "string"
end

-- Keys in display order: "enabled" first, then plain values, then tables, each by label.
function Model.SortedKeys(tbl)
	if Overrides.IsList(tbl) then
		local keys = {}
		for index = 1, #tbl do
			keys[index] = index
		end
		return keys
	end
	local keys = {}
	for key in pairs(tbl) do
		keys[#keys + 1] = key
	end
	local function Rank(key)
		if key == "enabled" then
			return 0
		end
		local value = tbl[key]
		return (type(value) == "table" and not Model.IsColor(key, value)) and 2 or 1
	end
	table.sort(keys, function(a, b)
		local rankA, rankB = Rank(a), Rank(b)
		if rankA ~= rankB then
			return rankA < rankB
		end
		return ns.ConfigLabel(a):lower() < ns.ConfigLabel(b):lower()
	end)
	return keys
end
