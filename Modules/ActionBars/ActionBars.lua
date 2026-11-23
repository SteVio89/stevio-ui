local _, ns = ...

local config = ns.config.actionBars
local style = ns.config.style

local ActionBars = ns.RegisterModule("actionBars", {})

-- Blizzard's own bars and buttons are kept, only restyled and moved: paging,
-- keybinds, cooldowns, range tint and proc glows keep working under the
-- secret-value restrictions without any code of ours involved.

local deadButtonParts = {
	"NormalTexture",
	"SlotBackground",
	"SlotArt",
	"Border",
	"IconMask",
	"NewActionTexture",
	"SpellHighlightTexture",
	"Name",
}

-- Kept outside the buttons so nothing is written onto Blizzard's secure frames.
local styled = setmetatable({}, { __mode = "k" })

local function StyleButton(button)
	if styled[button] then
		return
	end
	styled[button] = true

	for _, key in ipairs(deadButtonParts) do
		local region = button[key]
		if region then
			ns.KillTexture(region)
		end
	end
	-- Normal texture is also swapped by Blizzard via SetNormalTexture/Atlas, so the getter wins over the key.
	-- Usually it is the same texture as button.NormalTexture, which is already hooked above.
	local normal = button:GetNormalTexture()
	if normal ~= button.NormalTexture then
		ns.KillTexture(normal)
	end

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

	if button.cooldown then
		button.cooldown:ClearAllPoints()
		button.cooldown:SetAllPoints()
	end

	ns.CreateBorder(button)
	ns.CreateShadow(button, 3)

	-- Empty slots: only a hint of a square, below the icon, which covers it.
	local empty = button:CreateTexture(nil, "BACKGROUND", nil, -7)
	empty:SetAllPoints()
	empty:SetColorTexture(1, 1, 1, 0.025)
	ns.CreateInsetBorder(button, -6, 1, "BACKGROUND"):SetColor(1, 1, 1, 0.055)

	-- A fixed white inner frame rather than a palette color: it looks the same on every icon.
	ns.CreateInsetBorder(button, 2):SetColor(1, 1, 1, 0.10)

	-- Darkens the bottom so the keybinding and the count stay readable.
	local vignette = button:CreateTexture(nil, "ARTWORK", nil, 7)
	vignette:SetTexture(style.texture)
	vignette:SetPoint("BOTTOMLEFT")
	vignette:SetPoint("BOTTOMRIGHT")
	vignette:SetHeight(button:GetHeight() * 0.45)
	vignette:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0))

	local hover = ns.CreateInsetBorder(button, 3)
	hover:SetColor(1, 1, 1, 0.4)
	hover:SetShown(false)
	button:HookScript("OnEnter", function()
		hover:SetShown(true)
	end)
	button:HookScript("OnLeave", function()
		hover:SetShown(false)
	end)

	-- Checked (active stance, current action): the accent, as a tint and a
	-- 2 px inner edge. The edge follows SetChecked, which every Blizzard
	-- update of the state goes through.
	if button.SetCheckedTexture then
		local accent = style.palette.accent
		button:SetCheckedTexture(style.texture)
		button:GetCheckedTexture():SetVertexColor(accent[1], accent[2], accent[3], 0.25)
		local checked = ns.CreateInsetBorder(button, 4, 2)
		checked:SetColor(unpack(accent))
		checked:SetShownFromBoolean(button:GetChecked())
		hooksecurefunc(button, "SetChecked", function(self)
			checked:SetShownFromBoolean(self:GetChecked())
		end)
	end

	-- Smaller keybindings; Blizzard's grey stays (it turns red out of range).
	local hotKey = button.HotKey
	if hotKey then
		local font, size, flags = hotKey:GetFont()
		if font then
			hotKey:SetFont(font, size - 2, flags)
		end
	end

	-- The vignette sizes with the button, which Edit Mode sets later.
	button:HookScript("OnSizeChanged", function(self)
		vignette:SetHeight(self:GetHeight() * 0.45)
	end)
end

local function StyleBar(bar)
	for _, button in ipairs(bar.actionButtons or {}) do
		StyleButton(button)
	end
end

local dividerPools = { "HorizontalDividersPool", "VerticalDividersPool" }

