local _, ns = ...

-- Generic source for any open window (merchant, character, bags, mail, ...):
-- instead of knowing each window, it walks the window's frame tree and labels
-- every visible, clickable button. Windows are often open while playing, so
-- this source is only active after the leader key, which cycles through them.

local QuickJump = ns.QuickJump

-- Windows with a dedicated source that labels them better.
local DEDICATED = {
	GossipFrame = true,
	QuestFrame = true,
	TaxiFrame = true,
	FlightMapFrame = true,
	StevioUI_TaxiList = true,
}

local STRATA_RANK = {
	BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8,
}

local MAX_CONTAINER_FRAMES = 13

local activePanel
local hookedPanels = {}

local function OpenPanels()
	local seen, panels = {}, {}
	local function Add(frame)
		if frame and not seen[frame] and not frame:IsForbidden() and frame:IsVisible() and not DEDICATED[frame:GetName() or ""] then
			seen[frame] = true
			panels[#panels + 1] = frame
		end
	end

	for name in pairs(UIPanelWindows) do
		Add(_G[name])
	end
	for _, name in ipairs(UISpecialFrames) do
		Add(_G[name])
	end
	-- Bags close through their own logic and aren't in either registry.
	Add(ContainerFrameCombinedBags)
	for i = 1, MAX_CONTAINER_FRAMES do
		Add(_G["ContainerFrame" .. i])
	end

	-- Topmost first, so the first leader press lands on what's in front.
	table.sort(panels, function(a, b)
		local aRank, bRank = STRATA_RANK[a:GetFrameStrata()] or 0, STRATA_RANK[b:GetFrameStrata()] or 0
		if aRank ~= bRank then
			return aRank > bRank
		end
		return a:GetFrameLevel() > b:GetFrameLevel()
	end)
	return panels
end

local function IsScrollBar(frame)
	return frame.ScrollStepInDirection ~= nil
end

local function IsCloseButton(frame)
	local parentKey = frame.GetParentKey and frame:GetParentKey()
	return parentKey == "CloseButton" or (frame:GetName() or ""):find("CloseButton") ~= nil
end

-- Scroll children extend beyond what's visible, and their off-screen buttons
-- still count as visible to the API. So buttons inside a clipping region must
-- be centred inside it; elsewhere (e.g. side tabs hanging outside a window)
-- any visible button counts.
local function IsInside(frame, region)
	local x, y = frame:GetCenter()
	local left, bottom, width, height = region:GetRect()
	return x and left and x >= left and x <= left + width and y >= bottom and y <= bottom + height
end

-- Anything that reacts to a click or mouse press. Scroll frames are skipped:
-- their mouse handlers act on the cursor position (e.g. the map surface), which
-- a label can't provide.
local function IsClickable(frame)
	if not frame:IsMouseEnabled() or frame:IsObjectType("ScrollFrame") then
		return false
	end
	return frame:GetScript("OnClick") ~= nil or frame:GetScript("OnMouseUp") ~= nil
		or frame:GetScript("OnMouseDown") ~= nil
end

local function ClipsChildren(frame)
	return frame:IsObjectType("ScrollFrame") or frame:DoesClipChildren()
end

local function CollectButtons(frame, clipRegion, result)
	for _, child in ipairs({ frame:GetChildren() }) do
		if not child:IsForbidden() and child:IsVisible() then
			if IsScrollBar(child) then
				result.scrollBar = result.scrollBar or child
			else
				if IsClickable(child) and not IsCloseButton(child)
					and (not clipRegion or IsInside(child, clipRegion)) then
					result[#result + 1] = child
				end
				CollectButtons(child, ClipsChildren(child) and child or clipRegion, result)
			end
		end
	end
end

local function CollectPanel()
	local result = {}
	CollectButtons(activePanel, nil, result)
	local scrollBar = result.scrollBar
	result.scrollBar = nil
	return QuickJump.SortByPosition(result), scrollBar
end

local panelSource = {
	name = "panel",
	priority = 25,
	IsOpen = function()
		if activePanel and not activePanel:IsVisible() then
			activePanel = nil
		end
		return activePanel ~= nil
	end,
	Collect = function()
		return (CollectPanel())
	end,
	GetScrollBar = function()
		return select(2, CollectPanel())
	end,
	OnFinished = function()
		activePanel = nil
	end,
}

-- Each leader press moves to the next open window; past the last one, labels end.
function ns.CyclePanelLabels()
	local panels = OpenPanels()
	local nextPanel = panels[1]
	if activePanel then
		nextPanel = nil
		for index, panel in ipairs(panels) do
			if panel == activePanel then
				nextPanel = panels[index + 1]
			end
		end
	end

	activePanel = nextPanel
	if activePanel and not hookedPanels[activePanel] then
		hookedPanels[activePanel] = true
		activePanel:HookScript("OnHide", function()
			QuickJump:RequestRefresh()
		end)
	end
	QuickJump:RequestRefresh()
end

function ns.SetupPanelSource()
	QuickJump:RegisterSource(panelSource)
end
