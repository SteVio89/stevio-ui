-- Run with: lua tests/chat_blizzard_test.lua  (from the repo root)
-- Blizzard's input box under the channel view shows only while it is typed
-- into, not whenever the chat is open (#88).
local check, loadAddonFile = dofile("tests/helpers.lua")

local function Stub() end

-- hooksecurefunc on a widget method or a table function: the hook runs after it.
_G.hooksecurefunc = function(target, name, hook)
	if type(target) == "string" then
		return
	end
	local original = target[name]
	target[name] = function(...)
		original(...)
		hook(...)
	end
end

local function Widget()
	local widget = { alpha = 1, mouse = true, wheel = true }
	function widget:SetAlpha(alpha)
		self.alpha = alpha
	end
	function widget:EnableMouse(enabled)
		self.mouse = enabled
	end
	function widget:EnableMouseWheel(enabled)
		self.wheel = enabled
	end
	return widget
end

local editBox = Widget()
local chatFrame = Widget()
chatFrame.editBox = editBox
chatFrame.buttonFrame = Widget()
function chatFrame.GetName()
	return "ChatFrame1"
end
_G.CHAT_FRAMES = { "ChatFrame1" }
_G.ChatFrame1 = chatFrame
_G.ChatFrame1Tab = Widget()
_G.GeneralDockManager = Widget()
_G.DEFAULT_CHAT_FRAME = chatFrame

-- What Blizzard's activation does to the box and the global, in its order.
_G.ChatFrameUtil = {
	ActivateChat = function(box)
		_G.ACTIVE_CHAT_EDIT_BOX = box
		box:SetAlpha(1)
	end,
	DeactivateChat = function(box)
		_G.ACTIVE_CHAT_EDIT_BOX = nil
		box:SetAlpha(0.35)
	end,
}
_G.Enum = {
	EditModeSystem = { ChatFrame = 1 },
	EditModeChatFrameSetting = { WidthHundreds = 1, WidthTensAndOnes = 2, HeightHundreds = 3, HeightTensAndOnes = 4 },
}

local ns = {
	config = { chat = { showBlizzardChat = false, height = 300 } },
	layout = { chat = { point = "TOPLEFT" } },
	ChatInternal = { state = {}, ui = {} },
	SetEditModeSystem = Stub,
	KeepHidden = Stub,
	PinFrame = Stub,
}
local C = ns.ChatInternal
C.ChatWidth = function()
	return 500
end
C.Pin = Stub
C.Update = function()
	C.ApplyBlizzardVisibility()
end
loadAddonFile("Modules/Chat/Blizzard.lua", ns)

C.hidden = true
C.SetupBlizzardChat()
C.ApplyBlizzardVisibility(true)
check(editBox.alpha == 0 and not editBox.mouse, "hidden chat: input box invisible")

C.hidden = false
C.ApplyBlizzardVisibility()
check(editBox.alpha == 0 and not editBox.mouse, "open chat, not typing: input box stays invisible")

ChatFrameUtil.ActivateChat(editBox)
check(C.state.typing, "Enter counts as typing")
check(editBox.alpha == 1 and editBox.mouse, "typing into it shows the input box")

ChatFrameUtil.DeactivateChat(editBox)
check(editBox.alpha == 0 and not editBox.mouse, "sent: the input box hides again")

print("chat blizzard tests passed")
