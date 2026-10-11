local addonName, ns = ...

local config = ns.config.group
local style = ns.config.style

local UNITS_PER_GROUP = 5
local MAX_UNITS = 40

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local POWER_BY_CLASS = { WARRIOR = "RAGE", ROGUE = "ENERGY" }
local DISPELLABLE_ICON = "Interface\\Icons\\Spell_Holy_DispelMagic"
local OTHER_ICON = "Interface\\Icons\\Spell_Shadow_ShadowWordPain"

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
	}
end

local function ShowIcons(icons, count, texture)
	for i, icon in ipairs(icons) do
		icon.texture:SetTexture(texture)
		icon.count:SetText("")
		icon.cooldown:Clear()
		icon:SetShown(i <= count)
	end
end

local function ShowMember(cell, member)
	cell.health:SetMinMaxValues(0, 1)
	cell.power:SetMinMaxValues(0, 1)
	if member.dead then
		cell.health:SetValue(0)
		cell.health:SetStatusBarColor(unpack(style.deadColor))
		cell.power:SetValue(0)
	else
		local color = C_ClassColor.GetClassColor(member.class)
		cell.health:SetValue(member.health)
		cell.health:SetStatusBarColor(color.r, color.g, color.b)
		cell.power:SetValue(1 - member.health / 2)
	end
	local powerColor = PowerBarColor[member.power]
	cell.power:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)

	cell:SetAlpha(member.outOfRange and config.outOfRangeAlpha or 1)
	cell.aggroBorder:SetShown(member.aggro)
	cell.targetBorder:SetShown(member.target)
	cell.roleIcon:SetAtlas(GetMicroIconForRole(member.role))
	cell.roleIcon:Show()
	ShowIcons(cell.leftIcons, member.dispellable, DISPELLABLE_ICON)
	ShowIcons(cell.rightIcons, member.other, OTHER_ICON)
end

local function CreatePreview()
	local baseWidth, cellHeight = ns.GetGroupCellSize()
	local cells = {}
	local container = ns.CreateGroupContainer(baseWidth, cellHeight)
	for index = 1, MAX_UNITS do
		local cell = CreateFrame("Frame", nil, container)
		cell:SetSize(baseWidth, cellHeight)
		ns.BuildGroupCell(cell)
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

ns:RegisterSlashCommand("test", function(input)
	if not ns.config.group.enabled then
		return
	end
	local count = tonumber(input)
	if count and count >= 1 then
		ShowPreview(math.min(math.floor(count), MAX_UNITS))
	else
		HidePreview()
		print(("|cff33ff99%s|r: /sui test 5|10|25|40 – /sui test (aus)"):format(addonName))
	end
end)
