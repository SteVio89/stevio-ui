-- Run with: lua tests/chat_visibility_test.lua  (from the repo root)
-- When the chat hides by itself: only after popping up for a message, never
-- once the player opened it or did something with it (#37).
local check, loadAddonFile = dofile("tests/helpers.lua")

-- Timers fire only when the test says so.
local timers = {}
_G.C_Timer = {
	NewTimer = function(_, callback)
		local timer = { callback = callback }
		function timer:Cancel()
			self.cancelled = true
		end
		timers[#timers + 1] = timer
		return timer
	end,
}
local function FireTimers()
	local due = timers
	timers = {}
	for _, timer in ipairs(due) do
		if not timer.cancelled then
			timer.callback()
		end
	end
end

local function Stub() end
local function NotShown()
	return false
end
local ns = {
	config = { chat = { autoShowDuration = 8, main = { enabled = true, key = "main" } } },
	ChatInternal = { state = {} },
	RegisterModule = function()
		return {}
	end,
}
local C = ns.ChatInternal
local state = C.state
local channel = { key = "guild", messages = { {} }, unread = 0 }
C.Selected = function()
	return state.selected and channel
end
C.RenderMessages = Stub
C.ShowChannel = function(key)
	state.selected = key
	return channel
end
C.Attended = function()
	return state.manual or state.typing
end
C.MarkRead, C.RefreshSidebar, C.UpdateBadge, C.ApplyBlizzardVisibility = Stub, Stub, Stub, Stub
C.ui = {
	frame = { SetShown = Stub, IsVisible = NotShown, IsMouseOver = NotShown },
	input = { ClearFocus = Stub, SetFocus = Stub, HasFocus = NotShown },
	copy = { IsShown = NotShown },
}
loadAddonFile("Modules/Chat/Chat.lua", ns)

local function Reset()
	state.manual, state.typing, state.autoTimer, state.selected = false, false, nil, "guild"
	state.peekReturn = nil
	timers = {}
	C.Update()
end

-- A message pops up the hidden chat and it hides again by itself.
Reset()
check(C.hidden, "starts hidden")
C.StartAutoTimer(8)
C.Update()
check(not C.hidden, "message pops up the chat")
FireTimers()
check(C.hidden, "popped-up chat hides by itself")

-- Opened with the toggle key: no message hides it.
Reset()
ns.ToggleChat()
C.StartAutoTimer(8)
C.Update()
FireTimers()
check(not C.hidden, "chat opened by hand stays open")
ns.ToggleChat()
check(C.hidden, "toggled closed")

-- Popped up for a message: the toggle key hides it right away (#50).
Reset()
C.StartAutoTimer(8)
C.Update()
ns.ToggleChat()
check(C.hidden and not state.autoTimer, "toggle hides a popped-up chat")
ns.ToggleChat()
check(not C.hidden and state.manual, "and opens it again by hand")

-- The chat input key on a popped-up chat keeps it open.
Reset()
C.StartAutoTimer(8)
C.Update()
ns.FocusChatInput()
FireTimers()
check(not C.hidden and state.manual, "focusing the input pins a popped-up chat")

-- Popped up, then the player picks a channel or starts typing: stays open.
Reset()
C.StartAutoTimer(8)
C.Update()
C.Select("party")
FireTimers()
check(not C.hidden, "picking a channel in the popped-up chat keeps it open")

Reset()
C.StartAutoTimer(8)
C.Update()
C.Pin() -- what typing (input focus, Enter, a slash command) does
state.typing = true
C.Update()
state.typing = false -- the line is sent
C.Update()
FireTimers()
check(not C.hidden, "typing into the popped-up chat keeps it open after sending")

-- Picking a channel of the hidden chat (a key binding) doesn't open it.
Reset()
C.Select("party")
check(C.hidden and not state.manual, "selecting in the hidden chat doesn't open it")

-- With no channel open yet (login) the chat starts on Main (#65).
Reset()
state.selected = nil
C.Update()
check(state.selected == "main", "the chat starts on Main")

-- A message peeks at its channel in the hidden chat; once the chat hides
-- again, the channel open before comes back (#65: login left it on System).
local function PeekAt(key)
	C.Peek(key)
	C.StartAutoTimer(8)
	C.Update()
end

Reset()
PeekAt("system")
check(not C.hidden and state.selected == "system", "the popped-up chat shows the message's channel")
PeekAt("party")
check(state.selected == "party", "a later message peeks at its channel")
FireTimers()
check(C.hidden and state.selected == "guild", "hidden again, the channel open before comes back")
ns.ToggleChat()
check(state.selected == "guild", "opened by hand on the channel open before")

-- Closing the popped-up chat with the toggle key ends the peek as well.
Reset()
PeekAt("system")
ns.ToggleChat()
check(C.hidden and state.selected == "guild", "toggled closed: the channel open before comes back")

-- Opened or picked in during a peek: the chat stays on that channel.
Reset()
PeekAt("system")
ns.ToggleChat()
ns.ToggleChat()
check(not C.hidden and state.selected == "guild", "toggled closed and open again: no peek left")
ns.ToggleChat()

Reset()
PeekAt("system")
ns.FocusChatInput()
ns.ToggleChat()
check(C.hidden and state.selected == "system", "typing into the peeked channel keeps it")

Reset()
PeekAt("system")
C.Select("party")
FireTimers()
ns.ToggleChat()
ns.ToggleChat()
check(state.selected == "party", "a channel picked during a peek stays picked")

-- A focus channel opened in the chat the player opened is no peek.
Reset()
ns.ToggleChat()
PeekAt("system")
ns.ToggleChat()
check(C.hidden and state.selected == "system", "focus channel in the open chat stays")

print("chat_visibility_test: ok")
