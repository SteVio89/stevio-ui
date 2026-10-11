local _, ns = ...

local style = ns.config.style

ns.hiddenParent = CreateFrame("Frame")
ns.hiddenParent:Hide()

function ns.PixelSize(region)
	return PixelUtil.ConvertPixelsToUIForRegion(1, region)
end

function ns.SetPoint(frame, layout, relativeTo)
	frame:ClearAllPoints()
	frame:SetPoint(layout.point, relativeTo or UIParent, layout.relativePoint or layout.point, layout.x or 0, layout.y or 0)
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

-- Lets the client resolve possibly-secret booleans (e.g. UnitIsUnit in combat).
function Border:SetShownFromBoolean(value)
	if issecretvalue(value) then
		for _, edge in ipairs(self) do
			edge:Show()
			edge:SetAlphaFromBoolean(value, 1, 0)
		end
	else
		for _, edge in ipairs(self) do
			edge:SetAlpha(1)
		end
		self:SetShown(value)
	end
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

function ns.CreateBackground(frame)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(unpack(style.backgroundColor))
	return bg
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
	frame:SetParent(ns.hiddenParent)
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
			ns:RunAfterCombat(apply)
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
