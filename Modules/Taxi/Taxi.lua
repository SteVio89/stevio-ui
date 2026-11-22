local _, ns = ...

local config = ns.config.taxi
local Taxi = ns.RegisterModule("taxi", {})

-- Reachable destinations as a compact list sorted by name next to Blizzard's
-- flight map; the map stays for orientation. The list is one of Blizzard's
-- scroll boxes, so it scrolls once it is taller than the map.

local panel, scrollBox

-- Width of the scroll bar beside the list, with its gap, when it is needed.
local SCROLL_BAR_SPACE = 14

local function TakeNode(row)
	TakeTaxiNode(row.nodeIndex)
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
function Taxi.ReachableSorted(nodes)
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

-- The cost column: nothing for a free flight, like Blizzard's flight map.
function Taxi.CostText(cost, formatMoney)
	if not cost or cost <= 0 then
		return ""
	end
	return formatMoney(cost)
end

-- The panel's height for `count` rows, at most `maxHeight` (the rest scrolls).
function Taxi.PanelHeight(count, rowHeight, padding, maxHeight)
	local height = count * rowHeight + padding * 2
	if maxHeight and height > maxHeight then
		return maxHeight
	end
	return height
end

-- Scroll box rows are recycled: built once, filled for each destination.
local function InitRow(row, node)
	if not row.name then
		row:SetHighlightTexture(ns.config.style.texture)
		row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
		row.name = ns.CreateFontString(row)
		row.name:SetPoint("LEFT", 4, 0)
		row.cost = ns.CreateFontString(row, nil, "RIGHT")
		row.cost:SetPoint("RIGHT", -4, 0)
		row.name:SetPoint("RIGHT", row.cost, "LEFT", -6, 0)
		row:SetScript("OnClick", TakeNode)
	end
	row.nodeIndex = node.index
	row.name:SetText(node.name)
	row.cost:SetText(Taxi.CostText(node.cost, GetMoneyString))
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
	local nodes = Taxi.ReachableSorted(all)

	local mapFrame = GetMapFrame()
	local maxHeight = mapFrame and mapFrame:GetHeight() or UIParent:GetHeight() * 0.8
	panel:SetHeight(Taxi.PanelHeight(#nodes, config.rowHeight, config.padding, maxHeight))
	panel:ClearAllPoints()
	if mapFrame then
		panel:SetPoint("TOPLEFT", mapFrame, "TOPRIGHT", 8, 0)
	else
		panel:SetPoint("CENTER")
	end
	scrollBox:SetDataProvider(CreateDataProvider(nodes), ScrollBoxConstants.DiscardScrollPosition)
	panel:SetShown(#nodes > 0)
end

local function CreatePanel()
	panel = CreateFrame("Frame", "StevioUI_TaxiList", UIParent)
	panel:SetWidth(config.width)
	panel:SetFrameStrata("HIGH")
	ns.CreateBackground(panel, ns.PANEL_COLOR)
	ns.CreateBorder(panel)
	panel:Hide()

	local padding = config.padding
	scrollBox = CreateFrame("Frame", nil, panel, "WowScrollBoxList")
	local scrollBar = CreateFrame("EventFrame", nil, panel, "MinimalScrollBar")
	scrollBar:SetPoint("TOPRIGHT", -padding, -padding)
	scrollBar:SetPoint("BOTTOMRIGHT", -padding, padding)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(config.rowHeight)
	view:SetElementInitializer("Button", InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	-- The scroll bar only shows (and takes room) when the list doesn't fit.
	local withBar = {
		CreateAnchor("TOPLEFT", panel, "TOPLEFT", padding, -padding),
		CreateAnchor("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding - SCROLL_BAR_SPACE, padding),
	}
	local withoutBar = {
		CreateAnchor("TOPLEFT", panel, "TOPLEFT", padding, -padding),
		CreateAnchor("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -padding, padding),
	}
	ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar, withBar, withoutBar)
end

function Taxi:OnEnable()
	CreatePanel()

	-- The map frame is shown after the event, and the list anchors to it.
	ns.RegisterEvent("TAXIMAP_OPENED", function()
		C_Timer.After(0, Build)
	end)
	ns.RegisterEvent("TAXIMAP_CLOSED", function()
		panel:Hide()
	end)
end
