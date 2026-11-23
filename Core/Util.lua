local _, ns = ...

local style = ns.config.style

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

function ns.PixelSize(region)
	return PixelUtil.ConvertPixelsToUIForRegion(1, region)
end

function ns.SetPoint(frame, layout, relativeTo)
	frame:ClearAllPoints()
	frame:SetPoint(
		layout.point,
		relativeTo or UIParent,
		layout.relativePoint or layout.point,
		layout.x or 0,
		layout.y or 0
	)
end

local Border = {}
Border.__index = Border

function Border:SetColor(r, g, b, a)
	for _, edge in ipairs(self) do
		edge:SetColorTexture(r, g, b, a or 1)
	end
end

function Border:SetShown(shown)
	for _, edge in ipairs(self) do
		edge:SetShown(shown)
	end
end

-- Lets the client resolve possibly-secret booleans (e.g. UnitIsUnit in combat):
-- the edges are shown while `value` equals `shownWhen`.
local function SetShownWhen(border, value, shownWhen)
	if issecretvalue(value) then
		for _, edge in ipairs(border) do
			edge:Show()
			edge:SetAlphaFromBoolean(value, shownWhen and 1 or 0, shownWhen and 0 or 1)
		end
	else
		for _, edge in ipairs(border) do
			edge:SetAlpha(1)
		end
		if shownWhen then
			border:SetShown(value)
		else
			border:SetShown(not value)
		end
	end
end

function Border:SetShownFromBoolean(value)
	SetShownWhen(self, value, true)
end

-- The opposite of SetShownFromBoolean: shown while the value is false.
function Border:SetHiddenFromBoolean(value)
	SetShownWhen(self, value, false)
end

-- Edges sit outside the frame so the border never covers bar content.
-- Higher sublevels draw later, which lets highlight borders stack on the base one.
function ns.CreateBorder(frame, sublevel, size)
	local px = ns.PixelSize(frame) * (size or 1)
	local border = setmetatable({}, Border)
	for i = 1, 4 do
		border[i] = frame:CreateTexture(nil, "OVERLAY", nil, sublevel or 0)
	end
	local top, bottom, left, right = border[1], border[2], border[3], border[4]

	top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -px, 0)
	top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", px, 0)
	top:SetHeight(px)
	bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -px, 0)
	bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", px, 0)
	bottom:SetHeight(px)
	left:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
	left:SetWidth(px)
	right:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
	right:SetWidth(px)

	border:SetColor(unpack(style.borderColor))
	return border
end

-- Like CreateBorder, but the edges sit inside the frame: state edges (accent,
-- aggro, dispel) on top of the content without moving it.
function ns.CreateInsetBorder(frame, sublevel, size)
	local px = ns.PixelSize(frame) * (size or 1)
	local border = setmetatable({}, Border)
	for i = 1, 4 do
		border[i] = frame:CreateTexture(nil, "OVERLAY", nil, sublevel or 5)
	end
	local top, bottom, left, right = border[1], border[2], border[3], border[4]

	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(px)
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(px)
	left:SetPoint("TOPLEFT", 0, -px)
	left:SetPoint("BOTTOMLEFT", 0, px)
	left:SetWidth(px)
	right:SetPoint("TOPRIGHT", 0, -px)
	right:SetPoint("BOTTOMRIGHT", 0, px)
	right:SetWidth(px)

	border:SetColor(unpack(style.borderColor))
	return border
end

-- The glass edge of a panel: a light line along the inside of its top edge
-- and a faint inner frame. `topOnly` skips the frame (small icons).
function ns.CreateInnerEdge(frame, topOnly)
	local palette = style.palette
	local px = ns.PixelSize(frame)
	local edge = {}
	if not topOnly then
		edge.inner = ns.CreateInsetBorder(frame, 6)
		edge.inner:SetColor(unpack(palette.edgeInner))
	end
	edge.top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
	edge.top:SetPoint("TOPLEFT")
	edge.top:SetPoint("TOPRIGHT")
	edge.top:SetHeight(px)
	edge.top:SetColorTexture(unpack(palette.edgeTop))
	return edge
end

