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

-- Near-black backdrop of small overlay panels (Quickjump badges, flight list).
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

function ns.CreateFontString(parent, size, justify)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFont(style.font, size or style.fontSize, style.fontFlags)
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
		local color = classFile and not issecretvalue(classFile) and C_ClassColor.GetClassColor(classFile)
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
