local _, ns = ...

local config = ns.config.chat
local badgeStyle = ns.config.style.badge
local C = ns.ChatInternal

-- Edge badge at the left screen edge: toggles the chat and lights up a segment
-- per category (whisper, group, guild) while the chat is hidden and unread.

local badge

function C.UpdateBadge()
	for _, segment in ipairs(config.badge.segments) do
		local texture = badge.segments[segment.category]
		if not C.hidden then
			texture:SetColorTexture(unpack(badgeStyle.shownColor))
		elseif C.store:HasUnread(segment.category) then
			local info = ChatTypeInfo[segment.chatType]
			if info and info.r then
				texture:SetColorTexture(info.r, info.g, info.b, 1)
			else
				texture:SetColorTexture(unpack(segment.fallbackColor))
			end
		else
			texture:SetColorTexture(unpack(badgeStyle.hiddenColor))
		end
	end
end

function C.CreateBadge()
	local button = CreateFrame("Button", "StevioUI_ChatBadge", UIParent)
	local segments, gap = config.badge.segments, config.badge.segmentGap
	button:SetSize(badgeStyle.width, badgeStyle.height)
	ns.SetPoint(button, ns.layout.chatBadge)

	local segmentHeight = (badgeStyle.height - gap * (#segments - 1)) / #segments
	button.segments = {}
	for index, segment in ipairs(segments) do
		local frame = CreateFrame("Frame", nil, button)
		frame:SetSize(badgeStyle.width, segmentHeight)
		frame:SetPoint("TOP", 0, -(index - 1) * (segmentHeight + gap))
		ns.CreateBorder(frame)
		local texture = frame:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints()
		button.segments[segment.category] = texture
	end
	button:SetScript("OnClick", ns.ToggleChat)
	badge = button
end
