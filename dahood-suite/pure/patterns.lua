-- Movement patterns for the ragebot, each a pure function (targetPos, t, k, ctx) -> CFrame, the body looking at the target.
-- `k` holds the dahood.k.* numbers (names without the prefix); `ctx` is optional: { vel = Vector3, look = Vector3 }.
-- The names are the ones the user's config carries (RING_, POUNCE_, LURE_, HAUNT_, AMBUSH_, PRESS_, SWARM_); what each pattern
-- does with them is defined here, in the comments, and is not a copy of anything: BasedHub's own versions are not this.
return function(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local Patterns = {}
	local sin, cos, floor, max, min, pi = math.sin, math.cos, math.floor, math.max, math.min, math.pi

	Patterns.DEFAULT_K = {
		RING_CLEAR = 35, RING_HOLD = 0.25, RING_STEP = 34,
		POUNCE_HIGH = 200, POUNCE_LOW = 24, POUNCE_MARKS = 24, POUNCE_OUT = 150, POUNCE_STAY = 0.5, POUNCE_PERIOD = 2,
		LURE_BALL = 60, LURE_HIGH = 90, LURE_REST = 0.6, LURE_RISE = 60, LURE_SHOW = 0.25,
		HAUNT_APART = 20, HAUNT_MOST = 110, HAUNT_MEMORY = 6,
		AMBUSH_GRID = 28, AMBUSH_LEAST = 3, AMBUSH_MARKS = 24, AMBUSH_RANGE = 180, AMBUSH_STAY = 0.33,
		PRESS_HEX = 36, PRESS_NEAR = 14, PRESS_OUTSIDE = 15, PRESS_PERIOD = 1,
		SWARM_CLEAR = 27, SWARM_FAR = 80, SWARM_MIN = 60, SWARM_STEP = 38,
	}

	local function num(k, name)
		local value = k and k[name]
		if value == nil then value = Patterns.DEFAULT_K[name] end
		return value
	end

	local function at(target, angle, radius, height)
		local spot = target + Vector3.new(sin(angle) * radius, height or 0, cos(angle) * radius)
		if radius < 1e-3 then return CFrame.new(spot) end
		return CFrame.lookAt(spot, Vector3.new(target.X, spot.Y, target.Z)) -- (level: upright, facing the target)
	end

	-- ring: a new place on a ring of RING_CLEAR studs round the target every RING_HOLD s, RING_STEP studs of arc along
	function Patterns.ring(target, t, k)
		local radius, hold, step = num(k, "RING_CLEAR"), max(num(k, "RING_HOLD"), 0.02), num(k, "RING_STEP")
		return at(target, floor(t / hold) * step / max(radius, 1), radius, 0)
	end

	-- pounce: out at POUNCE_OUT studs and POUNCE_HIGH up, then down to POUNCE_LOW studs from the target for POUNCE_STAY s
	-- every POUNCE_PERIOD s; the bearing moves one of POUNCE_MARKS places each time
	function Patterns.pounce(target, t, k)
		local period = max(num(k, "POUNCE_PERIOD"), num(k, "POUNCE_STAY") + 0.05)
		local cycle = floor(t / period)
		local marks = max(floor(num(k, "POUNCE_MARKS")), 1)
		local bearing = (cycle % marks) * 2 * pi / marks
		if t - cycle * period < num(k, "POUNCE_STAY") then return at(target, bearing, num(k, "POUNCE_LOW"), 0) end
		return at(target, bearing, num(k, "POUNCE_OUT"), num(k, "POUNCE_HIGH"))
	end

	-- lure: shown at LURE_BALL studs and LURE_RISE up for LURE_SHOW s, then hidden LURE_HIGH up for LURE_REST s
	function Patterns.lure(target, t, k)
		local show, rest = num(k, "LURE_SHOW"), num(k, "LURE_REST")
		local length = max(show + rest, 0.05)
		local cycle = floor(t / length)
		local bearing = cycle * 2.399963 -- the golden angle: no two shows in a row from the same side
		if t - cycle * length < show then return at(target, bearing, num(k, "LURE_BALL"), num(k, "LURE_RISE")) end
		return at(target, bearing, num(k, "LURE_BALL"), num(k, "LURE_HIGH"))
	end

	-- haunt: HAUNT_APART studs behind where the target is heading (its look when it stands), never past HAUNT_MOST
	function Patterns.haunt(target, t, k, ctx)
		local heading
		if ctx and ctx.vel and Vector3.new(ctx.vel.X, 0, ctx.vel.Z).Magnitude > 1 then
			heading = Vector3.new(ctx.vel.X, 0, ctx.vel.Z).Unit
		elseif ctx and ctx.look and Vector3.new(ctx.look.X, 0, ctx.look.Z).Magnitude > 0.01 then
			heading = Vector3.new(ctx.look.X, 0, ctx.look.Z).Unit
		else
			heading = Vector3.new(sin(t * 0.5), 0, cos(t * 0.5))
		end
		local apart = min(num(k, "HAUNT_APART"), num(k, "HAUNT_MOST"))
		if apart < 1e-3 then return CFrame.new(target) end
		local spot = target - heading * apart
		return CFrame.lookAt(spot, Vector3.new(target.X, spot.Y, target.Z))
	end

	-- ambush: AMBUSH_MARKS places on a spiral of spacing AMBUSH_GRID out to AMBUSH_RANGE, one every AMBUSH_STAY s
	-- (never nearer than AMBUSH_LEAST); the caller picks among them by what it can see
	function Patterns.ambush(target, t, k)
		local marks, grid = max(floor(num(k, "AMBUSH_MARKS")), 1), num(k, "AMBUSH_GRID")
		local index = floor(t / max(num(k, "AMBUSH_STAY"), 0.02)) % marks
		local radius = min(max(num(k, "AMBUSH_LEAST"), (index + 1) * grid / 3), num(k, "AMBUSH_RANGE"))
		return at(target, index * 2.399963, radius, 0)
	end

	-- press: the six corners of a hexagon, PRESS_NEAR studs out and PRESS_OUTSIDE further on the odd turns,
	-- one corner every PRESS_PERIOD / 6 s
	function Patterns.press(target, t, k)
		local period = max(num(k, "PRESS_PERIOD"), 0.06)
		local corner = floor(t / (period / 6))
		local radius = num(k, "PRESS_NEAR") + (corner % 2 == 1 and num(k, "PRESS_OUTSIDE") or 0)
		return at(target, (corner % 6) * pi / 3, radius, 0)
	end

	-- swarm: places SWARM_STEP studs of arc apart on a ring that breathes between SWARM_MIN and SWARM_FAR
	function Patterns.swarm(target, t, k)
		local low, high, clear = num(k, "SWARM_MIN"), num(k, "SWARM_FAR"), num(k, "SWARM_CLEAR")
		local radius = max(clear, low + (high - low) * (0.5 + 0.5 * sin(t * 0.8)))
		return at(target, floor(t / 0.2) * num(k, "SWARM_STEP") / max(radius, 1), radius, 0)
	end

	Patterns.list = { "ring", "pounce", "lure", "haunt", "ambush", "press", "swarm" }

	---@param name string
	---@return fun(target: Vector3, t: number, k: table?, ctx: table?): CFrame
	function Patterns.get(name) return Patterns[name] end

	-- how far from the target a pattern can put the body: [low, high] (the heights are on top, for the sky ones)
	Patterns.reach = {
		ring = function(k) return num(k, "RING_CLEAR"), num(k, "RING_CLEAR") end,
		pounce = function(k) return num(k, "POUNCE_LOW"), num(k, "POUNCE_OUT") end,
		lure = function(k) return num(k, "LURE_BALL"), num(k, "LURE_BALL") end,
		haunt = function(k) return 0, num(k, "HAUNT_MOST") end,
		ambush = function(k) return num(k, "AMBUSH_LEAST"), num(k, "AMBUSH_RANGE") end,
		press = function(k) return num(k, "PRESS_NEAR"), num(k, "PRESS_NEAR") + num(k, "PRESS_OUTSIDE") end,
		swarm = function(k) return min(num(k, "SWARM_CLEAR"), num(k, "SWARM_MIN")), max(num(k, "SWARM_FAR"), num(k, "SWARM_CLEAR")) end,
	}

	return Patterns
end
