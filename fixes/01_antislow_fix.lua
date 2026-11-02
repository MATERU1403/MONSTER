-- ============================================================================
--  MONSTER AC FIX 01: Anti-slow CFrame carry — rate-limited to avoid rubberbanding
--
--  The original adds CFrame displacement every Heartbeat when WalkSpeed is below
--  normal. The server sees movement faster than the authorized WalkSpeed, which
--  triggers position correction (rubberbanding).
--
--  Fix: cap the carry so the total effective speed never exceeds what the server
--  would accept (WalkSpeed + a small margin). Also accumulate fractional movement
--  rather than applying it every frame, and skip frames where the delta is too small
--  to matter.
-- ============================================================================

-- PATCH: replace the antislow Heartbeat body (dahood_combat.lua, around the original
-- `B.connect(RS.Heartbeat, function(dt) if not O.antiSlow ...` block)

-- The server tolerates about 10% over the WalkSpeed it set. Beyond that it corrects.
local CARRY_MARGIN = 0.08          -- 8% over normal: safely under the 10% seen
local CARRY_MIN_DELTA = 0.001      -- studs: below this the frame is skipped (no micro-jitter)
local carryAccum = Vector3.zero

B.connect(RS.Heartbeat, function(dt)
	if not O.antiSlow or api.moving() or DH.strafing then
		carryAccum = Vector3.zero
		return
	end
	local me, root, humanoid = B.character(), B.root(), B.humanoid()
	if not (me and root and humanoid) or humanoid.Health <= 0 or root.Anchored then
		carryAccum = Vector3.zero
		return
	end
	local walk, direction = humanoid.WalkSpeed, humanoid.MoveDirection
	local normal = (Config.get("dahood.speed") and math.max(Config.get("dahood.speedValue") or 16, 16)) or 16
	if walk <= 0 or walk >= normal or direction.Magnitude < 0.05 or Config.get("dahood.speed") then
		carryAccum = Vector3.zero
		return
	end
	-- Cap: the carry brings the effective speed to normal + margin, not beyond
	local maxCarry = normal * (1 + CARRY_MARGIN) - walk
	local carry = math.min(maxCarry, normal - walk)
	if carry <= 0 then return end

	local delta = direction.Unit * (carry * math.min(dt, 0.1))
	carryAccum += delta

	-- Only apply when accumulated displacement is meaningful
	if carryAccum.Magnitude < CARRY_MIN_DELTA then return end

	root.CFrame += carryAccum
	-- Animate at the real speed the body travels
	gait(me, humanoid, (walk + carry) * math.min(direction.Magnitude, 1))
	carryAccum = Vector3.zero
end, "dahood.antislow")