-- Where each shadow strip sits and which way it fades: SetGradient's min
-- color is the bottom (VERTICAL) or left (HORIZONTAL) end.
local SHADOW_SIDES = {
	top = { "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT", "TOPRIGHT", "VERTICAL", true },
	bottom = { "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT", "BOTTOMRIGHT", "VERTICAL", false },
	left = { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT", "HORIZONTAL", false },
	right = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT", "HORIZONTAL", true },
}

-- A soft shadow outside the black border: strips `size` (default 4) wide
-- that fade from palette.shadow to nothing. The corners stay empty, which is
-- invisible at this size. `sides` limits it (e.g. { bottom = true }).
function ns.CreateShadow(frame, size, sides)
	size = size or 4
	local px = ns.PixelSize(frame)
	local r, g, b, a = unpack(style.palette.shadow)
	local dark, clear = CreateColor(r, g, b, a), CreateColor(r, g, b, 0)
	local shadow = {}
	for side, spec in pairs(SHADOW_SIDES) do
		if not sides or sides[side] then
			local point1, relative1, point2, relative2, orientation, darkFirst = unpack(spec)
			local strip = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
			strip:SetTexture(style.texture)
			local vertical = orientation == "VERTICAL"
			local dx = vertical and 0 or (side == "left" and -px or px)
			local dy = vertical and (side == "top" and px or -px) or 0
			-- Along the side, the strip covers the border's corners as well.
			local ax = vertical and px or 0
			local ay = vertical and 0 or px
			strip:SetPoint(point1, frame, relative1, dx - ax, dy + ay)
			strip:SetPoint(point2, frame, relative2, dx + ax, dy - ay)
			if vertical then
				strip:SetHeight(size)
			else
				strip:SetWidth(size)
			end
			if darkFirst then
				strip:SetGradient(orientation, dark, clear)
			else
				strip:SetGradient(orientation, clear, dark)
			end
			shadow[side] = strip
		end
	end
	return shadow
end

-- The common panel: background (palette.panel unless `opts.color`), black
-- border, glass edge and shadow. `opts`: color, background (false for none),
-- shadow (false for none), shadowSize, shadowSides.
function ns.CreatePanel(frame, opts)
	opts = opts or {}
	local panel = {}
	if opts.background ~= false then
		panel.background = ns.CreateBackground(frame, opts.color)
	end
	panel.border = ns.CreateBorder(frame)
	panel.edge = ns.CreateInnerEdge(frame)
	if opts.shadow ~= false then
		panel.shadow = ns.CreateShadow(frame, opts.shadowSize, opts.shadowSides)
	end
	return panel
end

-- Depth on a status bar without touching its color, which may be secret: a
-- neutral overlay on the fill, darker at the bottom and lighter at the top,
-- plus a light line along the top. `half` halves the overlay and drops the line.
function ns.CreateBarShade(bar, half)
	local strength = half and 0.5 or 1
	local fill = bar:GetStatusBarTexture()
	local shade = bar:CreateTexture(nil, "ARTWORK", nil, 7)
	shade:SetTexture(style.texture)
	shade:SetAllPoints(fill)
	shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.30 * strength), CreateColor(1, 1, 1, 0.10 * strength))
	bar.shade = shade
	if not half then
		local light = bar:CreateTexture(nil, "ARTWORK", nil, 7)
		light:SetPoint("TOPLEFT")
		light:SetPoint("TOPRIGHT")
		light:SetHeight(ns.PixelSize(bar))
		light:SetColorTexture(1, 1, 1, 0.25)
		bar.light = light
	end
	return shade
end

-- The part of a bar the fill doesn't cover (missing health), tinted with the
-- bar's color (ns.SetTrackColor) instead of grey.
function ns.CreateTintedTrack(bar)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetTexture(style.texture)
	return track
end

-- The color may be secret: SetVertexColor takes it as it is.
function ns.SetTrackColor(track, r, g, b)
	track:SetVertexColor(r, g, b, 0.14)
end

-- Muted icons that come to full color on hover.
function ns.Desaturate(region, on)
	region:SetDesaturated(on)
	region:SetAlpha(on and 0.62 or 1)
end

-- Desaturates what `regions(frame)` returns while the mouse is off `frame`.
-- A function, because Blizzard swaps some textures (micro menu atlases).
function ns.DesaturateUntilHover(frame, regions)
	local function Set(on)
		for _, region in ipairs(regions(frame)) do
			ns.Desaturate(region, on)
		end
	end
	frame:HookScript("OnEnter", function()
		Set(false)
	end)
	frame:HookScript("OnLeave", function()
		Set(true)
	end)
	Set(true)
	return Set
end

-- Near-black backdrop of small overlay panels (flight list).
ns.PANEL_COLOR = { 0, 0, 0, 0.9 }

-- `color` defaults to the style's background colour.
function ns.CreateBackground(frame, color, sublevel)
	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, sublevel)
	bg:SetAllPoints()
	bg:SetColorTexture(unpack(color or style.backgroundColor))
	return bg
end

-- Crops the built-in border off a square icon texture.
function ns.CropIcon(texture)
	texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

-- A button at a screen edge (chat, tracker) that toggles what it belongs to.
function ns.CreateEdgeBadge(name, layout, onClick)
	local badge = style.badge
	local button = CreateFrame("Button", name, UIParent)
	button:SetSize(badge.width, badge.height)
	ns.SetPoint(button, layout)
	button:SetScript("OnClick", onClick)
	return button
