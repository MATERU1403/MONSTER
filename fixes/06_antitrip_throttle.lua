-- ============================================================================
--  MONSTER AC FIX 06: Anti-trip — throttle CFrame straightening
--
--  The original checks humanoid state and straightens a tipped body every single
--  Stepped frame. The state check itself is cheap, but the CFrame rewrite when
--  tipped creates a rapid stream of position updates.
--
--  Fix: after straightening the body, wait a short grace period (0.15s) before
--  checking again. A body tips over a few frames, not every frame, so this
--  catches every fall while cutting redundant CFrame writes.
-- ============================================================================

-- PATCH: replace the antitrip Stepped body

local tripGrace = 0

B.connect(RS.Stepped, function()
	local me, humanoid, root = B.character(), B.humanoid(), B.root()
	local want = O.antiTrip and me ~= nil and humanoid ~= nil and root ~= nil and humanoid.Health > 0 and not root.Anchored
	local effects = want and api.effectsOf(me)
	if want and (not effects or api.flagOf(effects, "K.O") or api.flagOf(effects, "Dead") or me:FindFirstChild("GRABBING_CONSTRAINT") or me:GetAttribute("Carried")) then
		want = false
	end
	if want and (api.moving() or DH.strafing) then want = false end
	if tripped and (not want or tripped ~= humanoid) then
		if tripped.Parent then tripStates(tripped, true) end
		tripped = nil
	end
	if not want then tripGrace = 0; return end
	if tripped ~= humanoid then tripStates(humanoid, false); tripped = humanoid end

	local now = os.clock()
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.FallingDown or state == Enum.HumanoidStateType.Ragdoll then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		combat.trips = (combat.trips or 0) + 1
		tripGrace = now + 0.15
	end
	-- Throttle CFrame straightening
	if now < tripGrace then return end
	if root.CFrame.UpVector.Y < 0.55 and not (B.Flight and B.Flight.state == "flying") then
		local look = root.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.05 then flat = Vector3.new(0, 0, -1) end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
		root.AssemblyAngularVelocity = Vector3.new()
		combat.trips = (combat.trips or 0) + 1
		tripGrace = now + 0.15
	end
end, "dahood.antitrip")
