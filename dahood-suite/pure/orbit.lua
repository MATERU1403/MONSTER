-- Orbit strafe. Pure: `Orbit.step(t, center, myPos, params)` -> CFrame the server body is given, velocity for the real body.
-- The numbers of the default preset are the ones asked for: a turn at 28 rad/s on a ring of 135 studs, the height flipping
-- between 200000 and 199500 twenty times a second, a jitter of 10 studs about the ring and 5 up or down every 0.025 s,
-- and the real body pushed round the target at 420 studs/s with the part of the move that points at the target removed.
return function(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local Orbit = {}
	local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs
	local ZERO = Vector3.new(0, 0, 0)

	Orbit.PRESETS = {
		-- the default: far above the target, a body nobody can follow
		thunder = { speed = 28, radius = 135, heightHigh = 200000, heightLow = 199500, heightRate = 20, jitterH = 10, jitterV = 5, jitterRate = 80, jitterFlip = 0.025, velocity = 420 },
		-- the same turn kept inside the packet format (|coords| < 1024): high over the map, not past it
		sky = { speed = 28, radius = 135, heightHigh = 900, heightLow = 870, heightRate = 20, jitterH = 10, jitterV = 5, jitterRate = 80, jitterFlip = 0.025, velocity = 420 },
		-- close in, at the target's own height, for use without a void
		low = { speed = 6, radius = 10, heightHigh = 0, heightLow = 0, heightRate = 20, jitterH = 0, jitterV = 0, jitterRate = 80, jitterFlip = 0.025, velocity = 60 },
	}
	Orbit.DEFAULT = "thunder"

	---Fill what `params` leaves out from a preset.
	---@param params table|string|nil preset name, or a table of overrides
	---@return table
	function Orbit.resolve(params)
		local base = Orbit.PRESETS[Orbit.DEFAULT]
		if type(params) == "string" then base = Orbit.PRESETS[params] or base; params = nil end
		if not params then return base end
		local out = table.clone(base)
		for key, value in pairs(params) do out[key] = value end
		return out
	end

	---The server body's place and the real body's velocity at time t.
	---@param t number clock in seconds
	---@param center Vector3 what is orbited (the target, or a locked bait position)
	---@param myPos Vector3 where the real body is
	---@param params table|string|nil
	---@return CFrame, Vector3, table
	function Orbit.step(t, center, myPos, params)
		local p = Orbit.resolve(params)
		local angle = t * p.speed
		local around = Vector3.new(sin(angle) * p.radius, 0, cos(angle) * p.radius)
		local high = floor(t * p.heightRate) % 2 == 0
		local height = high and p.heightHigh or p.heightLow
		local flip = (floor(t / p.jitterFlip) % 2 == 0) and p.jitterV or -p.jitterV
		local jitter = Vector3.new(sin(t * p.jitterRate) * p.jitterH, flip, cos(t * p.jitterRate) * p.jitterH)
		local finalPos = center + around + Vector3.new(0, height, 0) + jitter

		-- the real body goes round the target on the ground: toward the ring, never toward the middle
		local move = (center + around) - myPos
		move = Vector3.new(move.X, 0, move.Z)
		local inward = Vector3.new(center.X - myPos.X, 0, center.Z - myPos.Z)
		if inward.Magnitude > 1e-3 then
			local unit = inward.Unit
			local along = move:Dot(unit)
			if along > 0 then move = move - unit * along end
		end
		local velocity = ZERO
		if move.Magnitude > 1e-3 then velocity = move.Unit * p.velocity end

		-- The body looks at the centre along the ground (level): a body 200000 up that looked straight down at it would have a
		-- yaw nobody can define, and the packet format only carries an upright body's yaw anyway.
		local facing = CFrame.new(finalPos)
		if Vector3.new(center.X - finalPos.X, 0, center.Z - finalPos.Z).Magnitude > 1e-3 then
			facing = CFrame.lookAt(finalPos, Vector3.new(center.X, finalPos.Y, center.Z))
		end
		return facing, velocity, { angle = angle, height = height, high = high, jitter = jitter }
	end

	---Keep a position inside what a packet can carry. Returns the CFrame (same look target) and whether it was cut.
	---@param cframe CFrame
	---@param limit number|nil default 1000
	---@return CFrame, boolean
	function Orbit.fit(cframe, limit)
		limit = limit or 1000
		local p = cframe.Position
		if abs(p.X) <= limit and abs(p.Y) <= limit and abs(p.Z) <= limit then return cframe, false end
		local cut = Vector3.new(math.clamp(p.X, -limit, limit), math.clamp(p.Y, -limit, limit), math.clamp(p.Z, -limit, limit))
		return CFrame.new(cut) * cframe.Rotation, true
	end

	return Orbit
end
