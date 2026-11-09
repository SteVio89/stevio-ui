local _, ns = ...

-- /sui export: the client's current action bars, bindings and changed CVars
-- as the text of a Profile.lua (see Model.ProfileText).

local Model = ns.SettingsModel

function ns.BuildProfileExport()
	local stamp = date("%Y-%m-%d %H:%M")
	local actionBars = ns.CurrentActionBarToggles()
	local bindings = {}
	for index = 1, GetNumBindings() do
		local command, category = GetBinding(index)
		bindings[index] = {
			command = command,
			category = category,
			categoryName = ns.BindingCategoryName(category, "?"),
			keys = ns.GetBindingKeys(index),
		}
	end
	local cvars = {}
	ns.ForEachCVar(function(name, value, defaultValue)
		if value ~= defaultValue and not ns.IsIgnoredCVar(name) then
			cvars[#cvars + 1] = { name = name, value = value }
		end
	end)
	return Model.ProfileText(stamp, actionBars, bindings, cvars)
end
