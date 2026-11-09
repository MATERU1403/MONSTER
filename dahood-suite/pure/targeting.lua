-- Ragebot target choice. Pure: filters, scores and the sticky pick, over plain tables.
--
-- candidate = { id, name, pos = Vector3, health, armor, ko, dead, friend, team, safeZone, forceField, visible = bool?,
--               screenDist = number? (pixels from the mouse), aimAngle = number? (degrees off the camera line),
--               threat = number? (0..1, from Threat.score), crowd = number? (other targets within 60 studs) }
-- ctx       = { mePos = Vector3, meTeam = any, targets = { [id or name] = true }? }
return function()
	local T = {}
	local huge = math.huge

	T.MODES = { "closest-to-mouse", "closest-to-me", "lowest-health", "threat" }

	T.DEFAULT = {
		mode = "threat",
		fov = 160,            -- degrees off the camera line (dahood.aimFov), when the candidate has an aimAngle
		walls = true,         -- the candidate must be visible (dahood.walls)
		teamCheck = false,
		ignoreFriends = true,
		range = 900,
		switchWait = 0.14,    -- dahood.switchWait
		threatWeight = 4,     -- dahood.threatWeight
		spreadWeight = 2.5,   -- dahood.spreadWeight
		hysteresis = 0.15,    -- a new best must beat the held target by this much (relative) to be worth a switch
	}

	local function cfgOf(cfg)
		if not cfg then return T.DEFAULT end
		if getmetatable(cfg) == nil then setmetatable(cfg, { __index = T.DEFAULT }) end
		return cfg
	end

	---Hard filters: nobody who fails one is ever a target.
	---@return boolean, string?
	function T.filter(c, ctx, cfg)
		cfg = cfgOf(cfg)
		if c.self then return false, "self" end
		if c.ko or c.dead then return false, "ko" end
		if c.safeZone then return false, "safezone" end
		if c.forceField then return false, "shield" end
		if cfg.ignoreFriends and c.friend then return false, "friend" end
		if cfg.teamCheck and c.team ~= nil and ctx.meTeam ~= nil and c.team == ctx.meTeam then return false, "team" end
		if ctx.targets and next(ctx.targets) ~= nil and not (ctx.targets[c.id] or ctx.targets[c.name]) then return false, "not listed" end
		if cfg.walls and c.visible == false then return false, "wall" end
		if c.aimAngle and cfg.fov and c.aimAngle > cfg.fov then return false, "fov" end
		if ctx.mePos and (c.pos - ctx.mePos).Magnitude > cfg.range then return false, "range" end
		return true
	end

	---Higher is better.
	function T.score(mode, c, ctx, cfg)
		cfg = cfgOf(cfg)
		local dist = ctx.mePos and (c.pos - ctx.mePos).Magnitude or 0
		if mode == "closest-to-mouse" then
			return -(c.screenDist or c.aimAngle or dist)
		elseif mode == "closest-to-me" then
			return -dist
		elseif mode == "lowest-health" then
			return -((c.health or 100) + (c.armor or 0))
		end
		-- threat: who can hurt me first, then who is alone, then who is near
		local alone = 1 / (1 + (c.crowd or 0))
		return cfg.threatWeight * (c.threat or 0) + cfg.spreadWeight * alone - dist / 400
	end

	---Pick a target and keep it. The held one is kept while it passes the filters; a better one replaces it only after
	---`switchWait` seconds since the last switch and by `hysteresis`. A held one that fails a filter is dropped at once.
	---@param state table { id = any?, since = number } (keep it between calls)
	---@param candidates table[]
	---@param now number
	---@return any, table state, table? entry
	function T.pick(state, candidates, now, ctx, cfg)
		cfg = cfgOf(cfg)
		local best, bestScore, held, heldScore = nil, -huge, nil, -huge
		for _, c in ipairs(candidates) do
			if T.filter(c, ctx, cfg) then
				local s = T.score(cfg.mode, c, ctx, cfg)
				if s > bestScore then best, bestScore = c, s end
				if c.id == state.id then held, heldScore = c, s end
			end
		end
		if held then
			if best and best.id ~= held.id and now - (state.since or 0) >= cfg.switchWait
				and bestScore > heldScore + math.abs(heldScore) * cfg.hysteresis + 1e-9 then
				state.id, state.since = best.id, now
				return best.id, state, best
			end
			return held.id, state, held
		end
		if best and (state.id == nil or now - (state.since or 0) >= 0) then
			state.id, state.since = best.id, now
			return best.id, state, best
		end
		state.id = nil
		return nil, state
	end

	return T
end
