local _, ns = ...

-- Edit Mode stores both sizes as steps of 5% above a per-system minimum.
local MICRO_MIN, BAGS_MIN, STEP = 70, 75, 5

-- The pure part is kept on ns.Menubar for tests/menubar_test.lua.
local Menubar = {}
ns.Menubar = Menubar

function Menubar.SizeSetting(percent, minimum)
	return math.floor(ns.EditModeStep(percent, minimum, STEP) + 0.5)
end

-- Bag buttons are drawn larger than micro buttons at the same percentage, so
-- the bag size is scaled by their height ratio to end up visually equal.
function Menubar.BagPercent(microPercent, ratio)
	return Clamp(microPercent * ratio, BAGS_MIN, 200)
end

local function MatchingBagPercent(microPercent)
	return Menubar.BagPercent(microPercent, CharacterMicroButton:GetHeight() / MainMenuBarBackpackButton:GetHeight())
end

-- Every texture of `button`: the micro buttons are atlases Blizzard swaps,
-- so the textures are muted again whenever it does (see MuteButton).
local function Textures(button)
	local textures = {}
	for _, region in ipairs({ button:GetRegions() }) do
		if region:IsObjectType("Texture") then
			textures[#textures + 1] = region
		end
	end
	return textures
end

local SWAPPING_METHODS = { "SetNormalAtlas", "SetPushedAtlas", "SetNormalTexture", "SetPushedTexture" }

-- Muted until hovered. Only looks: the buttons keep their positions and scripts.
local function MuteButton(button)
	local set = ns.DesaturateUntilHover(button, Textures)
	local function Reapply()
		set(not button:IsMouseOver())
	end
	for _, method in ipairs(SWAPPING_METHODS) do
		if button[method] then
			hooksecurefunc(button, method, Reapply)
		end
	end
end

-- A narrow panel behind a row of buttons, a little larger than the row.
local function BackPanel(row)
	local panel = CreateFrame("Frame", nil, row)
	panel:SetPoint("TOPLEFT", -3, 3)
	panel:SetPoint("BOTTOMRIGHT", 3, -3)
	panel:SetFrameLevel(row:GetFrameLevel())
	ns.CreatePanel(panel)
end

local function StyleRow(row)
	BackPanel(row)
	for _, child in ipairs({ row:GetChildren() }) do
		if child:IsObjectType("Button") then
			MuteButton(child)
		else
			-- Bag slots sit in a cluster frame of their own.
			for _, inner in ipairs({ child:GetChildren() }) do
				if inner:IsObjectType("Button") then
					MuteButton(inner)
				end
			end
		end
	end
end

function ns.CreateMenubar(config)
	StyleRow(MicroMenu)
	StyleRow(BagsBar)

	ns.SetEditModeSystem(Enum.EditModeSystem.MicroMenu, nil, ns.layout.menubar, {
		[Enum.EditModeMicroMenuSetting.Size] = Menubar.SizeSetting(config.menubarSize, MICRO_MIN),
	})
	ns.SetEditModeSystem(Enum.EditModeSystem.Bags, nil, ns.layout.bags, {
		[Enum.EditModeBagsSetting.Size] = Menubar.SizeSetting(MatchingBagPercent(config.menubarSize), BAGS_MIN),
	})
end
