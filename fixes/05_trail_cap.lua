-- ============================================================================
--  MONSTER AC FIX 05: Ragebot trail table — rolling window cap
--
--  The trail table accumulates position history entries while the ragebot runs.
--  Over hours of continuous use this grows unbounded.
--
--  Fix: cap at 200 entries. When the cap is hit, remove the oldest half. This
--  keeps recent history intact for the placement logic while preventing a slow
--  memory leak.
-- ============================================================================

-- PATCH: add this function and call it wherever trail entries are added

local TRAIL_CAP = 200
local TRAIL_TRIM = 100              -- remove this many when the cap is hit

local function trailAdd(entry)
	trail[#trail + 1] = entry
	if #trail > TRAIL_CAP then
		-- Shift: keep the newest TRAIL_CAP - TRAIL_TRIM entries
		local keep = #trail - TRAIL_TRIM
		for i = 1, keep do
			trail[i] = trail[i + TRAIL_TRIM]
		end
		for i = keep + 1, #trail do
			trail[i] = nil
		end
	end
end
