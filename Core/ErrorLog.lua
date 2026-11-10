local addonName, ns = ...

-- Blizzard's error frame records every Lua error even with scriptErrors off, but
-- only until the next /reload. Copying our entries into a SavedVariable keeps
-- them readable from the WTF folder; reading its data needs no error-handler hook.

local ErrorLog = {}
ns.ErrorLog = ErrorLog

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

-- Appends `session` to `earlier` (changing it) and keeps the newest
-- MAX_ENTRIES entries.
function ErrorLog.Merge(earlier, session)
	for _, entry in ipairs(session) do
		earlier[#earlier + 1] = entry
	end
	while #earlier > MAX_ENTRIES do
		table.remove(earlier, 1)
	end
	return earlier
end

-- The text /sui errors shows.
function ErrorLog.Format(entries)
	local parts = {}
	for i, entry in ipairs(entries) do
		parts[i] = ("#%d  %s  x%d\n%s\n%s\nLocals:\n%s"):format(
			i,
			entry.time,
			entry.count,
			entry.message,
			entry.stack,
			entry.locals
		)
	end
	return table.concat(parts, "\n\n")
end

-- Earlier sessions stay in the log, so a /reload after an error burst doesn't wipe it.
local function AllErrors()
	return ErrorLog.Merge(CopyTable(StevioUIErrors or {}), CollectSessionErrors())
end

ns.RegisterEvent("PLAYER_LOGOUT", function()
	StevioUIErrors = AllErrors()
end)

ns.RegisterSlashCommand("errors", function(input)
	if input == "clear" then
		StevioUIErrors = {}
		if ScriptErrorsFrame then
			firstSessionIndex = #ScriptErrorsFrame.errorData + 1
		end
		ns.Print(ns.T("error log cleared", "Fehlerprotokoll geleert"))
		return
	end

	local all = AllErrors()
	if #all == 0 then
		ns.Print(ns.T("no errors logged – /sui errors clear", "keine Fehler protokolliert – /sui errors clear"))
		return
	end
	ns.ShowTextWindow(ErrorLog.Format(all))
end)
