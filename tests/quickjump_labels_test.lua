-- Run with: lua tests/quickjump_labels_test.lua  (from the repo root)
local check, loadAddonFile = dofile("tests/helpers.lua")
local ns = loadAddonFile("Modules/Accessibility/Labels.lua")
local Labels = ns.AccessibilityInternal.Labels

-- The keys of Modules/Accessibility/Config.lua: 9 x 9 base labels, 6 extra first letters.
local left = { "F", "G", "R", "T", "V", "B", "C", "X", "Y" }
local right = { "H", "U", "I", "O", "P", "N", "M", "L", "Z" }
local extra = { "D", "S", "A", "E", "W", "Q" }

local function generate(count)
	return Labels.Generate(count, left, right, extra)
end

check(#generate(0) == 0, "no targets, no labels")

-- The first letter varies fastest.
local labels = generate(11)
check(labels[1] == "FH" and labels[2] == "GH" and labels[9] == "YH", "first letter first")
check(labels[10] == "FU" and labels[11] == "GU", "then the second")

local function unique(list)
	local seen = {}
	for _, label in ipairs(list) do
		if seen[label] then
			return false
		end
		seen[label] = true
	end
	return true
end

-- 81 fit the base keys; one more brings in the extra first letters, which
-- changes the order of all labels.
labels = generate(81)
check(#labels == 81 and unique(labels), "81 base labels")
check(labels[10] == "FU" and labels[81] == "YZ", "base keys only")
labels = generate(82)
check(#labels == 82 and unique(labels), "82 labels")
check(labels[10] == "DH" and labels[15] == "QH" and labels[16] == "FU", "extra first letters")
check(#left == 9, "the keys are not changed")

-- 15 x 9 is the most there can be.
labels = generate(200)
check(#labels == 135 and unique(labels) and labels[135] == "QZ", "capped at 135")

-- Binding plan: before typing, one narrowing step per first letter.
local steps = Labels.NextStep({ "FH", "GH", "FU" }, "")
check(#steps == 3, "every label is shown")
check(steps[1].index == 1 and steps[1].letter == "F" and steps[1].narrow and not steps[1].final, "narrow by F")
check(steps[2].letter == "G" and steps[2].narrow, "narrow by G")
check(steps[3].index == 3 and steps[3].letter == "F" and not steps[3].narrow and not steps[3].final, "F bound once")

-- After the first letter: only matching labels, each a final click.
steps = Labels.NextStep({ "FH", "GH", "FU" }, "F")
check(#steps == 2, "only matching labels")
check(steps[1].index == 1 and steps[1].letter == "H" and steps[1].final and not steps[1].narrow, "click FH")
check(steps[2].index == 3 and steps[2].letter == "U" and steps[2].final, "click FU")
check(#Labels.NextStep({ "FH" }, "G") == 0, "nothing matches")

-- Badge texts.
check(Labels.BadgeText("FH", "", false, "ff808080") == "fh", "untyped label")
check(Labels.BadgeText("FH", "F", false, "ff808080") == "|cff808080f|rh", "typed part greyed")
check(Labels.BadgeText("FH", "F", true, "ff808080") == "|cff808080F|rh", "right click shows uppercase")

-- Reading order: top to bottom, left to right; tops within a pixel are one line.
local function frame(name, top, leftEdge)
	return {
		name = name,
		GetTop = function()
			return top
		end,
		GetLeft = function()
			return leftEdge
		end,
	}
end
local targets = {
	frame("low", 100, 0),
	frame("right", 200.5, 50),
	frame("left", 200, 10),
	frame("unplaced", nil, nil),
	frame("top", 300, 90),
}
table.sort(targets, Labels.ByPosition)
local order = {}
for i, target in ipairs(targets) do
	order[i] = target.name
end
check(table.concat(order, " ") == "top left right low unplaced", "reading order")

print("quickjump labels tests passed")