local function StripMainBarArt()
	local bar = MainActionBar
	ns.KillTexture(bar.BorderArt)
	bar.EndCaps:SetAlpha(0)
	bar.ActionBarPageNumber:SetAlpha(0)

	-- Dividers come from a pool that is refilled on every button update.
	hooksecurefunc(bar, "UpdateDividers", function(self)
		for _, key in ipairs(dividerPools) do
			local pool = self[key]
			if not pool then
				break
			end
			for divider in pool:EnumerateActive() do
				divider:SetAlpha(0)
			end
		end
	end)
end

-- Blizzard's frame and Edit Mode index name of each bar named in
-- ns.layout.actionBars. The index names differ from the bar names from the
-- fourth bar on (Enum.EditModeActionBarSystemIndices has no "Bar4"; checked
-- against Blizzard_APIDocumentationGenerated/EditModeManagerConstantsDocumentation.lua).
local barSystems = {
	MainBar = { frame = "MainActionBar", index = "MainBar" },
	Bar2 = { frame = "MultiBarBottomLeft", index = "Bar2" },
	Bar3 = { frame = "MultiBarBottomRight", index = "Bar3" },
	Bar4 = { frame = "MultiBarRight", index = "RightBar1" },
	Bar5 = { frame = "MultiBarLeft", index = "RightBar2" },
	Bar6 = { frame = "MultiBar5", index = "ExtraBar1" },
	Bar7 = { frame = "MultiBar6", index = "ExtraBar2" },
	Bar8 = { frame = "MultiBar7", index = "ExtraBar3" },
}
ns.actionBarSystems = barSystems

-- The entries of ns.layout.actionBars naming a known bar (the options panel
-- may hold a mistyped one), each with its Edit Mode index and frame.
local function ConfiguredBars()
	local bars = {}
	for _, layout in ipairs(ns.layout.actionBars) do
		local system = barSystems[layout.bar]
		local frame = system and _G[system.frame]
		local systemIndex = system and Enum.EditModeActionBarSystemIndices[system.index]
		if frame and systemIndex then
			bars[#bars + 1] = { layout = layout, systemIndex = systemIndex, frame = frame }
		end
	end
	return bars
end

local function PlaceBars()
	local Setting = Enum.EditModeActionBarSetting
	for _, bar in ipairs(ConfiguredBars()) do
		-- NumRows counts columns on a vertical bar: one either way.
		local barSettings = {
			[Setting.Orientation] = bar.layout.vertical and Enum.ActionBarOrientation.Vertical
				or Enum.ActionBarOrientation.Horizontal,
			[Setting.NumRows] = 1,
			[Setting.NumIcons] = 12,
			[Setting.IconSize] = ns.EditModeStep(config.iconSize, 50, 10),
			[Setting.IconPadding] = config.iconPadding,
			[Setting.HideBarArt] = 1,
		}
		-- The main bar's page arrows: alpha 0 (StripMainBarArt) only makes them
		-- invisible, they still take clicks; Edit Mode's setting hides them.
		-- Bars without the setting ignore it (only carried settings are written).
		if Setting.HideBarScrolling then
			barSettings[Setting.HideBarScrolling] = 1
		end
		ns.SetEditModeSystem(Enum.EditModeSystem.ActionBar, bar.systemIndex, bar.layout, barSettings)
	end

	ns.SetEditModeSystem(
		Enum.EditModeSystem.ActionBar,
		Enum.EditModeActionBarSystemIndices.StanceBar,
		ns.layout.stanceBar
	)
	ns.SetEditModeSystem(
		Enum.EditModeSystem.ActionBar,
		Enum.EditModeActionBarSystemIndices.PetActionBar,
		ns.layout.petBar
	)
end

function ActionBars:OnEnable()
	for _, bar in ipairs(ConfiguredBars()) do
		StyleBar(bar.frame)
	end
	StyleBar(StanceBar)
	StyleBar(PetActionBar)

	StripMainBarArt()
	PlaceBars()

	ns.KeepHidden(MainStatusTrackingBarContainer)
	ns.KeepHidden(SecondaryStatusTrackingBarContainer)

	ns.CreateMenubar(config)
	ns.CreateActionSetSwitcher()
end
