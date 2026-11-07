local _, ns = ...

local config = ns.config.chat
local C = ns.ChatInternal

-- Lines Blizzard writes into its own chat window without a chat event (it
-- answers these game events itself). The known ones are worded the same way
-- here and go to the channel named in config.notices; lines other code writes
-- straight into Blizzard's window are not picked up.

local function Add(def, text, colorType)
	if not text or text == "" then
		return
	end
	C.Receive(def, def.key, def, { time = time(), text = text, colorType = colorType })
end

local function AddSystem(text)
	Add(config.notices.system, text, "SYSTEM")
end

-- Level-up text, a link to the level-up summary unless the game rules turn those off.
local function OnLevelChanged(_, oldLevel, newLevel, real)
	if not real or oldLevel == 0 or newLevel == 0 or newLevel <= oldLevel then
		return
	end
	local noLink = C_PlayerInfo.IsPlayerNPERestricted and C_PlayerInfo.IsPlayerNPERestricted()
	if C_GameRules and C_GameRules.IsGameRuleActive and Enum.GameRule and Enum.GameRule.ChatLinkLevelToastsDisabled then
		noLink = noLink or C_GameRules.IsGameRuleActive(Enum.GameRule.ChatLinkLevelToastsDisabled)
	end
	local text = noLink and format(LEVEL_UP_NO_LINK, newLevel) or format(LEVEL_UP, newLevel, newLevel)
	Add(config.notices.levelUp, text, "SYSTEM")
end

-- /played only counts as unread: addons also ask for it silently at login.
local function OnTimePlayed(_, totalTime, levelTime)
	for _, pair in ipairs({ { TIME_PLAYED_TOTAL, totalTime }, { TIME_PLAYED_LEVEL, levelTime } }) do
		local d, h, m, s = ChatFrameUtil.TimeBreakDown(pair[2])
		AddSystem(format(pair[1], format(TIME_DAYHOURMINUTESECOND, d, h, m, s)))
	end
end

local function OnGuildMotd(_, motd)
	if motd and motd ~= "" then
		Add(config.notices.guildMotd, format(GUILD_MOTD_TEMPLATE, motd), "GUILD")
	end
end

-- Worded like Blizzard's chat (its helpers for this are local to its own file).
local function RegionalChatText(available)
	local mentor = DoesActivePlayerHaveMentorStatus()
	if available then
		return mentor and NPEV2_CHAT_AVAILABLE or NPEV2_REGIONAL_CHAT_AVAILABLE
	end
	return mentor and NPEV2_CHAT_UNAVAILABLE or NPEV2_REGIONAL_CHAT_UNAVAILABLE
end

local function OnRegionalStatus(_, isServiceAvailable)
	AddSystem(RegionalChatText(isServiceAvailable))
end

local function OnChatSuppressed()
	local message
	if C_SocialRestrictions.IsAgeVerificationRestricted() then
		message = C_SocialRestrictions.IsAgeVerificationRestrictedMinor() and AGE_RESTRICTED_CHAT_MINOR
			or AGE_RESTRICTED_CHAT_UNVERIFIED
	else
		local hyperlink = ("|Haadcopenconfig|h[%s]"):format(RESTRICT_CHAT_CONFIG_HYPERLINK)
		message = RESTRICT_CHAT_CHATFRAME_FORMAT:format(
			RESTRICT_CHAT_MESSAGE_SUPPRESSED,
			LIGHTBLUE_FONT_COLOR:WrapTextInColorCode(hyperlink)
		)
	end
	AddSystem(message)
end

local handlers = {
	PLAYER_LEVEL_CHANGED = OnLevelChanged,
	TIME_PLAYED_MSG = OnTimePlayed,
	GUILD_MOTD = OnGuildMotd,
	CHAT_SERVER_DISCONNECTED = function()
		AddSystem(CHAT_SERVER_DISCONNECTED_MESSAGE)
	end,
	CHAT_SERVER_RECONNECTED = function()
		AddSystem(CHAT_SERVER_RECONNECTED_MESSAGE)
	end,
	BN_CONNECTED = function(_, suppressNotification)
		if not suppressNotification then
			AddSystem(BN_CHAT_CONNECTED)
		end
	end,
	BN_DISCONNECTED = function(_, _, suppressNotification)
		if not suppressNotification then
			AddSystem(BN_CHAT_DISCONNECTED)
		end
	end,
	CHAT_REGIONAL_STATUS_CHANGED = OnRegionalStatus,
	CHAT_REGIONAL_SEND_FAILED = function()
		AddSystem(RegionalChatText(false))
	end,
	NOTIFY_CHAT_SUPPRESSED = OnChatSuppressed,
}

-- A notice failing (a global this client lacks) must not break the others.
function C.SetupNotices()
	for event, handler in pairs(handlers) do
		ns:RegisterEvent(event, function(...)
			local ok, err = pcall(handler, ...)
			if not ok then
				geterrorhandler()(err)
			end
		end)
	end
end
