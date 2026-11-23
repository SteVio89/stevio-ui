-- Run with: lua tests/notes_store_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Notes/Store.lua")
local Store = ns.NotesStore

-- New fills in a missing or partial saved table.
local store = Store.New(nil)
check(store.db.version == 1 and next(store.db.items) == nil and next(store.db.notes) == nil, "fresh table")
local saved = { items = { [2589] = { text = "linen" } } }
store = Store.New(saved)
check(store.db == saved and store:ItemNote(2589) == "linen" and store.db.notes, "existing table kept")
store = Store.New(nil)
print("new ok")

-- Item notes.
store:SetItemNote(2589, " 90 pieces for 1s each ", 100)
store:SetItemNote(2592, "wool", 200)
check(store:ItemNote(2589) == "90 pieces for 1s each", "item note")
check(table.concat(store:ItemIDs(), ",") == "2592,2589", "newest first")
store:SetItemNote(2589, "", 300)
check(store:ItemNote(2589) == nil and #store:ItemIDs() == 1, "empty removes")
print("items ok")

-- General notes.
local first = store:AddNote(100)
Store.SetNoteText(first, "Shopping\nlinen", 100)
local second = store:AddNote(200)
Store.SetNoteText(second, "Quest chain", 200)
local list = store:Notes()
check(list[1] == second and list[2] == first, "newest first")
check(#store:Notes("LINEN") == 1, "filter")
check(Store.Title(first.text) == "Shopping", "title is the first line")
check(Store.Title("\n  Title  \nrest") == "Title" and Store.Title("") == "", "title trimmed")
check(store:RemoveNote(first) and #store:Notes() == 1, "removed")
check(not store:RemoveNote(first), "not there twice")
print("general notes ok")

print("notes store tests passed")
