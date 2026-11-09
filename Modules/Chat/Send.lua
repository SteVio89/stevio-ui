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

function C.Send(text)
	-- Slash commands run in any channel, read-only ones included (see Commands.lua).
	if text:sub(1, 1) == "/" then
		C.RunCommand(text)
		return
	end
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
		if bnetID then
			C_BattleNet.SendWhisper(bnetID, text)
		end
	elseif channel.kind == "whisper" then
		C_ChatInfo.SendChatMessage(text, "WHISPER", nil, channel.target)
	elseif channel.channelIndex then
		C_ChatInfo.SendChatMessage(text, "CHANNEL", nil, channel.channelIndex)
	else
		C_ChatInfo.SendChatMessage(text, channel.chatType)
	end
end
