local _, ns = ...

local C = ns.ChatInternal

-- Sends what is typed into the channel view's input to the selected channel.

-- The account id may change between sessions, so channels with a BattleTag
-- look it up again in the friend list; a friend no longer in the list gets
-- nothing rather than whoever holds the old id now. `numFriends()` and
-- `friendInfo(index)` read the friend list.
function C.CurrentBattleNetID(channel, numFriends, friendInfo)
	if not channel.battleTag then
		return channel.bnetID
	end
	for index = 1, numFriends() do
		local info = friendInfo(index)
		if info and info.battleTag == channel.battleTag then
			channel.bnetID = info.bnetAccountID
			return info.bnetAccountID
		end
	end
end

-- Whispers that went out without a trace (#41): the server echoes every
-- whisper it delivers (CHAT_MSG_WHISPER_INFORM, ..._BN_WHISPER_INFORM). A
-- whisper without an echo after WATCH_SECONDS gets a line saying so, with
-- what the client told us about it, so a test in game shows where it fails.
local WATCH_SECONDS = 3

-- Whispers sent and not echoed yet, oldest first: { key, target, lockdown,
-- error, blocked }.
local watched = {}

-- Why a whisper to `target` didn't go out, from what was seen while sending
-- it (`attempt`: lockdown, error, blocked, missing; see C.Whisper): the line
-- shown in its channel.
function C.WhisperFailure(target, attempt)
	local reasons = {}
	if attempt.missing then
		reasons[#reasons + 1] = attempt.missing
	end
	if attempt.error then
		reasons[#reasons + 1] = ns.T("error: %s", "Fehler: %s"):format(attempt.error)
	end
	if attempt.blocked then
		reasons[#reasons + 1] = ns.T("blocked by the client: %s", "vom Client blockiert: %s"):format(attempt.blocked)
	end
	if attempt.lockdown then
		reasons[#reasons + 1] = ns.T("chat lockdown", "Chat-Sperre")
	end
	if attempt.restricted then
		reasons[#reasons + 1] = ns.T("addon chat restricted on this realm", "Addon-Chat auf diesem Realm gesperrt")
	end
	if #reasons == 0 then
		reasons[1] = ns.T("no answer from the server", "keine Antwort vom Server")
	end
	return ns.T("Whisper to %s was not sent (%s)", "Flüstern an %s nicht gesendet (%s)")
		:format(target or "?", table.concat(reasons, ", "))
end

-- Shows `text` as a system line in channel `key`, or in System when there is
-- no such channel.
local function Report(key, text)
	local channel = key and C.store:Get(key)
	if not channel then
		ns.Print(text)
		return
	end
	local entry = { time = time(), text = text, colorType = "SYSTEM" }
	C.store:Add(key, channel, entry, false)
	if C.state.selected == key then
		C.ShowEntry(channel, ns.ChatHistory.PreviousTimed(channel.messages, #channel.messages), entry)
	end
end

local function Lockdown()
	return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

local function Restricted()
	return C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted()
		or false
end

-- Sends a whisper with `send()` and watches for its echo; `key` is the channel
-- it was written in (nil for /w typed elsewhere), `target` who it goes to.
-- `missing` names why there was no one to send to; it is reported right away.
function C.Whisper(key, target, send, missing)
	local attempt = { key = key, target = target, lockdown = Lockdown(), restricted = Restricted() }
	if missing then
		attempt.missing = missing
		Report(key, C.WhisperFailure(target, attempt))
		return
	end
	watched[#watched + 1] = attempt
	local ok, err = pcall(send)
	if not ok then
		attempt.error = tostring(err)
	end
	C_Timer.After(WATCH_SECONDS, function()
		for i, waiting in ipairs(watched) do
			if waiting == attempt then
				table.remove(watched, i)
				Report(key, C.WhisperFailure(target, attempt))
				return
			end
		end
	end)
end

-- The echo of a whisper we sent: the oldest one watched went out. Names can't
-- be compared (secret during the chat lockdown, with or without the realm).
function C.WhisperEchoed()
	table.remove(watched, 1)
end

-- ADDON_ACTION_BLOCKED / ADDON_ACTION_FORBIDDEN for us while whispers are
-- watched: the client refused a call, which is then named in their line.
function C.OnActionBlocked(_, addon, action)
	if addon == ns.name and #watched > 0 then
		watched[#watched].blocked = tostring(action)
	end
end

function C.Send(text)
	-- Slash commands run in any channel, read-only ones included (see Commands.lua).
	if text:sub(1, 1) == "/" then
		C.RunCommand(text)
		return
	end
	text = C.SubstituteTags(text)
	local channel = C.Selected()
	if channel and C.IsMain(channel.key) then
		channel = C.MainTarget()
	end
	-- "Other" mixes several channels and "System" has no sender: no one to answer to.
	if not channel or text == "" or channel.readOnly then
		return
	end
	if channel.clubId then
		C_Club.SendMessage(channel.clubId, channel.streamId, text)
	elseif channel.bnetID or channel.battleTag or channel.chatType == "BN_WHISPER" then
		local bnetID = C.CurrentBattleNetID(channel, BNGetNumFriends, C_BattleNet.GetFriendAccountInfo)
		local missing = not bnetID and ns.T("not in your friend list", "nicht in der Freundesliste")
		C.Whisper(channel.key, C.Label(channel), function()
			C_BattleNet.SendWhisper(bnetID, text)
		end, missing)
	elseif channel.kind == "whisper" then
		-- Sent without the realm, which WoW Forever refuses (see History.SendName).
		local name = channel.target and ns.ChatHistory.SendName(channel.target)
		local missing = not name and ns.T("no character name", "kein Charaktername")
		C.Whisper(channel.key, name or C.Label(channel), function()
			C_ChatInfo.SendChatMessage(text, "WHISPER", nil, name)
		end, missing)
	elseif channel.channelIndex then
		C_ChatInfo.SendChatMessage(text, "CHANNEL", nil, ns.ChatHistory.ChannelNumber(channel, GetChannelName))
	else
		C_ChatInfo.SendChatMessage(text, channel.chatType)
	end
end
