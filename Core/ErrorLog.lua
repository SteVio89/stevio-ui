local addonName, ns = ...

-- Blizzard's error frame records every Lua error even with scriptErrors off, but
-- only until the next /reload. Copying our entries into a SavedVariable keeps
-- them readable from the WTF folder; reading its data needs no error-handler hook.

local MAX_ENTRIES = 50

-- Blizzard's frame indexes its entries by position, so clearing skips them instead of wiping them.
local firstSessionIndex = 1

local function IsOurs(entry)
	return entry.message:find(addonName, 1, true) or entry.stack:find(addonName, 1, true)
end

local function CollectSessionErrors()
	local collected = {}
	if not ScriptErrorsFrame then
		return collected
	end
	for i = firstSessionIndex, #ScriptErrorsFrame.errorData do
		local entry = ScriptErrorsFrame.errorData[i]
		-- Secret values can't be searched or written to SavedVariables.
		local readable = not (issecretvalue(entry.message) or issecretvalue(entry.stack) or issecretvalue(entry.locals))
		if readable and IsOurs(entry) then
			collected[#collected + 1] = {
				time = entry.time,
				count = entry.count,
				message = entry.message,
				stack = entry.stack,
				locals = entry.locals,
			}
		end
	end
	return collected
end

-- Earlier sessions stay in the log, so a /reload after an error burst doesn't wipe it.
local function AllErrors()
	local all = CopyTable(StevioUIErrors or {})
	tAppendAll(all, CollectSessionErrors())
	while #all > MAX_ENTRIES do
		table.remove(all, 1)
	end
	return all
end

ns:RegisterEvent("PLAYER_LOGOUT", function()
	StevioUIErrors = AllErrors()
end)

ns:RegisterSlashCommand("errors", function(input)
	if input == "clear" then
		StevioUIErrors = {}
		if ScriptErrorsFrame then
			firstSessionIndex = #ScriptErrorsFrame.errorData + 1
		end
		print(("|cff33ff99%s|r: error log cleared"):format(addonName))
		return
	end

	local all = AllErrors()
	if #all == 0 then
		print(("|cff33ff99%s|r: no errors logged – /sui errors clear"):format(addonName))
		return
	end
	local parts = {}
	for i, entry in ipairs(all) do
		parts[i] = ("#%d  %s  x%d\n%s\n%s\nLocals:\n%s"):format(i, entry.time, entry.count, entry.message, entry.stack, entry.locals)
	end
	ns.ShowExportWindow(table.concat(parts, "\n\n"))
end)
