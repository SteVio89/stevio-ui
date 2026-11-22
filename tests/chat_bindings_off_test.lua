-- Run with: lua tests/chat_bindings_off_test.lua  (from the repo root)
-- The chat key bindings run even when the chat module is off or failed to
-- enable; they must do nothing then instead of raising an error.
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = {
	config = { chat = { main = { enabled = true, key = "main" } } },
	ChatInternal = { state = {}, ui = {} },
	RegisterModule = function()
		return {}
	end,
	RegisterModuleCommand = function() end,
}
loadAddonFile("Modules/Chat/Chat.lua", ns)

for _, name in ipairs({ "ToggleChat", "FocusChatInput", "NextChatChannel", "PreviousChatChannel" }) do
	local ok, err = pcall(ns[name])
	check(ok, name .. " without an enabled chat: " .. tostring(err))
end
print("chat bindings off tests passed")
