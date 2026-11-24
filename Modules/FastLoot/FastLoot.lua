local _, ns = ...

local config = ns.config.fastLoot
local FastLoot = ns.RegisterModule("fastLoot", {})

-- With auto loot on (the client setting, inverted while the auto loot modifier
-- is held) every slot is taken at once as soon as the loot is ready, instead of
-- one by one through Blizzard's loot window. The window stays invisible while
-- that happens and only appears if something is left after `revealDelay`.

local lastLoot = 0
local revealTimer

-- Testable without the game: the slots to take, last first (taking a slot can
-- move the ones behind it), skipping locked ones (master loot, someone else's).
-- `slots` lists one { locked = bool } per loot slot.
function FastLoot.SlotsToLoot(slots)
	local list = {}
	for index = #slots, 1, -1 do
		if not slots[index].locked then
			list[#list + 1] = index
		end
	end
	return list
end

-- LOOT_READY can fire twice for the same loot; the second one finds the slots
-- already requested.
function FastLoot.IsRepeat(now, last, gap)
	return now - last < gap
end

local function SetWindowShown(shown)
	if LootFrame then
		LootFrame:SetAlpha(shown and 1 or 0)
	end
end

local function Reveal()
	if revealTimer then
		revealTimer:Cancel()
		revealTimer = nil
	end
	SetWindowShown(true)
end

local function OnLootReady(_, autoLoot)
	if autoLoot == nil then
		autoLoot = GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")
	end
	if not autoLoot then
		return
	end
	local now = GetTime()
	if FastLoot.IsRepeat(now, lastLoot, config.revealDelay) then
		return
	end
	lastLoot = now

	local slots = {}
	for index = 1, GetNumLootItems() do
		slots[index] = { locked = select(6, GetLootSlotInfo(index)) }
	end
	SetWindowShown(false)
	for _, index in ipairs(FastLoot.SlotsToLoot(slots)) do
		LootSlot(index)
	end
	if revealTimer then
		revealTimer:Cancel()
	end
	revealTimer = C_Timer.NewTimer(config.revealDelay, Reveal)
end

function FastLoot:OnEnable()
	ns.RegisterEvent("LOOT_READY", OnLootReady)
	ns.RegisterEvent("LOOT_CLOSED", Reveal)
end
