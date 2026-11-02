-- ============================================================================
--  MONSTER AC FIX 04: Respect the server's jump cooldown
--
--  The original writes JumpPower back every Stepped frame when the game sets it
--  to 0 after five rapid jumps. The server knows about the cooldown and sees jumps
--  happening during a window it enforces.
--
--  Fix: track the last 5 jump times. If 5 jumps happened within 3 seconds, respect
--  the 1.5s cooldown the game imposes before writing JumpPower back. The server's
--  window is its own, not ours to override.
-- ============================================================================

-- PATCH: replace the nojumpcd Stepped body

local jumpTimes = {}
local JUMP_WINDOW = 3.0              -- seconds: 5 jumps in this window triggers cooldown
local JUMP_COOLDOWN = 1.55           -- seconds: the game's own 1.5s + a small margin
local jumpCooldownUntil = 0

B.connect(RS.Stepped, function()
	if not O.noJumpCd then return end
	local me, humanoid = B.character(), B.humanoid()
	local effects = me and api.effectsOf(me)
	if not (humanoid and effects) or humanoid.Health <= 0 or humanoid.JumpPower > 0 then return end
	-- Knocked, cuffed, grabbed, movement-locked: leave the game's 0 alone
	if api.flagOf(effects, "K.O") or api.flagOf(effects, "Cuff") or me:FindFirstChild("GRABBING_CONSTRAINT") then return end
	local movement = effects:FindFirstChild("Movement")
	if movement and (movement:FindFirstChild("NoJumping") or movement:FindFirstChild("NoWalkSpeed")) then return end
	local grabbed = effects:FindFirstChild("Grabbed")
	if grabbed and grabbed.Value then return end

	local now = os.clock()
	-- Respect the server's cooldown after 5 rapid jumps
	if now < jumpCooldownUntil then return end

	-- Track this jump restore
	jumpTimes[#jumpTimes + 1] = now
	-- Trim old entries
	while #jumpTimes > 0 and now - jumpTimes[1] > JUMP_WINDOW do
		table.remove(jumpTimes, 1)
	end
	-- 5 jumps in the window: enter cooldown
	if #jumpTimes >= 5 then
		jumpCooldownUntil = now + JUMP_COOLDOWN
		table.clear(jumpTimes)
		return
	end

	humanoid.JumpPower = Config.get("dahood.jump") and Config.get("dahood.jumpValue") or 50
end, "dahood.nojumpcd")
