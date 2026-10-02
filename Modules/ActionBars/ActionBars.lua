local _, ns = ...

local config = ns.config.actionbars
local style = ns.config.style

local ActionBars = ns:RegisterModule("actionbars", {})

-- Blizzard's own bars and buttons are kept, only restyled and moved: paging,
-- keybinds, cooldowns, range tint and proc glows keep working under the
-- secret-value restrictions without any code of ours involved.

local deadButtonParts = {
	"NormalTexture", "SlotBackground", "SlotArt", "Border", "IconMask",
	"NewActionTexture", "SpellHighlightTexture", "Name",
}

local function StyleButton(button)
	if button.stevioStyled then
		return
	end
	button.stevioStyled = true

	for _, key in ipairs(deadButtonParts) do
		local region = button[key]
		if region then
			ns.KillTexture(region)
		end
	end
	-- Normal texture is also swapped by Blizzard via SetNormalTexture/Atlas, so the getter wins over the key.
	ns.KillTexture(button:GetNormalTexture())

	local icon = button.icon or button.Icon
	if icon then
		if button.IconMask then
			icon:RemoveMaskTexture(button.IconMask)
		end
		icon:ClearAllPoints()
		icon:SetAllPoints()
		icon:SetTexCoord(config.iconCrop, 1 - config.iconCrop, config.iconCrop, 1 - config.iconCrop)
	end

	button:SetHighlightTexture(style.texture)
	button:GetHighlightTexture():SetVertexColor(1, 1, 1, config.highlightAlpha)
	button:SetPushedTexture(style.texture)
	button:GetPushedTexture():SetVertexColor(1, 1, 1, config.pushedAlpha)
	if button.SetCheckedTexture then
		button:SetCheckedTexture(style.texture)
		button:GetCheckedTexture():SetVertexColor(unpack(config.checkedColor))
	end

	if button.cooldown then
		button.cooldown:ClearAllPoints()
		button.cooldown:SetAllPoints()
	end

	ns.CreateBorder(button)
end

local function StyleBar(bar)
	for _, button in ipairs(bar.actionButtons or {}) do
		StyleButton(button)
	end
end

local function StripMainBarArt()
	local bar = MainActionBar
	ns.KillTexture(bar.BorderArt)
	bar.EndCaps:SetAlpha(0)
	bar.ActionBarPageNumber:SetAlpha(0)

	-- Dividers come from a pool that is refilled on every button update.
	hooksecurefunc(bar, "UpdateDividers", function(self)
		for _, pool in ipairs({ self.HorizontalDividersPool, self.VerticalDividersPool }) do
			for divider in pool:EnumerateActive() do
				divider:SetAlpha(0)
			end
		end
	end)
end

local barSystemIndices = {
	Enum.EditModeActionBarSystemIndices.MainBar,
	Enum.EditModeActionBarSystemIndices.Bar2,
	Enum.EditModeActionBarSystemIndices.Bar3,
}

-- Edit Mode stores icon size as steps of 10 above 50%.
local function IconSizeSetting(percent)
	return (percent - 50) / 10
end

local function PlaceBars()
	local Setting = Enum.EditModeActionBarSetting
	local barSettings = {
		[Setting.Orientation] = Enum.ActionBarOrientation.Horizontal,
		[Setting.NumRows] = 1,
		[Setting.NumIcons] = 12,
		[Setting.IconSize] = IconSizeSetting(config.iconSize),
		[Setting.IconPadding] = config.iconPadding,
		[Setting.HideBarArt] = 1,
	}
	for index, systemIndex in ipairs(barSystemIndices) do
		ns:SetEditModeSystem(Enum.EditModeSystem.ActionBar, systemIndex, ns.layout.actionBars[index], barSettings)
	end

	ns:SetEditModeSystem(Enum.EditModeSystem.ActionBar, Enum.EditModeActionBarSystemIndices.StanceBar, ns.layout.stanceBar)
	ns:SetEditModeSystem(Enum.EditModeSystem.ActionBar, Enum.EditModeActionBarSystemIndices.PetActionBar, ns.layout.petBar)
end

function ActionBars:OnEnable()
	for _, barName in ipairs(config.bars) do
		StyleBar(_G[barName])
	end
	StyleBar(StanceBar)
	StyleBar(PetActionBar)

	StripMainBarArt()
	PlaceBars()

	ns.KeepHidden(MainStatusTrackingBarContainer)
	ns.KeepHidden(SecondaryStatusTrackingBarContainer)

	ns.CreateMenubar(config)
end
