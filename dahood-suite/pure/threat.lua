-- Defense decisions. Pure: every "is this a threat / should the body go to the void" question is a function of plain tables,
-- so each can be tested without a game.
--
-- me      = { pos = Vector3, ko = bool, health = number, maxHealth = number, armor = number, protected = bool }
-- other   = { id, pos = Vector3, vel = Vector3?, ko = bool, friend = bool, protected = bool, tool = "gun"|"flame"|"melee"|"none",
--             aimingAtMe = bool?, still = number? (seconds standing still), teleported = bool? }
return function()
	local Threat = {}
	local max, min, clamp = math.max, math.min, math.clamp

	Threat.DEFAULT = {
		safeDistance = 90,   -- inside this, an armed player is a threat
		gunRange = 300,      -- a gun reaches this far
		flameRange = 25,
		meleeRange = 10,
		bagRange = 12,       -- a knocked body can be picked up from this close
		bagLead = 1.0,       -- seconds: someone who will be within bagRange this soon counts as there already
		teleportJump = 80,   -- studs in one sample
		teleportRange = 150, -- a teleporter this close to a knocked body is a bagger
		koHealth = 5,        -- a body at or under this health counts as knocked
		baitStill = 1.0,     -- seconds an armed player stands still near the return spot to count as a camper
		baitRange = 160,
		unsafeScore = 0.25,  -- a score at or above this makes the strafe override's `unsafe` true
	}

	local function cfgOf(cfg)
		if not cfg then return Threat.DEFAULT end
		if getmetatable(cfg) == nil then setmetatable(cfg, { __index = Threat.DEFAULT }) end
		return cfg
	end

	function Threat.knocked(me, cfg)
		cfg = cfgOf(cfg)
		return me.ko == true or (me.health ~= nil and me.health <= cfg.koHealth)
	end

	local function counts(other)
		return other and not other.friend and not other.ko and not other.protected
	end

	---Can this player hurt me from where they are? 0 (no) to about 1 (certainly): by what they hold and how far.
	function Threat.score(me, other, cfg)
		cfg = cfgOf(cfg)
		if not counts(other) or me.protected then return 0 end
		local dist = (other.pos - me.pos).Magnitude
		local base
		if other.tool == "gun" then
			if dist > cfg.gunRange then return 0 end
			base = 0.5 + 0.5 * clamp(1 - dist / cfg.gunRange, 0, 1)
		elseif other.tool == "flame" then
			if dist > cfg.flameRange * 2 then return 0 end
			base = clamp(1.2 - dist / (cfg.flameRange * 2), 0, 1.2)
		elseif other.tool == "melee" then
			if dist > cfg.meleeRange * 2 then return 0 end
			base = clamp(1 - dist / (cfg.meleeRange * 2), 0, 1) * 0.8
		else
			return 0
		end
		if other.aimingAtMe then base *= 1.5 end
		return base
	end

	---Seconds until `other` is within `range` of me going at its own speed (math.huge when it is not closing).
	function Threat.timeToReach(me, other, range)
		local offset = me.pos - other.pos
		local dist = offset.Magnitude
		if dist <= range then return 0 end
		local vel = other.vel
		if not vel or offset.Magnitude < 1e-6 then return math.huge end
		local closing = vel:Dot(offset.Unit)
		if closing <= 0.5 then return math.huge end
		return (dist - range) / closing
	end

	---A jump too big for a body walking: someone who appears next to a knocked player to bag it.
	---@param prev Vector3 @param cur Vector3 @param dt number
	function Threat.teleport(prev, cur, dt, cfg)
		cfg = cfgOf(cfg)
		if not prev or not cur then return false end
		local d = (cur - prev).Magnitude
		return d >= cfg.teleportJump and (dt or 0) < 0.5
	end

	---Anti-bag: I am knocked and someone is near, or about to be (or a teleporter is near).
	---@return boolean, string?
	function Threat.antiBag(me, players, cfg)
		cfg = cfgOf(cfg)
		if not Threat.knocked(me, cfg) then return false end
		for _, other in ipairs(players) do
			if counts(other) then
				local dist = (other.pos - me.pos).Magnitude
				if dist <= cfg.bagRange then return true, "near:" .. tostring(other.id) end
				if Threat.timeToReach(me, other, cfg.bagRange) <= cfg.bagLead then return true, "closing:" .. tostring(other.id) end
				if other.teleported and dist <= cfg.teleportRange then return true, "teleporter:" .. tostring(other.id) end
			end
		end
		return false
	end

	---Anti-flame: a flamethrower within reach, or closing on me fast enough to be.
	---@return boolean, string?
	function Threat.antiFlame(me, players, cfg)
		cfg = cfgOf(cfg)
		if me.protected then return false end
		for _, other in ipairs(players) do
			if counts(other) and other.tool == "flame" then
				local dist = (other.pos - me.pos).Magnitude
				if dist <= cfg.flameRange then return true, "flame:" .. tostring(other.id) end
				if Threat.timeToReach(me, other, cfg.flameRange) <= cfg.bagLead then return true, "closing:" .. tostring(other.id) end
			end
		end
		return false
	end

	---Anti-bait: an armed player standing still near where I would come back out is waiting for me; stay hidden.
	---@param returnPos Vector3 where the body goes when released
	---@return boolean, string?
	function Threat.camper(returnPos, players, cfg)
		cfg = cfgOf(cfg)
		for _, other in ipairs(players) do
			if counts(other) and (other.tool == "gun" or other.tool == "flame") and (other.still or 0) >= cfg.baitStill then
				if (other.pos - returnPos).Magnitude <= cfg.baitRange then return true, "camper:" .. tostring(other.id) end
			end
		end
		return false
	end

	---The whole picture for one frame.
	---@return table { threatNear, unsafe, top, antiBag, antiFlame, camper, reasons }
	function Threat.assess(me, players, cfg, returnPos)
		cfg = cfgOf(cfg)
		local top, topScore, near = nil, 0, false
		for _, other in ipairs(players) do
			local score = Threat.score(me, other, cfg)
			if score > topScore then top, topScore = other, score end
			if score > 0 and (other.pos - me.pos).Magnitude <= cfg.safeDistance then near = true end
		end
		local bag, bagWhy = Threat.antiBag(me, players, cfg)
		local flame, flameWhy = Threat.antiFlame(me, players, cfg)
		local camp, campWhy = false, nil
		if returnPos then camp, campWhy = Threat.camper(returnPos, players, cfg) end
		local reasons = {}
		if bag then reasons[#reasons + 1] = bagWhy end
		if flame then reasons[#reasons + 1] = flameWhy end
		if camp then reasons[#reasons + 1] = campWhy end
		return {
			threatNear = near or bag or flame,
			unsafe = topScore >= cfg.unsafeScore,
			top = top, topScore = topScore,
			antiBag = bag, antiFlame = flame, camper = camp,
			reasons = reasons,
		}
	end

	return Threat
end
