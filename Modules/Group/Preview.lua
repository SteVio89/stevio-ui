local _, ns = ...

local config = ns.config.group
local style = ns.config.style

local UNITS_PER_GROUP = ns.UNITS_PER_GROUP
local MAX_UNITS = ns.MAX_GROUPS * ns.UNITS_PER_GROUP

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local POWER_BY_CLASS = { WARRIOR = "RAGE", ROGUE = "ENERGY" }
local DISPELLABLE_ICON = "Interface\\Icons\\Spell_Holy_DispelMagic"
local OTHER_ICON = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"
local OWN_ICON = "Interface\\Icons\\Spell_Holy_Renew"
local NAMES = { "Stevio", "Aldric", "Brunhilde", "Cassian", "Dagna", "Elowen", "Fenwick", "Grimbold", "Hilde" }

local preview

-- Deterministic instead of random, so every state (dead, out of range, aggro,
-- target, both debuff sides) shows up at the same spot in each preview size.
local function FakeMember(index)
	local class = CLASSES[(index - 1) % #CLASSES + 1]
	return {
		class = class,
		power = POWER_BY_CLASS[class] or "MANA",
		health = 0.25 + ((index * 37) % 75) / 100,
		dead = index % 11 == 0,
		outOfRange = index % 7 == 0,
		aggro = index == 2,
		target = index == 1,
		-- One tank and one healer per group, the rest damage dealers.
		role = (index % 5 == 1 and "TANK") or (index % 5 == 2 and "HEALER") or "DAMAGER",
		dispellable = index % 4 == 0 and 2 or (index % 3 == 0 and 1 or 0),
		other = index % 5 == 0 and 2 or (index % 2 == 0 and 1 or 0),
		own = index % 6,
		name = NAMES[(index - 1) % #NAMES + 1],
	}
end

local function CreatePreviewIcon(cell, anchorPoint, offsetX, offsetY, size)
	local icon = CreateFrame("Frame", nil, cell.health)
	icon:SetPoint(anchorPoint, cell.health, anchorPoint, offsetX, offsetY)
	icon:SetFrameLevel(cell.health:GetFrameLevel() + 2)
	ns.StyleAuraIcon(icon, size, ns.GROUP_ICON_COUNT_SIZE)
	icon:Hide()
	return icon
end

-- Plain frames the /sui test preview fills with fake debuffs and HoTs, where
-- the cell's aura containers put them (ns.GROUP_CELL_LAYOUT).
local function BuildPreviewIcons(cell)
	local layout = ns.GROUP_CELL_LAYOUT
	local step = config.iconSize + ns.GROUP_ICON_SPACING
	cell.debuffIcons, cell.ownIcons = {}, {}
	for i = 1, config.debuffsMax do
		cell.debuffIcons[i] =
			CreatePreviewIcon(cell, "TOPRIGHT", layout.debuffX - (i - 1) * step, layout.debuffY, config.iconSize)
	end
	local ownStep = config.ownAuraSize + ns.GROUP_ICON_SPACING
	for i = 1, config.ownAurasMax do
		cell.ownIcons[i] =
			CreatePreviewIcon(cell, "TOPLEFT", layout.ownX + (i - 1) * ownStep, layout.ownY, config.ownAuraSize)
	end
end

local function ShowIcon(icon, texture, borderColor)
	icon.texture:SetTexture(texture)
	icon.count:SetText("")
	icon.cooldown:Clear()
	icon.border:SetColor(unpack(borderColor or style.borderColor))
	icon:Show()
end

-- Dispellable debuffs first (as many as the live cell's group takes), then
-- the others, together at most config.debuffsMax.
local function ShowDebuffs(cell, dispellable, other)
	local dispellableMax = math.min(ns.GROUP_CELL_LAYOUT.dispellableMax, config.debuffsMax)
	dispellable = math.min(dispellable, dispellableMax)
	other = math.min(other, config.debuffsMax - dispellableMax)
	for i, icon in ipairs(cell.debuffIcons) do
		if i <= dispellable then
			ShowIcon(icon, DISPELLABLE_ICON, config.dispelColor)
		elseif i <= dispellable + other then
			ShowIcon(icon, OTHER_ICON)
		else
			icon:Hide()
		end
	end
end

local function ShowIcons(icons, count, texture)
	for i, icon in ipairs(icons) do
		if i <= count then
			ShowIcon(icon, texture)
		else
			icon:Hide()
		end
	end
end

local function ShowMember(cell, member)
	cell.health:SetMinMaxValues(0, 1)
	cell.power:SetMinMaxValues(0, 1)
	if member.dead then
		cell.health:SetValue(0)
		cell.power:SetValue(0)
		local r, g, b = unpack(style.deadColor)
		ns.ShowGroupCellState(cell, "dead", false, r, g, b)
	else
		local color = C_ClassColor.GetClassColor(member.class)
		cell.health:SetValue(member.health)
		cell.power:SetValue(1 - member.health / 2)
		local dark = ns.Luminance(color.r, color.g, color.b) > config.darkNameLuminance
		ns.ShowGroupCellState(cell, nil, dark, color.r, color.g, color.b)
	end
	local powerColor = PowerBarColor[member.power]
	cell.power:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)

	cell:SetAlpha(member.outOfRange and config.outOfRangeAlpha or 1)
	cell.aggroBorder:SetShown(member.aggro)
	cell.targetBorder:SetShown(member.target)
	if member.role == "DAMAGER" then
		cell.roleIcon:Hide()
	else
		cell.roleIcon:SetAtlas(GetMicroIconForRole(member.role))
		cell.roleIcon:Show()
	end
	ShowDebuffs(cell, member.dispellable, member.other)
	ShowIcons(cell.ownIcons, member.own, OWN_ICON)
	cell.nameText:SetText(member.name)
end

-- The four states the settings window's group page shows side by side.
local SAMPLES = {
	{ "PRIEST", "Shiewa", { own = 3 } },
	{ "MAGE", "Cassian", { dispellable = 1, other = 1, own = 1 } },
	{ "WARRIOR", "Aldric", { aggro = true, role = "TANK", other = 1, power = "RAGE" } },
	{ "DRUID", "Elowen", { outOfRange = true, own = 1 } },
}

local function SampleMember(sample)
	local member = {
		class = sample[1],
		name = sample[2],
		power = "MANA",
		health = 0.72,
		role = "DAMAGER",
		dispellable = 0,
		other = 0,
		own = 0,
	}
	for key, value in pairs(sample[3]) do
		member[key] = value
	end
	return member
end

-- Four cells (normal, dispellable, aggro, out of range) in `parent`, built
-- with the current config like the /sui test preview. Returns the cells and
-- one cell's size; the config is read while building, so a changed config
-- needs new cells.
function ns.CreateGroupSamples(parent)
	local width, height = ns.GetGroupCellSize()
	local cells = {}
	for index, sample in ipairs(SAMPLES) do
		local cell = CreateFrame("Frame", nil, parent)
		cell:SetSize(width, height)
		ns.BuildGroupCell(cell)
		BuildPreviewIcons(cell)
		ShowMember(cell, SampleMember(sample))
		cells[index] = cell
	end
	return cells, width, height
end

local function CreatePreview()
	local baseWidth, cellHeight = ns.GetGroupCellSize()
	local cells = {}
	local container = ns.CreateGroupContainer(baseWidth, cellHeight)
	for index = 1, MAX_UNITS do
		local cell = CreateFrame("Frame", nil, container)
		cell:SetSize(baseWidth, cellHeight)
		ns.BuildGroupCell(cell)
		BuildPreviewIcons(cell)
		ShowMember(cell, FakeMember(index))
		cells[index] = cell
	end
	return { container = container, cells = cells, baseWidth = baseWidth, cellHeight = cellHeight }
end

local function ShowPreview(count)
	preview = preview or CreatePreview()
	local mode = ns.GetGroupLayoutMode(math.ceil(count / UNITS_PER_GROUP))
	local cellWidth = ns.GetGroupCellWidth(mode, preview.baseWidth)
	for index, cell in ipairs(preview.cells) do
		local groupIndex = math.ceil(index / UNITS_PER_GROUP)
		local slot = (index - 1) % UNITS_PER_GROUP + 1
		cell:SetWidth(cellWidth)
		cell:ClearAllPoints()
		cell:SetPoint("BOTTOMLEFT", ns.GetGroupCellOffset(mode, groupIndex, slot, cellWidth, preview.cellHeight))
		cell:SetShown(index <= count)
	end
	preview.container:Show()
	ns.SetLiveGroupAlpha(0)
	if ns.OnGroupPreviewChanged then
		ns.OnGroupPreviewChanged(preview.cells, count, mode)
	end
end

local function HidePreview()
	if preview then
		preview.container:Hide()
	end
	ns.SetLiveGroupAlpha(1)
	if ns.OnGroupPreviewChanged then
		ns.OnGroupPreviewChanged(nil)
	end
end

ns.RegisterModuleCommand("test", "group", function(input)
	local count = tonumber(input)
	if count and count >= 1 then
		ShowPreview(math.min(math.floor(count), MAX_UNITS))
	else
		HidePreview()
		ns.Print(ns.T("/sui test 5|10|25|40 – /sui test (off)", "/sui test 5|10|25|40 – /sui test (aus)"))
	end
end)
