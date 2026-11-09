-- Fake position modes. Pure: where the server is told the body is, from where it really is.
--   static  the real place plus a fixed offset in world axes
--   follow  the real place plus an offset in the body's own frame (it turns with you)
--   jitter  a random place inside a radius of the real one, re-rolled every `rate` milliseconds
--   anchor  one world place, held while the real body moves (taken from the real body when first asked, or set)
return function(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local Modes = {}
	local sqrt, cos, sin, pi = math.sqrt, math.cos, math.sin, math.pi

	Modes.names = { "static", "follow", "jitter", "anchor" }

	---State for one use of the modes (keep it between calls).
	function Modes.new()
		return { anchor = nil, jitterAt = -math.huge, jitterOffset = Vector3.new(0, 0, 0) }
	end

	function Modes.setAnchor(state, cframe) state.anchor = cframe end
	function Modes.clearAnchor(state) state.anchor = nil end

	---@param name string
	---@param state table from Modes.new
	---@param real CFrame where the body really is
	---@param opts table { offset = Vector3, radius = number, rate = ms }
	---@param now number clock in seconds
	---@param rng table with :NextNumber() in [0, 1)
	---@return CFrame?
	function Modes.compute(name, state, real, opts, now, rng)
		if name == "static" then
			return CFrame.new(real.Position + opts.offset) * real.Rotation
		elseif name == "follow" then
			return real * CFrame.new(opts.offset)
		elseif name == "jitter" then
			local every = math.max((opts.rate or 100) / 1000, 0.005)
			if now - state.jitterAt >= every then
				local turn, reach = rng:NextNumber() * 2 * pi, sqrt(rng:NextNumber()) * (opts.radius or 10)
				state.jitterOffset = Vector3.new(cos(turn) * reach, 0, sin(turn) * reach)
				state.jitterAt = now
			end
			return CFrame.new(real.Position + state.jitterOffset) * real.Rotation
		elseif name == "anchor" then
			if not state.anchor then state.anchor = real end
			return state.anchor
		end
		return nil
	end

	return Modes
end
