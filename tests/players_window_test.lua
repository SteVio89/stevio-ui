-- Run with: lua tests/players_window_test.lua  (from the repo root)
-- A smoke test of the players window (#86): with every frame faked, the
-- window, its list, the overview, a player's page and the rating popup are
-- built and rendered once with an empty and a filled database, so typos and
-- calls on nil show up outside the game. Looks are checked in game.
local check, loadAddonFile = dofile("tests/helpers.lua")

local now = 100 * 86400 + 15 * 3600

-- A fake widget: remembers points, sizes, texts and scripts; any other
-- method does nothing.
local Widget = {}
local function NewWidget(kind)
	local widget = setmetatable(
		{ kind = kind, scripts = {}, width = 100, height = 20, shown = true, text = "", children = {} },
		Widget
	)
	return widget
end
local methods = {
	GetWidth = function(self)
		return self.width
	end,
	GetHeight = function(self)
		return self.height
	end,
	SetWidth = function(self, width)
		assert(type(width) == "number", "SetWidth needs a number")
		self.width = width
	end,
	SetHeight = function(self, height)
		assert(type(height) == "number", "SetHeight needs a number")
		self.height = height
	end,
	SetSize = function(self, width, height)
		assert(type(width) == "number" and type(height) == "number", "SetSize needs numbers")
		self.width, self.height = width, height
	end,
	GetStringWidth = function(self)
		return #(self.text or "") * 6
	end,
	SetText = function(self, text)
		self.text = text ~= nil and tostring(text) or ""
	end,
	SetFormattedText = function(self, format, ...)
		self.text = format:format(...)
	end,
	GetText = function(self)
		return self.text
	end,
	Show = function(self)
		self.shown = true
	end,
	Hide = function(self)
		self.shown = false
	end,
	SetShown = function(self, shown)
		self.shown = not not shown
	end,
	IsShown = function(self)
		return self.shown
	end,
	SetScript = function(self, name, fn)
		self.scripts[name] = fn
	end,
	HookScript = function(self, name, fn)
		self.scripts[name] = fn
	end,
	GetScript = function(self, name)
		return self.scripts[name]
	end,
	GetVerticalScroll = function()
		return 0
	end,
	GetMinMaxValues = function()
		return 0, 0
	end,
	GetValue = function()
		return 0
	end,
	HasFocus = function()
		return false
	end,
	GetPoint = function()
		return "CENTER", nil, "CENTER", 0, 0
	end,
	GetParent = function(self)
		return self.parent
	end,
	GetName = function(self)
		return self.name
	end,
	GetFrameLevel = function()
		return 1
	end,
	GetHighlightTexture = function()
		return NewWidget("Texture")
	end,
	CreateTexture = function(self)
		local texture = NewWidget("Texture")
		texture.parent = self
		return texture
	end,
	CreateMaskTexture = function()
		return NewWidget("MaskTexture")
	end,
	CreateFontString = function(self)
		local text = NewWidget("FontString")
		text.parent = self
		return text
	end,
	SetPoint = function(_, point, ...)
		assert(type(point) == "string", "SetPoint needs a point")
		local relative = ...
		assert(relative == nil or type(relative) ~= "string" or relative:match("^[A-Z]+$"), "bad relative point")
	end,
}
-- Methods are capitalized; other keys are fields, nil until set, as in the game.
Widget.__index = function(_, name)
	if methods[name] then
		return methods[name]
	end
	if type(name) == "string" and name:match("^%u") then
		return function() end
	end
end

_G.CreateFrame = function(kind, name, parent)
	local frame = NewWidget(kind)
	frame.parent, frame.name = parent, name
	if name then
		_G[name] = frame
	end
	return frame
end
_G.UIParent = NewWidget("Frame")
_G.UISpecialFrames = {}
_G.tinsert = table.insert
_G.time = function(day)
	if day then
		return os.time(day)
	end
	return now
end
_G.date = os.date
_G.issecretvalue = function()
	return false
end
_G.InCombatLockdown = function()
	return false
end
_G.hooksecurefunc = function(object, name, hook)
	local original = object[name]
	object[name] = function(...)
		original(...)
		hook(...)
	end
end
_G.CreateColor = function(r, g, b, a)
	return { r = r, g = g, b = b, a = a }
end
_G.PixelUtil = {
	ConvertPixelsToUIForRegion = function()
		return 1
	end,
}
_G.C_ClassColor = {
	GetClassColor = function()
		return {
			r = 1,
			g = 0.5,
			b = 0,
			WrapTextInColorCode = function(_, text)
				return text
			end,
		}
	end,
}
_G.LOCALIZED_CLASS_NAMES_MALE = { DRUID = "Druid", WARRIOR = "Warrior" }
_G.STANDARD_TEXT_FONT = "font"
_G.ChatFontNormal = {}
_G.GameTooltip = NewWidget("GameTooltip")
_G.GameTooltip_Hide = function() end
_G.StaticPopupDialogs = {}
_G.YES, _G.NO, _G.OKAY = "Yes", "No", "Okay"
_G.MenuUtil = { CreateContextMenu = function() end }

local registered = {}
local ns = {
	config = {},
	name = "stevio-ui",
	T = function(english)
		return english
	end,
	RegisterModule = function(name, module)
		module.name = name
		return module
	end,
	RegisterModuleCommand = function() end,
	RegisterEvent = function(event, handler)
		registered[event] = handler
	end,
	Print = function() end,
}
loadAddonFile("Core/Config.lua", ns)
loadAddonFile("Core/Theme.lua", ns)
loadAddonFile("Core/Util.lua", ns)
loadAddonFile("Modules/Notes/Config.lua", ns)
loadAddonFile("Modules/Notes/Widgets.lua", ns)
for _, file in ipairs({
	"Config",
	"Store",
	"Stats",
	"Widgets",
	"Kit",
	"Overview",
	"Page",
	"Window",
	"Popup",
}) do
	loadAddonFile("Modules/Players/" .. file .. ".lua", ns)
end
local Store = ns.PlayersStore
local Window = ns.PlayersWindow

-- Empty database: the overview of nothing.
ns.Players = { store = Store.New(nil) }
Window.Open()
check(StevioUI_Players and StevioUI_Players.shown, "window open")
Window.Select(nil)
for _, period in ipairs({ 7, 30, false }) do
	Window.state.period = period or nil
	Window.RenderContent()
end
print("empty ok")

-- A filled database: every part of the overview and the page.
local store = Store.New(nil)
ns.Players.store = store
local DAY = 86400
for index = 1, 220 do
	local name = ("Player%d-Realm"):format(index)
	local start = now - (index % 40) * DAY - 3600
	store:Open(
		name,
		{ class = "DRUID", role = Store.ROLES[index % 3 + 1], place = "Uldaman", isInstance = true },
		start
	)
	store:Encounter("Ironaya", true)
	store:Encounter(nil, false)
	store:Close(name, start + 1800)
	store:AddRoll(name, nil, index % 4 == 0 and "need" or "greed", start)
	if index % 5 == 0 then
		Store.Rate(store:Player(name).sessions[1], index % 5 + 1)
	end
end
local brakk = store:Ensure("Brakk-Kaltstahl", "WARRIOR", now - 3 * DAY)
store:Open("Brakk-Kaltstahl", { class = "WARRIOR", role = "TANK", place = "Uldaman", isInstance = true }, now - DAY)
store:Encounter("Ironaya", true)
store:Encounter(nil, false)
store:Close("Brakk-Kaltstahl", now - DAY + 3600)
store:Open("Brakk-Kaltstahl", { place = "Tausend Nadeln" }, now - 7200)
for _ = 1, 14 do
	store:AddRoll("Brakk-Kaltstahl", nil, "need", now)
end
store:AddRoll("Brakk-Kaltstahl", nil, "pass", now)
store:AddWin("Brakk-Kaltstahl", nil, { link = "[Robe]", time = now - DAY + 600, choice = "need" }, now)
brakk.blocked = { guild = "Eisenwacht", pattern = "eisenwacht", time = now - 10 * DAY }
brakk.guild = "Eisenwacht"
store:SetVerdict("Brakk-Kaltstahl", "avoid", now)
store:AddTag("Brakk-Kaltstahl", "Rage-Quit", now)
store:AddTag("Player1-Realm", "Guter Heiler", now)
store:SetPlayerNote("Brakk-Kaltstahl", "Needs on cloth.", now)
Store.Rate(brakk.sessions[1], 1)
Store.SetComment(brakk.sessions[1], "Rage-quit after the second wipe.")

Window.Select(nil)
for _, period in ipairs({ 7, 30, false }) do
	Window.state.period = period or nil
	Window.RenderContent()
end
print("overview ok")

for _, sortBy in ipairs({ "recent", "rating", "time", "name" }) do
	Window.state.sortBy = sortBy
	for _, filter in ipairs(Store.LIST_FILTERS) do
		Window.state.filter = filter
		Window.RefreshList()
	end
end
Window.state.sortBy, Window.state.filter, Window.state.role = "recent", "all", "TANK"
Window.RefreshList()
Window.state.role = nil
print("list ok")

Window.Open("Brakk-Kaltstahl")
check(Window.state.selected == "Brakk-Kaltstahl", "player selected")
for _, history in ipairs({ "all", "loot", "unrated" }) do
	Window.state.history = history
	Window.RenderContent()
end
Window.Select("Player2-Realm")
Window.Select("Player1-Realm")
print("page ok")

-- Arrow keys and typing.
StevioUI_Players.scripts.OnKeyDown(StevioUI_Players, "DOWN")
StevioUI_Players.scripts.OnKeyDown(StevioUI_Players, "UP")
_G.IsControlKeyDown, _G.IsAltKeyDown, _G.IsMetaKeyDown, _G.IsShiftKeyDown =
	function() end, function() end, function() end, function() end
StevioUI_Players.scripts.OnKeyDown(StevioUI_Players, "B")
StevioUI_Players.scripts.OnKeyDown(StevioUI_Players, "F5")
registered.PLAYER_REGEN_DISABLED()
registered.PLAYER_REGEN_ENABLED()
print("keys ok")

-- The rating queue: every unrated group of the last week, then closed.
local groups = store:UnratedGroups(now, now - 7 * DAY)
check(#groups > 1, "groups to rate")
ns.PlayersPopup.ShowQueue(groups)
check(StevioUI_PlayersPopup.shown, "popup shown")
for _ = 1, #groups do
	ns.PlayersPopup.Next()
end
check(not StevioUI_PlayersPopup.shown, "closed after the last group")
print("popup ok")

print("players window tests passed")
