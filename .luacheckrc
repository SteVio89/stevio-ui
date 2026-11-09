-- luacheck config: WoW's Lua 5.1 with the game API as read-only globals.
std = "lua51"
max_line_length = false -- StyLua keeps lines in shape
self = false -- methods that ignore `self` are fine

-- The game API is far too large to list; reading unknown globals is allowed,
-- writing them is not, except for the ones below.
allow_defined_top = false
ignore = { "113" } -- accessing an undefined (game API) global

globals = {
	-- SavedVariables (stevio-ui.toc)
	"StevioUIState",
	"StevioUIConfig",
	"StevioUIExport",
	"StevioUIDebug",
	"StevioUIErrors",
	"StevioUIChatHistory",
	"StevioUIActionSets",
	-- Reached from Bindings.xml
	"StevioUI",
	-- Read by other addons placing minimap buttons
	"GetMinimapShape",
	-- Game tables addons add entries to
	"SlashCmdList",
	"StaticPopupDialogs",
	"UISpecialFrames",
	-- Slash command and keybinding names (Bindings.xml)
	"SLASH_STEVIOUI1",
	"BINDING_HEADER_STEVIOUI",
	"BINDING_NAME_STEVIOUI_TOGGLE_TRACKER",
	"BINDING_NAME_STEVIOUI_TOGGLE_CHAT",
	"BINDING_NAME_STEVIOUI_CHAT_INPUT",
	"BINDING_NAME_STEVIOUI_CHAT_NEXT",
	"BINDING_NAME_STEVIOUI_CHAT_PREVIOUS",
	"BINDING_NAME_STEVIOUI_QUICKJUMP",
	"BINDING_NAME_STEVIOUI_ACTIONSET_NEXT",
}
