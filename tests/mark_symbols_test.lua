-- Run with: lua tests/mark_symbols_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = loadAddonFile("Modules/Marks/Symbols.lua")
local Symbols = ns.MarkSymbols

-- All eight raid target indices, each once, skull first.
check(#Symbols.LIST == 8, "eight symbols")
local seenIndex, seenWorld = {}, {}
for _, symbol in ipairs(Symbols.LIST) do
	check(not seenIndex[symbol.index], "raid target index used once: " .. symbol.index)
	check(not seenWorld[symbol.world], "ground marker index used once: " .. symbol.world)
	seenIndex[symbol.index] = true
	seenWorld[symbol.world] = true
	check(symbol.name[1] and symbol.name[2], "English and German name")
end
for i = 1, 8 do
	check(seenIndex[i] and seenWorld[i], "index " .. i .. " covered")
end
check(Symbols.LIST[1].index == 8 and Symbols.LIST[8].index == 1, "skull to star")
print("symbols ok")

-- Ground markers use their own numbering (1 blue square ... 8 white skull).
local function World(index)
	for _, symbol in ipairs(Symbols.LIST) do
		if symbol.index == index then
			return symbol.world
		end
	end
end
check(World(8) == 8, "skull")
check(World(7) == 4, "cross")
check(World(6) == 1, "square")
check(World(5) == 7, "moon")
check(World(4) == 2, "triangle")
check(World(3) == 3, "diamond")
check(World(2) == 6, "circle")
check(World(1) == 5, "star")
check(Symbols.Texture(8) == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "texture path")
print("ground markers ok")

-- Secure attributes. Blizzard's SecureActionButton_OnClick ignores a mouse
-- release unless useOnKeyDown is false (ActionButtonUseKeyDown is on by default),
-- and these buttons only register releases.
local skull = Symbols.LIST[1]
local mark = Symbols.Attributes(skull, true)
check(mark.useOnKeyDown == false, "acts on the mouse release")
check(mark.unit == "target" and mark.type1 == "raidtarget", "left click marks the target")
check(mark.action1 == "toggle" and mark.marker1 == 8, "left click toggles the skull")
check(mark.type2 == "worldmarker", "right click places a ground marker")
check(mark.unit2 == "none", "ground markers need no target")
check(mark.action2 == "toggle" and mark.marker2 == 8, "right click toggles the skull ground marker")

local clear = Symbols.Attributes(nil, true)
check(clear.useOnKeyDown == false, "clear acts on the mouse release")
check(clear.action1 == "clear" and clear.marker1 == nil, "left click unmarks the target")
check(clear.action2 == "clear" and clear.marker2 == nil, "right click removes all ground markers")
check(clear.unit2 == "none", "clearing ground markers needs no target")

local noGround = Symbols.Attributes(skull, false)
check(noGround.type2 == nil and noGround.unit2 == nil, "no right click without ground markers")
print("attributes ok")
