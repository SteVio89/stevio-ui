local _, ns = ...

-- Decides whether the notch island is shown, from the cursor position alone.
-- Kept free of WoW API calls so it can be tested outside the game.

local Zone = {}
ns.NotchZone = Zone

-- A rect is { left, right, bottom } in UIParent units. It has no top: the
-- cursor cannot leave the screen upwards, and an open top avoids rounding
-- trouble at the very top pixel row, where the cursor sits behind the notch.
function Zone.Contains(rect, x, y, margin)
	margin = margin or 0
	return rect ~= nil and x >= rect.left - margin and x <= rect.right + margin and y >= rect.bottom - margin
end

function Zone.New()
	return { shown = false, outside = 0 }
end

-- input: x, y (cursor), cursorHidden (mouselook), notch and island rects.
-- options: hideDelay (seconds outside before hiding), margin (around the island).
-- Returns whether the island should be shown.
function Zone.Step(state, input, elapsed, options)
	if input.cursorHidden then
		-- Turning the camera: the island would only block the view. It comes
		-- back on the next poll if the cursor reappears inside the notch.
		state.shown, state.outside = false, 0
	elseif Zone.Contains(input.notch, input.x, input.y) then
		state.shown, state.outside = true, 0
	elseif state.shown then
		if Zone.Contains(input.island, input.x, input.y, options.margin) then
			state.outside = 0
		else
			state.outside = state.outside + elapsed
			if state.outside >= options.hideDelay then
				state.shown, state.outside = false, 0
			end
		end
	end
	return state.shown
end
