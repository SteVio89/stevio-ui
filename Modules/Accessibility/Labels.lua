local _, ns = ...

-- Shared between the accessibility files; only ns.QuickJump and
-- ns.QuickJumpLeader (Bindings.xml) are meant for the rest of the addon.
local Internal = {}
ns.AccessibilityInternal = Internal

-- The quick-jump label logic, kept free of WoW API calls so it can be tested
-- outside the game.
local Labels = {}
Internal.Labels = Labels

-- Adds `left .. right` labels for every pair, the first letter varying
-- fastest, until `labels` holds `count`.
local function AddLabels(labels, count, leftKeys, rightKeys)
	for _, right in ipairs(rightKeys) do
		for _, left in ipairs(leftKeys) do
			if #labels == count then
				return
			end
			labels[#labels + 1] = left .. right
		end
	end
end

-- The first letter varies fastest, so the first labels all differ already in
-- the first keystroke. Windows with more targets than the base keys can label
-- borrow extra first letters for the targets after those; they are only ever
-- leader-activated, so taking movement keys is fine there. The base labels
-- stay the same however many targets follow. Never more labels than the keys
-- can make.
function Labels.Generate(count, leftKeys, rightKeys, extraLeftKeys)
	local labels = {}
	AddLabels(labels, count, leftKeys, rightKeys)
	AddLabels(labels, count, extraLeftKeys, rightKeys)
	return labels
end

-- What to bind after `typed`: one step { index, letter, final, narrow } per
-- label still matching, in label order, with the letter typed next. A final
-- letter clicks the target; otherwise the first label with that letter
-- (`narrow`) narrows the selection, and the others share its binding.
function Labels.NextStep(labels, typed)
	local steps = {}
	local nextLetters = {}
	for index, label in ipairs(labels) do
		if label:sub(1, #typed) == typed then
			local letter = label:sub(#typed + 1, #typed + 1)
			local step = { index = index, letter = letter, final = #label == #typed + 1, narrow = false }
			if not step.final and not nextLetters[letter] then
				nextLetters[letter] = true
				step.narrow = true
			end
			steps[#steps + 1] = step
		end
	end
	return steps
end

-- Badge text: the typed part in `typedHex` ("ffrrggbb") and in its case, so a
-- pending right click is visible as e.g. "F", then the rest in lowercase.
function Labels.BadgeText(label, typed, rightClick, typedHex)
	local remaining = label:sub(#typed + 1)
	local shownTyped = rightClick and typed:upper() or typed:lower()
	return (#typed > 0 and ("|c%s%s|r"):format(typedHex, shownTyped) or "") .. remaining:lower()
end

-- Sort order of targets: top to bottom, then left to right, so labels follow
-- reading order. Tops within a pixel count as one line.
function Labels.ByPosition(a, b)
	local aTop, bTop = a:GetTop() or 0, b:GetTop() or 0
	if math.abs(aTop - bTop) > 1 then
		return aTop > bTop
	end
	return (a:GetLeft() or 0) < (b:GetLeft() or 0)
end
