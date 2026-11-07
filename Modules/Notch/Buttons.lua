local addonName, ns = ...

-- Moves the minimap buttons of other addons into the notch island, where they
-- sit in a grid below the other rows and stay clickable. Blizzard's own
-- buttons (looking for group, mail, tracking, ...) stay on the map.

local Buttons = {}
ns.NotchButtons = Buttons

-- Map pins (gathering nodes, waypoints, quest markers) are children of the map
-- as well, but smaller than any real button.
local MIN_BUTTON_SIZE = 20

-- The round frame and background LibDBIcon (and many hand-made buttons) draw
-- around the icon; on the island's flat black they only waste space.
local FRAME_ART = {
	[136430] = true,
	[136467] = true,
	["interface\\minimap\\minimap-trackingborder"] = true,
	["interface\\minimap\\ui-minimap-background"] = true,
}

-- Pure helpers, kept free of WoW API calls so they can be tested outside the game.

-- info: name, owner (the addon that created the frame's global, nil for
-- Blizzard), isButton, width, height.
function Buttons.IsAddonButton(info, ownAddon)
	if not info.isButton or not info.name or not info.owner or info.owner == ownAddon then
		return false
	end
	return info.width >= MIN_BUTTON_SIZE and info.height >= MIN_BUTTON_SIZE
end

-- Lays out count squares of size in lines of the given width, each line
-- centred. Returns the top left corner of each square and the total height.
function Buttons.Grid(count, width, size, gap)
	if count == 0 then
		return {}, 0
	end
	local columns = math.max(1, math.floor((width + gap) / (size + gap)))
	local positions = {}
	for index = 1, count do
		local line = math.floor((index - 1) / columns)
		local column = (index - 1) % columns
		local inLine = math.min(columns, count - line * columns)
		local offset = (width - inLine * size - (inLine - 1) * gap) / 2
		positions[index] = { x = offset + column * (size + gap), y = line * (size + gap) }
	end
	local lines = math.ceil(count / columns)
	return positions, lines * size + (lines - 1) * gap
end

-- In-game part.

local container
-- Adopted buttons in a stable order; each sits centred in its own slot frame.
local adopted, slots = {}, {}
local libDBIconHooked = false

local function OwnerOf(name)
	local secure, owner = issecurevariable(name)
	if secure then
		return nil
	end
	-- Insecure without a known source: still another addon's frame.
	return owner or "?"
end

local function StripFrameArt(button)
	for _, region in ipairs({ button:GetRegions() }) do
		if region:IsObjectType("Texture") then
			local texture = region.GetTextureFileID and region:GetTextureFileID() or region:GetTexture()
			if type(texture) == "string" then
				texture = texture:lower()
			end
			if texture and FRAME_ART[texture] then
				ns.KillTexture(region)
			end
		end
	end
	-- LibDBIcon places its icon off-centre to fit the round frame; without the
	-- frame the button shrinks to the icon.
	local icon = button.icon
	if icon and icon.IsObjectType and icon:IsObjectType("Texture") and button:GetName():find("^LibDBIcon") then
		icon:ClearAllPoints()
		icon:SetPoint("CENTER")
		button:SetSize(icon:GetSize())
	end
end

local function Adopt(button, size)
	if adopted[button] then
		return
	end
	adopted[button] = true

	local slot = CreateFrame("Frame", nil, container)
	slot:SetSize(size, size)
	slot.button = button
	slots[#slots + 1] = slot
	table.sort(slots, function(a, b)
		return a.button:GetName() < b.button:GetName()
	end)

	StripFrameArt(button)
	button:SetParent(slot)
	button:SetScale(size / math.max(button:GetWidth(), button:GetHeight()))
	if button.SetFixedFrameStrata then
		button:SetFixedFrameStrata(false)
		button:SetFixedFrameLevel(false)
	end
	button:SetFrameStrata(container:GetFrameStrata())
	button:SetFrameLevel(container:GetFrameLevel() + 5)
	button:SetAlpha(1)
	-- Dragging would move the button around the map again.
	button:RegisterForDrag()
	-- LibDBIcon's "show on mouseover" fades buttons out once the cursor leaves.
	if button.fadeOut then
		hooksecurefunc(button.fadeOut, "Play", function(animation)
			animation:Stop()
			button:SetAlpha(1)
		end)
	end
	ns.PinFrame(button, function(frame)
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", slot, "CENTER")
	end)
end

local function Consider(frame, size)
	if adopted[frame] or frame:IsProtected() then
		return
	end
	local name = frame:GetName()
	local info = {
		name = name,
		owner = name and OwnerOf(name),
		isButton = frame:IsObjectType("Button"),
		width = frame:GetWidth(),
		height = frame:GetHeight(),
	}
	if Buttons.IsAddonButton(info, addonName) then
		Adopt(frame, size)
	end
end

-- Looks for new buttons. Addons create them at any time after login, so this
-- runs again whenever the island opens.
function Buttons.Scan(size)
	if not container then
		return
	end
	for _, parent in ipairs({ Minimap, MinimapBackdrop, MinimapCluster }) do
		if parent then
			for _, child in ipairs({ parent:GetChildren() }) do
				Consider(child, size)
			end
		end
	end

	local lib = LibStub and LibStub("LibDBIcon-1.0", true)
	if lib and lib.GetButtonList then
		for _, name in ipairs(lib:GetButtonList()) do
			local button = lib:GetMinimapButton(name)
			if button then
				Consider(button, size)
			end
		end
		if not libDBIconHooked and lib.RegisterCallback then
			libDBIconHooked = true
			lib.RegisterCallback(Buttons, "LibDBIcon_IconCreated", function(_, button)
				Consider(button, size)
			end)
		end
	end
end

function Buttons.Setup(parent)
	container = parent
end

-- Places the shown buttons in a grid of the given width; returns its height.
-- Buttons their addon hides (e.g. hidden in its options) leave no gap.
function Buttons.Layout(width, size, gap)
	local shown = {}
	for _, slot in ipairs(slots) do
		local visible = slot.button:IsShown()
		slot:SetShown(visible)
		if visible then
			shown[#shown + 1] = slot
		end
	end
	local positions, height = Buttons.Grid(#shown, width, size, gap)
	for index, slot in ipairs(shown) do
		slot:SetPoint("TOPLEFT", container, "TOPLEFT", positions[index].x, -positions[index].y)
	end
	return height
end
