-- Run with: lua tests/mark_symbols_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")

local ns = loadAddonFile("Modules/Marks/Symbols.lua")
local Symbols = ns.MarkSymbols

-- All eight raid target indices, each once, skull first.
check(#Symbols.LIST == 8, "eight symbols")
local seenIndex = {}
for _, symbol in ipairs(Symbols.LIST) do
	check(not seenIndex[symbol.index], "raid target index used once: " .. symbol.index)
	seenIndex[symbol.index] = true
	check(symbol.name[1] and symbol.name[2], "English and German name")
end
for i = 1, 8 do
	check(seenIndex[i], "index " .. i .. " covered")
end
check(Symbols.LIST[1].index == 8 and Symbols.LIST[8].index == 1, "skull to star")
print("symbols ok")

check(Symbols.Texture(8) == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", "texture path")
print("texture ok")

-- Secure attributes. Blizzard's SecureActionButton_OnClick ignores a mouse
-- release unless useOnKeyDown is false (ActionButtonUseKeyDown is on by default),
-- and these buttons only register releases.
local skull = Symbols.LIST[1]
local mark = Symbols.Attributes(skull)
check(mark.useOnKeyDown == false, "acts on the mouse release")
check(mark.unit == "target" and mark.type1 == "raidtarget", "left click marks the target")
check(mark.action1 == "toggle" and mark.marker1 == 8, "left click toggles the skull")
check(mark.type2 == nil, "no right click action")

local clear = Symbols.Attributes(nil)
check(clear.useOnKeyDown == false, "clear acts on the mouse release")
check(clear.action1 == "clear" and clear.marker1 == nil, "left click unmarks the target")
print("attributes ok")
