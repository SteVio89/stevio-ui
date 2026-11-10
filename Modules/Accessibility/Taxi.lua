local _, ns = ...

local config = ns.config.accessibility.taxi
local Internal = ns.AccessibilityInternal

-- Blizzard's flight map has no list to label, so reachable destinations get
-- their own compact list next to it; the map stays for orientation.

local panel
local rows = {}

local function TakeNode(row)
	TakeTaxiNode(row.nodeIndex)
end

local function GetRow(index)
	local row = rows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, panel)
	row:SetHeight(config.rowHeight)
	row:SetPoint("TOPLEFT", config.padding, -config.padding - (index - 1) * config.rowHeight)
	row:SetPoint("RIGHT", -config.padding, 0)
	row:SetHighlightTexture(ns.config.style.texture)
	row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
	row.name = ns.CreateFontString(row)
	row.name:SetPoint("LEFT", 4, 0)
	row.cost = ns.CreateFontString(row, nil, "RIGHT")
	row.cost:SetPoint("RIGHT", -4, 0)
	row.name:SetPoint("RIGHT", row.cost, "LEFT", -6, 0)
	row:SetScript("OnClick", TakeNode)
	rows[index] = row
	return row
end

local function GetMapFrame()
	if FlightMapFrame and FlightMapFrame:IsShown() then
		return FlightMapFrame
	end
	if TaxiFrame and TaxiFrame:IsShown() then
		return TaxiFrame
	end
end

-- Testable without the game: the reachable nodes ({ index, type, name, cost })
-- sorted by name, ignoring case.
function Internal.ReachableSorted(nodes)
	local reachable = {}
	for _, node in ipairs(nodes) do
		if node.type == "REACHABLE" then
			reachable[#reachable + 1] = node
		end
	end
	table.sort(reachable, function(a, b)
		return a.name:lower() < b.name:lower()
	end)
	return reachable
end

local function Build()
	local all = {}
	for index = 1, NumTaxiNodes() do
		all[index] = { index = index, type = TaxiNodeGetType(index) }
		-- Name and cost are only read for reachable nodes.
		if all[index].type == "REACHABLE" then
			all[index].name, all[index].cost = TaxiNodeName(index), TaxiNodeCost(index)
		end
	end
	local nodes = Internal.ReachableSorted(all)

	for index, node in ipairs(nodes) do
		local row = GetRow(index)
		row.nodeIndex = node.index
		row.name:SetText(node.name)
		row.cost:SetText(GetMoneyString(node.cost))
		row:Show()
	end
	for index = #nodes + 1, #rows do
		rows[index]:Hide()
	end

	panel:SetHeight(#nodes * config.rowHeight + config.padding * 2)
	panel:ClearAllPoints()
	local mapFrame = GetMapFrame()
	if mapFrame then
		panel:SetPoint("TOPLEFT", mapFrame, "TOPRIGHT", 8, 0)
	else
		panel:SetPoint("CENTER")
	end
	panel:SetShown(#nodes > 0)
	ns.QuickJump:RequestRefresh()
end

local taxiSource = {
	name = "taxi",
	priority = 15,
	IsOpen = function()
		return panel:IsShown()
	end,
	Collect = function()
		local targets = {}
		for _, row in ipairs(rows) do
			if row:IsShown() then
				targets[#targets + 1] = row
			end
		end
		return targets
	end,
}

function Internal.IsTaxiListOpen()
	return panel ~= nil and panel:IsShown()
end

function Internal.SetupTaxiList()
	panel = CreateFrame("Frame", "StevioUI_TaxiList", UIParent)
	panel:SetWidth(config.width)
	panel:SetFrameStrata("HIGH")
	ns.CreateBackground(panel, ns.PANEL_COLOR)
	ns.CreateBorder(panel)
	panel:Hide()

	ns.QuickJump:RegisterSource(taxiSource)

	-- The map frame is shown after the event, and the list anchors to it.
	ns.RegisterEvent("TAXIMAP_OPENED", function()
		C_Timer.After(0, Build)
	end)
	ns.RegisterEvent("TAXIMAP_CLOSED", function()
		panel:Hide()
		ns.QuickJump:RequestRefresh()
	end)
end
