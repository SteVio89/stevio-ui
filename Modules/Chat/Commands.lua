local _, ns = ...

local C = ns.ChatInternal
local Parse = ns.ChatParse

-- Slash commands typed into the channel view's input. Blizzard only runs
-- protected commands (/cast, /target, /focus, ...) from its own input box on a
-- key press, so those are handed over to it, pre-filled: Enter runs them. So
-- are Blizzard's own other commands (/who, /roll, /macro, ...): run from addon
-- code they would open Blizzard panels tainted, which can block actions later.
-- Chat (/p, /w Bob, /r, /1, ...), emotes and addon commands (/sui, ...) run
-- right here, without touching the state of Blizzard's input box.

-- Opens Blizzard's input box (under the channel view) with `text`.
local function HandOff(text)
	ChatFrameUtil.OpenChat(text)
end

local function IsBattleNetName(name)
	return BNet_GetBNetIDAccount(name) ~= nil
end

-- Also remembered as last told target, so Blizzard's input box offers it too.
local function Whisper(target, message, isBattleNet)
	if isBattleNet then
		local bnetID = BNet_GetBNetIDAccount(target)
		if bnetID then
			C_BattleNet.SendWhisper(bnetID, message)
			ChatFrameUtil.SetLastToldTarget(target, "BN_WHISPER")
		end
	else
		C_ChatInfo.SendChatMessage(message, "WHISPER", nil, target)
		ChatFrameUtil.SetLastToldTarget(target, "WHISPER")
	end
end

local function SendToChannel(channel, message)
	local id = GetChannelName(tonumber(channel) or channel)
	if id and id > 0 then
		C_ChatInfo.SendChatMessage(message, "CHANNEL", nil, id)
		return true
	end
	return false
end

-- Chat-type commands (/p, /g, /w Bob, /r, /1, /c General, ...) speak in that
-- chat. Returns false when there is nothing to send yet (e.g. "/p" alone),
-- which leaves the command to Blizzard's input box.
local function RunChatType(chatType, message)
	if chatType == "WHISPER" or chatType == "SMART_WHISPER" then
		-- WHISPER (/tell to a character) never means a Battle.net friend.
		local target, text, isBattleNet = Parse.WhisperTarget(message, chatType == "SMART_WHISPER" and IsBattleNetName)
		if not target then
			return false
		end
		Whisper(target, text, isBattleNet)
	elseif chatType == "REPLY" then
		local lastTell, lastTellType = ChatFrameUtil.GetLastTellTarget()
		if not lastTell or message == "" then
			return false
		end
		Whisper(lastTell, message, lastTellType == "BN_WHISPER")
	elseif chatType == "GUILD_DISCORD" then
		-- Needs a Discord login, which Blizzard's input box checks first.
		return false
	elseif chatType == "CHANNEL" then
		local channel, text = Parse.FirstWord(message)
		return text ~= nil and SendToChannel(channel, text)
	elseif message == "" then
		return false
	else
		C_ChatInfo.SendChatMessage(message, chatType)
	end
	return true
end

-- Runs `text` (a line starting with "/"); unknown commands get a hint in System.
function C.RunCommand(text)
	local command, message = Parse.Command(text)
	if not command then
		return
	end
	if IsSecureCmd(command) then
		HandOff(text)
		return
	end

	ChatFrameUtil.ImportAllListsToHash()
	local kind, value = Parse.Classify(command, {
		chatTypes = hash_ChatTypeInfoList,
		chatTypeInfo = ChatTypeInfo,
		slashCommands = hash_SlashCmdList,
		isSecure = issecurevariable,
		emotes = hash_EmoteTokenList,
	})
	if kind == "channel" then
		if message == "" or not SendToChannel(value, message) then
			HandOff(text)
		end
	elseif kind == "chatType" then
		if not RunChatType(value, message) then
			HandOff(text)
		end
	elseif kind == "addon" then
		value(message, DEFAULT_CHAT_FRAME.editBox)
	elseif kind == "emote" then
		C_ChatInfo.PerformEmote(value, message ~= "" and message or nil)
	else
		-- Blizzard would answer into its hidden chat window, so the hint goes to System.
		ns.Print(ns.T("Unknown command: %s", "Unbekannter Befehl: %s"):format(command:lower()))
	end
end