end

function ns.CreateStatusBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture(style.texture)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

-- With style.textShadow, text gets a drop shadow instead of the outline;
-- `outline` keeps the outline as well, for text on bright bars.
function ns.SetFont(text, size, outline)
	local shadow = style.textShadow
	text:SetFont(style.font, size or style.fontSize, (outline or not shadow) and style.fontFlags or "")
	if shadow then
		local offset = outline and 0.5 or 1
		text:SetShadowOffset(offset, -offset)
		text:SetShadowColor(0, 0, 0, 1)
	else
		text:SetShadowOffset(0, 0)
	end
end

function ns.CreateFontString(parent, size, justify, outline)
	local text = parent:CreateFontString(nil, "OVERLAY")
	ns.SetFont(text, size, outline)
	text:SetJustifyH(justify or "LEFT")
	text:SetWordWrap(false)
	return text
end

-- Reparenting to a hidden frame is the least invasive way to hide Blizzard
-- frames: their code keeps running untouched, so nothing else gets tainted.
-- Unregistering events additionally stops work nobody will ever see, but must
-- be skipped for frames other Blizzard systems still query.
function ns.HideBlizzard(frame, keepEvents)
	if not frame then
		return
	end
	if not keepEvents then
		frame:UnregisterAllEvents()
	end
	frame:SetParent(hiddenParent)
end

local function SecretClassColor(classFile)
	local color = C_ClassColor.GetClassColor(classFile)
	return color.r, color.g, color.b
end

-- Only values used as table keys need an issecretvalue guard; colors themselves
-- may be secret because widget color setters accept secrets.
function ns.UnitHealthColor(unit)
	if not UnitIsConnected(unit) then
		return unpack(style.offlineColor)
	end
	if UnitIsDeadOrGhost(unit) then
		return unpack(style.deadColor)
	end
	if UnitIsPlayer(unit) then
		local _, classFile = UnitClass(unit)
		if issecretvalue(classFile) then
			-- The class is secret for players outside the group, and for compound
			-- units like "targettarget" whenever any unit in the chain is (e.g.
			-- the player an enemy NPC is targeting). C_ClassColor.GetClassColor
			-- accepts a secret class from addon code, but its result can't be
			-- tested, so a failure falls back to the plain color via pcall.
			local ok, r, g, b = pcall(SecretClassColor, classFile)
			if ok then
				return r, g, b
			end
			return unpack(style.fallbackHealthColor)
		end
		local color = classFile and C_ClassColor.GetClassColor(classFile)
		if color then
			return color.r, color.g, color.b
		end
		return unpack(style.fallbackHealthColor)
	end
	if UnitIsTapDenied(unit) then
		return unpack(style.tappedColor)
	end
	return UnitSelectionColor(unit)
end

function ns.UnitPowerColor(unit)
	local powerType, powerToken, altR, altG, altB = UnitPowerType(unit)
	local color = PowerBarColor[powerToken] or PowerBarColor[powerType]
	if color then
		return color.r, color.g, color.b
	end
	if altR then
		return altR, altG, altB
	end
	return 1, 1, 1
end

-- Edit Mode and the UIParent frame manager re-anchor Blizzard frames whenever a
-- layout is applied or neighbours change size. Hooking SetPoint catches every
-- one of those paths, and the flag stops our own SetPoint from re-triggering.
function ns.PinFrame(frame, place)
	local function apply()
		frame.stevioPlacing = true
		place(frame)
		frame.stevioPlacing = nil
	end

	-- Unprotected frames may move in combat, so only protected ones wait.
	local function request()
		if frame:IsProtected() then
			ns.RunAfterCombat(apply)
		else
			apply()
		end
	end

	hooksecurefunc(frame, "SetPoint", function()
		if not frame.stevioPlacing then
			request()
		end
	end)
	request()
end

-- Hides a Blizzard frame that other systems keep showing, without reparenting
-- it, for frames Edit Mode re-parents on every layout pass.
function ns.KeepHidden(frame)
	if not frame then
		return
	end
	frame:Hide()
	hooksecurefunc(frame, "Show", frame.Hide)
	hooksecurefunc(frame, "SetShown", function(self, shown)
		if shown then
			self:Hide()
		end
	end)
end

-- Strips textures for good, because Blizzard code may re-set them on updates.
function ns.KillTexture(texture)
	if not texture then
		return
	end
	texture:SetAlpha(0)
	texture:Hide()
	hooksecurefunc(texture, "Show", texture.Hide)
end

