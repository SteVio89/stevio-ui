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
		local glow = badge.glows[segment.category]
		if not C.hidden then
			texture:SetColorTexture(unpack(badgeStyle.shownColor))
			glow:Hide()
		elseif C.store:HasUnread(segment.category) then
			local r, g, b, a = C.TypeColor(segment.chatType, segment.fallbackColor)
			texture:SetColorTexture(r, g, b, a or 1)
			glow:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0.5), CreateColor(r, g, b, 0))
			glow:Show()
		else
			texture:SetColorTexture(unpack(badgeStyle.hiddenColor))
			glow:Hide()
		end
	end
end

function C.CreateBadge()
	local button = ns.CreateEdgeBadge("StevioUI_ChatBadge", ns.layout.chatBadge, ns.ToggleChat)
	local segments, gap = config.badge.segments, config.badge.segmentGap

	local segmentHeight = (badgeStyle.height - gap * (#segments - 1)) / #segments
	button.segments, button.glows = {}, {}
	for index, segment in ipairs(segments) do
		local frame = CreateFrame("Frame", nil, button)
		frame:SetSize(badgeStyle.width, segmentHeight)
		frame:SetPoint("TOP", 0, -(index - 1) * (segmentHeight + gap))
		ns.CreateBorder(frame)
		local texture = frame:CreateTexture(nil, "ARTWORK")
		texture:SetAllPoints()
		button.segments[segment.category] = texture
		-- The badge sits on the left edge, so the glow fades to the right.
		local glow = frame:CreateTexture(nil, "BACKGROUND")
		glow:SetTexture(ns.config.style.texture)
		glow:SetPoint("TOPLEFT")
		glow:SetPoint("BOTTOMLEFT")
		glow:SetWidth(badgeStyle.glowWidth)
		glow:Hide()
		button.glows[segment.category] = glow
	end
	badge = button
end
