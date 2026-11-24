local _, ns = ...

-- The search of the settings window: finds settings by their name, help
-- text, module, section and value, in the client's language and regardless
-- of case. Kept free of WoW API calls so it can be tested outside the game
-- (tests/settings_search_test.lua).

local Pages = ns.ConfigPages
local Meta = ns.SettingsMeta

local Search = {}
ns.SettingsSearch = Search

-- string.lower only knows ASCII; the umlauts are two bytes each and keep
-- their length, so positions in the lowered text fit the original.
local UPPER = { ["Ä"] = "ä", ["Ö"] = "ö", ["Ü"] = "ü", ["É"] = "é" }

function Search.Lower(text)
	text = text:lower()
	for upper, lower in pairs(UPPER) do
		text = text:gsub(upper, lower)
	end
	return text
end

local function Trim(text)
	return (text or ""):match("^%s*(.-)%s*$")
end

-- One entry per setting of every page: the item and the texts it is found by.
-- `itemsOf(module)` returns a page's items (Meta.Items).
function Search.Entries(itemsOf)
	local entries = {}
	local modules = { Pages.STYLE }
	for _, module in ipairs(Pages.MODULES) do
		modules[#modules + 1] = module
	end
	for order, module in ipairs(modules) do
		local title = Pages.Title(module)
		for _, item in ipairs(itemsOf(module)) do
			local section = Pages.Section(module, item.section)
			local sectionTitle = item.advanced and ns.T("Advanced", "Erweitert")
				or (section and ns.T(section.title[1], section.title[2]))
				or ""
			local path = sectionTitle
			if item.group then
				path = path ~= "" and (path .. " › " .. item.group) or item.group
			end
			entries[#entries + 1] = {
				item = item,
				module = module[1],
				moduleTitle = title,
				order = order,
				path = path,
				texts = {
					item.label or "",
					item.help or "",
					title,
					path,
				},
			}
		end
	end
	return entries
end

-- The value of an entry as the search sees it ("38 %", "on"); `value` is
-- the live value of its setting.
function Search.ValueText(entry, value)
	return Meta.FormatValue(value, entry.item.meta, entry.item.control)
end

-- The entries matching `query`, grouped by module in page order:
-- { total, groups = { { module, title, entries } } }. Values are matched as
-- `valueOf(entry)` writes them (nil: values aren't searched).
function Search.Run(entries, query, valueOf)
	query = Search.Lower(Trim(query))
	local result = { total = 0, groups = {}, query = query }
	if query == "" then
		return result
	end
	local byModule = {}
	for _, entry in ipairs(entries) do
		local found = false
		for _, text in ipairs(entry.texts) do
			if Search.Lower(text):find(query, 1, true) then
				found = true
				break
			end
		end
		if not found and valueOf then
			found = Search.Lower(valueOf(entry)):find(query, 1, true) ~= nil
		end
		if found then
			local group = byModule[entry.module]
			if not group then
				group = { module = entry.module, title = entry.moduleTitle, order = entry.order, entries = {} }
				byModule[entry.module] = group
				result.groups[#result.groups + 1] = group
			end
			table.insert(group.entries, entry)
			result.total = result.total + 1
		end
	end
	table.sort(result.groups, function(a, b)
		return a.order < b.order
	end)
	return result
end

-- `text` with every match of `query` wrapped in `open` and `close` (colour
-- codes), keeping the original spelling.
function Search.Highlight(text, query, open, close)
	query = Search.Lower(Trim(query))
	if query == "" then
		return text
	end
	local lower = Search.Lower(text)
	local parts, position = {}, 1
	while true do
		local first, last = lower:find(query, position, true)
		if not first then
			break
		end
		parts[#parts + 1] = text:sub(position, first - 1)
		parts[#parts + 1] = open .. text:sub(first, last) .. close
		position = last + 1
	end
	parts[#parts + 1] = text:sub(position)
	return table.concat(parts)
end