-- Unit frame parts shared by the unit frames (Units) and the group cells (Group)
-- ------------------------------------------------------------------------------

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax

-- Health may be secret; the bar takes it as it is. Returned for callers that
-- show it as text as well.
function ns.UpdateHealthBar(bar, unit)
	local health = UnitHealth(unit)
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(health)
	return health
end

function ns.UpdatePowerBar(bar, unit)
	bar:SetMinMaxValues(0, UnitPowerMax(unit))
	bar:SetValue(UnitPower(unit))
end

function ns.SetPowerBarColor(bar, unit)
	bar:SetStatusBarColor(ns.UnitPowerColor(unit))
end

-- UNIT_DISPLAYPOWER: another power type has another color and range.
function ns.UpdatePowerType(bar, unit)
	ns.SetPowerBarColor(bar, unit)
	ns.UpdatePowerBar(bar, unit)
end

-- A border-colored line between health and power instead of a gap keeps the
-- frame one solid block. It runs along `relativeTo`'s `relativeEdge` ("TOP"
-- or "BOTTOM"), with its own `edge` there.
function ns.CreateSeparator(frame, edge, relativeTo, relativeEdge)
	local separator = frame:CreateTexture(nil, "ARTWORK")
	separator:SetColorTexture(unpack(style.borderColor))
	separator:SetPoint(edge .. "LEFT", relativeTo, relativeEdge .. "LEFT")
	separator:SetPoint(edge .. "RIGHT", relativeTo, relativeEdge .. "RIGHT")
	separator:SetHeight(ns.PixelSize(frame))
end

-- A cropped aura icon with a cooldown swipe, a stack count and a border.
function ns.StyleAuraIcon(icon, size, countSize)
	icon:SetSize(size, size)

	icon.texture = icon:CreateTexture(nil, "ARTWORK")
	icon.texture:SetAllPoints()
	ns.CropIcon(icon.texture)

	icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
	icon.cooldown:SetAllPoints()
	icon.cooldown:SetReverse(true)
	icon.cooldown:SetDrawEdge(false)
	icon.cooldown:SetHideCountdownNumbers(true)

	icon.count = ns.CreateFontString(icon, countSize, "RIGHT")
	icon.count:SetPoint("BOTTOMRIGHT", 1, -1)

	ns.CreateBorder(icon)
	ns.CreateInnerEdge(icon, true)
end

-- Sets up a button of Blizzard's secure aura container. This runs once per
-- button before Blizzard locks it against tainted access while auras are
-- secret, so it is the only place our code may touch it.
function ns.InitAuraButton(button, size, countSize)
	button:EnableMouse(false)
	ns.StyleAuraIcon(button, size, countSize)
	button:SetIcon(button.texture)
	button:SetDurationCooldown(button.cooldown)
	button:SetApplicationCount(button.count)
end

-- An initializeFrame callback for AuraContainer:AddAuraGroup.
function ns.AuraButtonInitializer(size, countSize)
	return function(button)
		ns.InitAuraButton(button, size, countSize)
	end
end

-- Whether Blizzard's aura containers accept `filter` (AuraUtil.IsValidFilterString).
function ns.IsValidAuraFilter(filter)
	if type(filter) ~= "string" then
		return false
	end
	return AuraUtil.IsValidFilterString(filter) and true or false
end

-- Blizzard's secure aura container with one aura group, growing in
-- `options.growth` and then down. Its calls stay in one fixed order, as the
-- template may depend on it: `options.place(container)` sizes and anchors it
-- right after creation, then the setup, the group, the unit (if given) and
-- enabling last. `options`: place, flowAnchor, growth, key, filter, max,
-- spacing, initializeFrame, unit, and noMouse for display-only icons.
function ns.CreateAuraContainer(parent, options)
	local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
	options.place(container)
	container:SetEditModePreviewEnabled(false)
	if options.noMouse then
		container:EnableMouse(false)
	end
	container:SetFlowLayoutAnchorPoint(options.flowAnchor)
	container:SetFlowLayoutGrowthDirection(options.growth, AnchorUtil.FlowDirection.Down)
	-- Filters can be edited in the options panel. Blizzard's container asserts
	-- on an invalid one, which would break the whole cell or frame; with the
	-- same check first, only this group stays empty and the typo is reported.
	if ns.IsValidAuraFilter(options.filter) then
		container:AddAuraGroup(options.key, options.filter, {
			maxFrameCount = options.max,
			layout = { elementSpacing = options.spacing },
			initializeFrame = options.initializeFrame,
		})
	else
		geterrorhandler()(("invalid aura filter %q (%s)"):format(tostring(options.filter), options.key))
	end
	if options.unit then
		container:SetUnit(options.unit)
	end
	container:SetEnabled(true)
	return container
end
