-- ============================================================================
--  MONSTER AC FIX 02: No-collide throttled to every 3 Stepped frames
--
--  The original iterates ALL roster entries and ALL their joint parts every single
--  Stepped frame. With 20 players * ~15 parts = 300 CanCollide checks per frame.
--  At 60 fps that is 18,000 property reads per second.
--
--  Fix: run the full sweep every 3 frames. Parts set to CanCollide=false stay that
--  way until the game or physics resets them, which happens at most once per frame.
--  A 3-frame gap (0.05s at 60fps) is imperceptible but cuts the cost by 67%.
-- ============================================================================

-- PATCH: replace the nocollide Stepped body

local noCollideFrame = 0
local NO_COLLIDE_EVERY = 3          -- run the sweep every N Stepped frames
local NO_COLLIDE_SWEEP = 8          -- seconds between dead-reference cleanup (up from 5)

B.connect(RS.Stepped, function()
	if not O.noCollide then
		if next(unCollided) then
			for part in pairs(unCollided) do if part.Parent then part.CanCollide = true end end
			table.clear(unCollided)
		end
		noCollideFrame = 0
		return
	end
	noCollideFrame += 1
	if noCollideFrame < NO_COLLIDE_EVERY then return end
	noCollideFrame = 0

	local roster = B.Roster
	for _, entry in ipairs(roster and roster.list or {}) do
		local character = entry.character
		if character and character.Parent then
			for _, part in pairs(entry.joints or {}) do
				if part.CanCollide then part.CanCollide = false; unCollided[part] = true end
			end
			local root = entry.root
			if root and root.CanCollide then root.CanCollide = false; unCollided[root] = true end
		end
	end
	if os.clock() - sweepAt > NO_COLLIDE_SWEEP then
		sweepAt = os.clock()
		for part in pairs(unCollided) do if not part.Parent then unCollided[part] = nil end end
	end
end, "dahood.nocollide")
