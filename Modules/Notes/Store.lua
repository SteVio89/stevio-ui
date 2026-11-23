local _, ns = ...

-- Game-independent part of the notes: item notes and general notes in one
-- saved table. Notes on players live in the player database (Modules/Players).
-- Times are passed in (`now`, seconds like time()) so this can be tested
-- outside the game.

local Store = {}
ns.NotesStore = Store
Store.__index = Store

Store.VERSION = 1

-- Wraps the saved table `db` (created when nil) and fills in missing parts.
function Store.New(db)
	db = db or {}
	db.version = db.version or Store.VERSION
	db.items = db.items or {}
	db.notes = db.notes or {}
	return setmetatable({ db = db }, Store)
end

local function Trimmed(text)
	text = text and text:match("^%s*(.-)%s*$") or ""
	return text ~= "" and text or nil
end

-- Items --------------------------------------------------------------------

function Store:ItemNote(itemID)
	local item = self.db.items[itemID]
	return item and item.text
end

-- Sets the note of an item type; empty text removes it.
function Store:SetItemNote(itemID, text, now)
	text = Trimmed(text)
	if text then
		self.db.items[itemID] = { text = text, changed = now }
	else
		self.db.items[itemID] = nil
	end
end

-- Item IDs with a note, the most recently changed first.
function Store:ItemIDs()
	local ids = {}
	for id in pairs(self.db.items) do
		ids[#ids + 1] = id
	end
	table.sort(ids, function(a, b)
		local ca, cb = self.db.items[a].changed or 0, self.db.items[b].changed or 0
		if ca ~= cb then
			return ca > cb
		end
		return a < b
	end)
	return ids
end

-- General notes ------------------------------------------------------------

function Store:AddNote(now)
	local note = { text = "", created = now, changed = now }
	table.insert(self.db.notes, note)
	return note
end

function Store.SetNoteText(note, text, now)
	note.text, note.changed = text or "", now
end

function Store:RemoveNote(note)
	for index, candidate in ipairs(self.db.notes) do
		if candidate == note then
			table.remove(self.db.notes, index)
			return true
		end
	end
	return false
end

-- General notes matching `filter`, the most recently changed first.
function Store:Notes(filter)
	local list = {}
	filter = filter and filter:lower() or ""
	for _, note in ipairs(self.db.notes) do
		if filter == "" or note.text:lower():find(filter, 1, true) then
			list[#list + 1] = note
		end
	end
	table.sort(list, function(a, b)
		return (a.changed or 0) > (b.changed or 0)
	end)
	return list
end

-- The first non-empty line of a text, for lists.
function Store.Title(text)
	return (text or ""):match("^%s*([^\n]-)%s*\n") or (text or ""):match("^%s*(.-)%s*$")
end
