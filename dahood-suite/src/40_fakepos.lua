-- ---- fakepos: where the server is told the body is. The driver loop is the Desync block below (it owns the body swap and the
-- strike hooks); this module computes the new modes, arbitrates the sources that may ask for a place, and reports.
-- Priority when things collide: panic > defense void > physrep ride > ragebot / api > the configured mode > normal movement.
local Modes = DH.F.modes(DH.ENV)
local Orbit = DH.F.orbit(DH.ENV)
DH.Orbit = Orbit
local Fakepos = {
	state = Modes.new(), rng = Random.new(), sources = {}, backend = "off", degraded = false,
	panicked = false, owner = "none", server = nil, real = nil, orbitVelocity = nil,
}
DH.Fakepos = Fakepos

Fakepos.MODES = {
	{ "static", "Static offset" }, { "follow", "Follow offset" }, { "jitter", "Jitter" }, { "anchor", "Anchor" }, { "thunder", "Orbit strafe (sky)" },
}
local OWN = { static = true, follow = true, jitter = true, anchor = true, thunder = true }

DH.define("monster.fakepos.offX", { kind = "slider", default = 0, min = -300, max = 300, step = 1, label = "Offset X", desc = "Static / Follow: right (+) or left (-).", group = "fakepos" })
DH.define("monster.fakepos.offY", { kind = "slider", default = 0, min = -300, max = 300, step = 1, label = "Offset Y", desc = "Static / Follow: up (+) or down (-).", group = "fakepos" })
DH.define("monster.fakepos.offZ", { kind = "slider", default = 30, min = -300, max = 300, step = 1, label = "Offset Z", desc = "Static / Follow: behind (+) or in front (-).", group = "fakepos" })
DH.define("monster.fakepos.radius", { kind = "slider", default = 25, min = 1, max = 150, step = 1, label = "Jitter radius", desc = "Jitter: how far from you they see you.", group = "fakepos", suffix = " st" })
DH.define("monster.fakepos.rate", { kind = "slider", default = 120, min = 20, max = 1000, step = 10, label = "Jitter rate", desc = "Jitter: milliseconds between new places.", group = "fakepos", suffix = " ms" })
DH.define("monster.fakepos.anchorKey", { kind = "keybind", default = "None", label = "Anchor key", desc = "Anchor: press to hold where you stand; press again to let go.", group = "fakepos" })
DH.define("monster.fakepos.resetOnKO", { kind = "toggle", default = true, label = "Reset on KO", desc = "A knock clears the anchor and the jitter.", group = "fakepos" })
DH.define("monster.fakepos.backend", { kind = "dropdown", default = "auto", label = "Backend", desc = "Auto: raknet when it works, else the body swap. Velocity is unmeasured.", group = "fakepos",
	options = { { "auto", "Auto" }, { "raknet", "Raknet" }, { "swap", "Body swap" }, { "velocity", "Velocity (unmeasured)" } } })
DH.define("monster.fakepos.orbitAround", { kind = "dropdown", default = "target", label = "Orbit around", desc = "Orbit strafe: the target (you, when nobody is near) or always yourself.", group = "fakepos",
	options = { { "target", "The target" }, { "me", "Me" } } })
DH.define("monster.fakepos.moveReal", { kind = "toggle", default = false, label = "Push the real body (orbit)", desc = "Orbit strafe also runs your own body round the target (capped on the ground).", group = "fakepos" })

---The orbit settings as a params table for Orbit.step, from K; the sky variant stays inside what a packet can carry.
function Fakepos.orbitParams(packets)
	local K = DH.K.get
	local p = {
		speed = K("ORBIT_SPEED"), radius = K("ORBIT_RADIUS"), heightHigh = K("ORBIT_H1"), heightLow = K("ORBIT_H2"), heightRate = K("ORBIT_FLIP"),
		jitterH = K("ORBIT_JIT_H"), jitterV = K("ORBIT_JIT_V"), jitterRate = K("ORBIT_JIT_RATE"), jitterFlip = 0.025, velocity = K("ORBIT_VEL"),
	}
	if packets then
		p.heightHigh, p.heightLow = math.min(p.heightHigh, 900), math.min(p.heightLow, 870)
		p.radius = math.min(p.radius, 400)
	end
	return p
end

---The new modes, for the Desync block's fakeOf: nil for any mode that is not one of these.
---@param where string
---@param real CFrame where the body really is
---@param centre Vector3? what the orbit goes round (the target; nil = you)
---@param packets boolean whether raknet carries the result (then it is kept inside |coord| < 1000)
---@return CFrame?
function Fakepos.compute(where, real, centre, packets)
	if not OWN[where] then return nil end
	local now = os.clock()
	if where ~= "thunder" then Fakepos.orbitVelocity = nil end
	if where == "thunder" then
		if DH.get("monster.fakepos.orbitAround") == "me" then centre = real.Position end
		local cf, velocity = Orbit.step(now, centre or real.Position, real.Position, Fakepos.orbitParams(packets))
		if packets then cf = Orbit.fit(cf, 1000) end
		Fakepos.orbitVelocity = DH.get("monster.fakepos.moveReal") and velocity or nil
		return cf
	end
	local opts = {
		offset = Vector3.new(DH.get("monster.fakepos.offX"), DH.get("monster.fakepos.offY"), DH.get("monster.fakepos.offZ")),
		radius = DH.get("monster.fakepos.radius"), rate = DH.get("monster.fakepos.rate"),
	}
	local cf = Modes.compute(where, Fakepos.state, real, opts, now, Fakepos.rng)
	if cf and packets then cf = Orbit.fit(cf, 1000) end
	return cf
