-- Run with: lua tests/action_sets_test.lua  (from the repo root)
local ns = {}
assert(loadfile("Modules/ActionBars/Sets.lua"))("stevio-ui", ns)
local Sets = ns.ActionSets

local function check(cond, msg)
	if not cond then
		error("FAIL: " .. msg, 2)
	end
end

local fireball = { type = "spell", id = 133 }
local heal = { type = "spell", id = 2050 }
local potion = { type = "item", id = 118 }

check(Sets.Same(nil, nil), "two empty slots")
check(not Sets.Same(fireball, nil), "spell vs empty")
check(Sets.Same(fireball, { type = "spell", id = 133 }), "same spell")
check(not Sets.Same(fireball, heal), "different spells")
check(not Sets.Same({ type = "item", id = 133 }, fireball), "same id, different type")
check(
	Sets.Same({ type = "macro", id = 3, name = "Mount" }, { type = "macro", id = 5, name = "Mount" }),
	"macros by name"
)
check(
	not Sets.Same({ type = "macro", id = 3, name = "Mount" }, { type = "macro", id = 3, name = "Heal" }),
	"renamed macro"
)

-- Only differing slots change; slots beyond the main bar (other bars, pages) count too.
local current = { [1] = fireball, [2] = potion, [61] = fireball }
local wanted = { [1] = heal, [2] = potion, [62] = heal, [100] = potion }
local changes = Sets.Changes(current, wanted)
check(#changes == 4, "four slots differ")
check(changes[1].slot == 1 and changes[1].action == heal, "replace")
check(changes[2].slot == 61 and changes[2].action == nil, "clear")
check(changes[3].slot == 62 and changes[3].action == heal, "fill")
check(changes[4].slot == 100, "bonus bar page")
check(#Sets.Changes(wanted, wanted) == 0, "nothing to do")
check(#Sets.Changes({ [181] = heal }, {}) == 0, "beyond the last slot")

check(Sets.Next(1, 2) == 2 and Sets.Next(2, 2) == 1, "wraps")
check(Sets.Next(nil, 3) == 1, "starts at one")
check(Sets.Next(1, 0) == nil, "no sets")

local names = { "Leveling", "Healing" }
check(Sets.Find(names, "healing") == 2, "by name")
check(Sets.Find(names, "1") == 1, "by number")
check(Sets.Find(names, "3") == nil, "number out of range")
check(Sets.Find(names, "tank") == nil, "unknown name")

print("action_sets_test: ok")
