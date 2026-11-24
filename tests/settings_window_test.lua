-- Run with: lua tests/settings_window_test.lua  (from the repo root)
-- A smoke test of the settings window: with every frame faked, the window
-- and each of its pages are built and rendered, values are changed and reset
-- through the rows, so typos and calls on nil show up outside the game.
-- Looks and behaviour are checked in game.
local registered = {}
local check, loadAddonFile = dofile("tests/helpers.lua")

local now = 1700000000

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
	GetStringHeight = function(self)
		return self.text ~= "" and 14 or 0
	end,
	GetSize = function(self)
		return self.width, self.height
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

_G.C_Timer = {
	After = function(_, fn)
		fn()
	end,
}
_G.C_AddOns = {
	GetAddOnMetadata = function()
		return "@project-version@"
	end,
}
_G.Settings = {
	RegisterCanvasLayoutCategory = function()
		return {
			GetID = function()
				return 1
			end,
		}
	end,
	RegisterAddOnCategory = function() end,
}
_G.SlashCmdList = {}
_G.ColorPickerFrame = NewWidget("ColorPickerFrame")
_G.ReloadUI = function() end
local popups = {}
_G.StaticPopup_Show = function(name, _, _, data)
	popups[#popups + 1] = { name = name, data = data }
end
_G.IsControlKeyDown, _G.IsAltKeyDown, _G.IsMetaKeyDown, _G.IsShiftKeyDown =
	function() end, function() end, function() end, function() end
_G.StevioUIConfig = { values = {}, bindings = {}, cvars = {} }
_G.StevioUIState = { consented = true, backup = { time = now - 86400 } }

local slash = {}
local ns = {
	config = {},
	name = "stevio-ui",
	isGerman = true,
	RegisterModule = function(name, module)
		module.name = name
		return module
	end,
	RegisterModuleCommand = function() end,
	RegisterSlashCommand = function(name, fn)
		slash[name] = fn
	end,
	RegisterEvent = function(event, handler)
		registered[event] = handler
	end,
	UnregisterEvent = function() end,
	Print = function() end,
	SafeCall = function(fn, ...)
		return true, fn(...)
	end,
	RunAfterCombat = function(fn)
		fn()
	end,
}
function ns.T(english, german)
	return ns.isGerman and german or english
end
loadAddonFile("Core/Overrides.lua", ns)
loadAddonFile("Core/Config.lua", ns)
loadAddonFile("Core/Theme.lua", ns)
loadAddonFile("Core/Layout.lua", ns)
loadAddonFile("Core/Util.lua", ns)
local files = io.popen("ls Modules/*/Config.lua")
for path in files:lines() do
	loadAddonFile(path, ns)
end
files:close()
loadAddonFile("Modules/Players/Kit.lua", ns)
for _, file in ipairs({
	"Config",
	"Profile",
	"Model",
	"Labels",
	"Pages",
	"Meta",
	"Help",
	"Search",
	"EditorModel",
	"UI",
	"Controls",
	"Window",
	"PageStart",
	"PageModule",
	"PageSearch",
	"Panel",
}) do
	loadAddonFile("Modules/Settings/" .. file .. ".lua", ns)
end
ns.overrideRoots = { config = ns.config, layout = ns.layout }
ns.overrideDefaults = ns.Overrides.DeepCopy(ns.overrideRoots)
local Window, UI, Pages = ns.SettingsWindow, ns.SettingsUI, ns.ConfigPages

ns.SetupOptionsPanel()
check(slash.config and slash[""] and slash.reset, "slash commands")
slash.config("")
check(StevioUI_Settings and StevioUI_Settings.shown, "window open")
print("window ok")

-- Every page renders, in both languages.
for _, german in ipairs({ true, false }) do
	ns.isGerman = german
	Window.Open("start")
	Window.Open("module", "style")
	for _, module in ipairs(Pages.MODULES) do
		Window.Open("module", module[1])
	end
end
ns.isGerman = true
print("pages ok")

-- Changing a value through its row saves an override and waits for a reload;
-- the row's reset removes it again.
local function Rows(kind)
	return StevioUI_Settings.pages.module.rows.frames[kind] or {}
end
local function RowOf(metaKey)
	for _, rows in pairs(StevioUI_Settings.pages.module.rows.frames) do
		for _, row in ipairs(rows) do
			if row.shown and row.item.metaKey == metaKey then
				return row
			end
		end
	end
end
Window.Open("module", "group")
check(#Rows("slider") > 0, "slider rows")
local row = RowOf("group.nameFontSize")
check(row, "name font size row")
row.control.onChange(12)
check(StevioUIConfig.values["config/group/nameFontSize"] == 12, "override saved")
check(ns.config.group.nameFontSize == 12, "live config changed")
local count, names = UI.PendingChanges()
check(count == 1 and names[1] == "Namens-Schriftgröße", "reload bar lists it: " .. tostring(names[1]))
check(StevioUI_Settings.reload.shown, "reload bar shown")
row = RowOf("group.nameFontSize")
check(row.reset.shown and row.default.text:find("11"), "default line")
row.reset.scripts.OnClick(row.reset)
check(StevioUIConfig.values["config/group/nameFontSize"] == nil, "override removed")
check(UI.PendingChanges() == 0, "back at the start value")
print("rows ok")

-- Positions, switches, lists and colors.
row = RowOf("layout.group")
row.control.onChange({ y = 200 })
check(StevioUIConfig.values["layout/group/y"] == 200, "position saved")
row = RowOf("layout.group")
row.control.anchor.onChange("TOP")
check(ns.layout.group.point == "TOP", "anchor saved")
UI.Reset(RowOf("layout.group").item)
check(
	StevioUIConfig.values["layout/group/y"] == nil and StevioUIConfig.values["layout/group/point"] == nil,
	"position reset"
)
Window.Open("module", "actionBars")
row = RowOf("actionBars.sets")
row.control.add.scripts.OnClick(row.control.add)
check(#ns.config.actionBars.sets == 3, "list grew")
row = RowOf("actionBars.sets")
row.control.rows:Get(3).remove.scripts.OnClick()
check(#ns.config.actionBars.sets == 2 and StevioUIConfig.values["config/actionBars/sets"] == nil, "list shrank")
Window.Open("module", "chat")
row = RowOf("chat.main.channels")
row.control.chips:Get(1).scripts.OnClick(row.control.chips:Get(1))
check(next(StevioUIConfig.values) ~= nil, "flag saved")
StevioUI_Settings.pages.module.advanced.toggle.scripts.OnClick()
check(RowOf("chat.fadeTime"), "advanced rows shown")
StevioUI_Settings.pages.module.menu.scripts.OnClick(StevioUI_Settings.pages.module.menu)
StaticPopupDialogs.STEVIOUI_RESET_MODULE.OnAccept(nil, Pages.Module("chat"))
check(next(StevioUIConfig.values) == nil, "module reset: " .. tostring(next(StevioUIConfig.values)))
Window.Open("module", "fastLoot")
StevioUI_Settings.pages.module.enabled.onChange(false)
check(ns.config.fastLoot.enabled == false and StevioUIConfig.values["config/fastLoot/enabled"] == false, "module off")
Window.Open("start")
for _, chip in ipairs(StevioUI_Settings.pages.start.chips) do
	chip.scripts.OnClick(chip)
end
StevioUI_Settings.pages.start.themeCards[1].scripts.OnClick(StevioUI_Settings.pages.start.themeCards[1])
check(ns.config.style.theme == "dusk", "theme picked")
Window.Open("module", "style")
check(RowOf("style.themes.dusk.accent"), "the picked theme's colors")
print("changes ok")

-- Keys: Ctrl+F searches, Escape closes; none are taken in combat.
_G.IsControlKeyDown = function()
	return true
end
StevioUI_Settings.scripts.OnKeyDown(StevioUI_Settings, "F")
_G.IsControlKeyDown = function() end
StevioUI_Settings.scripts.OnKeyDown(StevioUI_Settings, "ESCAPE")
check(not StevioUI_Settings.shown, "escape closes")
registered.PLAYER_REGEN_DISABLED()
registered.PLAYER_REGEN_ENABLED()
Window.Open()
print("keys ok")

-- Search: typing shows the results, a chip filters, values change in the
-- result rows, Escape empties the search.
local function Type(text)
	local edit = StevioUI_Settings.search.edit
	edit:SetText(text)
	edit.scripts.OnTextChanged(edit, true)
end
Type("abstand")
local results = StevioUI_Settings.pages.search
check(results.shown and results.title.text:find("Treffer"), "results shown: " .. results.title.text)
check(not StevioUI_Settings.pages.module.shown, "page hidden while searching")
results.chips:Get(2).scripts.OnClick(results.chips:Get(2))
local card = results.cards:Get(1)
local first = card.rows.frames.slider[1]
check(first and first.shown, "a slider row in the results")
first.control.onChange(first.item.meta.max)
check(next(StevioUIConfig.values) ~= nil, "changed from the results")
UI.Reset(first.item)
Type("xyzzy")
check(results.title.text:find("^0"), "nothing found")
local edit = StevioUI_Settings.search.edit
edit.scripts.OnEscapePressed(edit)
check(edit.text == "" and Window.state.search == "", "escape empties the search")
print("search ok")

print("settings window tests passed")