end

---The real body's push for the orbit strafe, capped while it stands on the ground (the game's speed lock is 40 studs/s).
function Fakepos.applyVelocity(root)
	local velocity = Fakepos.orbitVelocity
	if not velocity or not root then return end
	local humanoid = DH.humanoid()
	local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	if grounded and velocity.Magnitude > DH.K.get("ORBIT_GROUND_CAP") then velocity = velocity.Unit * DH.K.get("ORBIT_GROUND_CAP") end
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, root.AssemblyLinearVelocity.Y, velocity.Z)
end

-- ---- sources: who may ask for a place, by priority
Fakepos.PRIORITY = { panic = 5, defense = 4, rage = 3, net = 2.5, api = 2.5 }

---Ask for the server body to be at `value` (a CFrame, or a function(real) -> CFrame?). nil withdraws the request.
function Fakepos.setSource(name, value, priority)
	if value == nil then Fakepos.sources[name] = nil; return end
	if typeof(value) == "CFrame" and value == CFrame.new() then Fakepos.sources[name] = nil; return end -- (identity means off)
	Fakepos.sources[name] = { value = value, priority = priority or Fakepos.PRIORITY[name] or 2.5 }
end
function Fakepos.clearSource(name) Fakepos.sources[name] = nil end
---True when some source wants a place right now (a source that returns nil this step does not count).
function Fakepos.hasForced()
	if Fakepos.panicked or next(Fakepos.sources) == nil then return false end
	local root = DH.root()
	return Fakepos.forced(root and root.CFrame or CFrame.new()) ~= nil
end
---The CFrame the highest-priority source wants this step (nil: none). Asked twice in a step (wanted, then fakeOf): answered once.
function Fakepos.forced(real)
	if Fakepos.panicked then return nil end
	local stamp = os.clock()
	if Fakepos.cache and Fakepos.cache.real == real and stamp - Fakepos.cache.t < 0.004 then return Fakepos.cache.result end
	local result = Fakepos.pickSource(real)
	Fakepos.cache = { real = real, t = stamp, result = result }
	return result
end
function Fakepos.pickSource(real)
	local best, bestPriority
	for name, source in pairs(Fakepos.sources) do
		if not bestPriority or source.priority > bestPriority then best, bestPriority = name, source.priority end
	end
	if not best then Fakepos.owner = DH.get("monster.fake") and "config" or "none"; return nil end
	local value = Fakepos.sources[best].value
	local cf = value
	if type(value) == "function" then
		local ok, result = pcall(value, real)
		if not ok then DH.fail("fakepos.source:" .. best, result); return nil end
		cf = result
	end
	if cf ~= nil then Fakepos.owner = best end
	return cf
end

---A physrep ride or a panic suspends the configured modes (the ride and the fake position never run together).
function Fakepos.suspended()
	return Fakepos.panicked or (DH.Physrep ~= nil and DH.Physrep.isAttached())
end

---Published by the driver each step.
function Fakepos.publish(real, server, backend)
	Fakepos.real, Fakepos.server = real, server
	if backend then Fakepos.backend, Fakepos.degraded = backend, backend ~= "raknet" end
end
function Fakepos.getServerCFrame() return Fakepos.server or Fakepos.real end
function Fakepos.getRealCFrame()
	local root = DH.root()
	return root and root.CFrame or Fakepos.real
end

---Anchor key: hold where you stand, or let go.
function Fakepos.toggleAnchor()
	local root = DH.root()
	if Fakepos.state.anchor then
		Modes.clearAnchor(Fakepos.state)
		return false
	end
	if root then Modes.setAnchor(Fakepos.state, root.CFrame); return true end
	return false
end
---A knock (or a stop) resets what the modes remember, by setting.
function Fakepos.onIdle(character)
	if DH.get("monster.fakepos.resetOnKO") and (DH.knocked(character) or not character) then
		Fakepos.state = Modes.new()
	end
end

function Fakepos.panic() Fakepos.panicked = true; Fakepos.sources = {} end
function Fakepos.unpanic() Fakepos.panicked = false end

function Fakepos.init() end
function Fakepos.enable() DH.set("monster.fake", true, true) end
function Fakepos.disable()
	Fakepos.sources = {}
	Fakepos.server = nil
	DH.set("monster.fake", false, true)
	DH.set("monster.desync", false, true)
	Fakepos.state = Modes.new()
end
function Fakepos.status()
	return {
		mode = DH.get("monster.fakeWhere"), enabled = DH.get("monster.fake") == true or DH.get("monster.desync") == true,
		backend = Fakepos.backend, degraded = Fakepos.degraded, owner = Fakepos.owner, panicked = Fakepos.panicked,
		sources = (function() local names = {}; for name in pairs(Fakepos.sources) do names[#names + 1] = name end; return names end)(),
		anchored = Fakepos.state.anchor ~= nil,
		server = Fakepos.server and { Fakepos.server.X, Fakepos.server.Y, Fakepos.server.Z } or nil,
		suspended = Fakepos.suspended(),
	}
end
DH.register("fakepos", Fakepos)
