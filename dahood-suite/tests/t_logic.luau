return function(T, env)
	T.suite_("logic")
	local V, CF = env.Vector3, env.CFrame
	local SMF = require("../pure/voidsm")()
	local Threat = require("../pure/threat")()
	local Targeting = require("../pure/targeting")()
	local Modes = require("../pure/modes")(env)

	-- ---- void phases
	local function drive(m, from, to, threat, step)
		local last
		local t = from
		while t <= to + 1e-9 do
			local near = threat
			if type(threat) == "function" then near = threat(t) end
			last = m:update(t, near)
			t += step or 0.02
		end
		return last
	end

	T.test("void: bait delay, then voided, then released after a calm hold", function()
		local m = SMF.new()
		m:request("key", 0)
		local s = m:update(0.0, false)
		T.eq(s.phase, "bait"); T.falsy(s.voided)
		s = drive(m, 0.02, 0.3, false)
		T.eq(s.phase, "voided"); T.truthy(s.voided)
		m:cancel("key")
		s = m:update(0.31, false)
		T.truthy(s.voided, "not released at once")
		s = drive(m, 0.32, 1.2, false)
		T.eq(s.phase, "idle"); T.falsy(s.voided)
		T.eq(m.releases, 1)
	end)

	T.test("void: a threat near extends the hold", function()
		local m = SMF.new()
		m:request("key", 0)
		drive(m, 0, 0.5, false)
		m:cancel("key")
		-- a threat stays near until t = 3: the body must still be voided at 3.4 and gone after a calm 0.6 s
		local s = drive(m, 0.5, 3.4, function(t) return t < 3 end)
		T.truthy(s.voided, "still voided with a threat near")
		s = drive(m, 3.4, 3.5, false)
		T.truthy(s.voided, "calm hold (0.6 s since the last threat) not over")
		s = drive(m, 3.5, 4.0, false)
		T.falsy(s.voided, "released after a full calm hold")
	end)

	T.test("void: a persistent request holds the void for as long as it is made", function()
		local m = SMF.new()
		m:request("defense", 0)
		local s = drive(m, 0, 30, false)
		T.truthy(s.voided)
		m:cancel("defense")
		s = drive(m, 30.02, 31.5, false)
		T.falsy(s.voided)
	end)

	T.test("void: a ttl request lapses by itself", function()
		local m = SMF.new()
		m:request("dead", 0, 1.0)
		local s = drive(m, 0, 0.9, false)
		T.truthy(s.voided)
		s = drive(m, 0.92, 2.6, false)
		T.falsy(s.voided)
	end)

	T.test("void: a bait that is cancelled before it fires never voids", function()
		local m = SMF.new()
		m:request("key", 0)
		m:update(0.0, false)
		m:cancel("key")
		local s = m:update(0.05, false)
		T.eq(s.phase, "idle"); T.falsy(s.voided)
	end)

	T.test("void: respawn ramp holds 3.2 s, then steps down while threats stay", function()
		local m = SMF.new()
		m:respawned(0)
		local s = m:update(0.0, true)
		T.truthy(s.voided); T.eq(s.ramp, 1)
		s = drive(m, 0.02, 3.1, true)
		T.truthy(s.voided, "long hold under threat")
		s = m:update(3.21, true)
		T.eq(s.phase, "peek"); T.falsy(s.voided)
		-- the threat is still there at the peek: next, shorter hold
		s = drive(m, 3.22, 3.4, true)
		T.eq(s.ramp, 2)
		T.truthy(s.voided)
		-- 0.55 s later a peek, threat again: hold 3 (0.25), then 4 (0.15)
		s = drive(m, 3.4, 4.4, true)
		T.truthy(s.ramp >= 3, "stepped down to " .. tostring(s.ramp))
		s = drive(m, 4.4, 8, true)
		T.eq(s.ramp, 4, "stays at the last, shortest hold while threatened")
	end)

	T.test("void: respawn ramp releases at the first calm peek", function()
		local m = SMF.new()
		m:respawned(0)
		drive(m, 0, 3.3, false)
		local s = drive(m, 3.3, 3.5, false)
		T.eq(s.phase, "idle"); T.falsy(s.voided)
	end)

	T.test("void: a persistent request ends the ramp", function()
		local m = SMF.new()
		m:respawned(0)
		m:request("key", 0.5)
		local s = drive(m, 0.5, 6, false)
		T.truthy(s.voided); T.eq(s.ramp, nil)
	end)

	-- ---- threats
	local me = { pos = V.new(0, 0, 0), ko = false, health = 100, armor = 0, protected = false }
	local function other(id, x, tool, extra)
		local o = { id = id, pos = V.new(x, 0, 0), tool = tool or "gun", ko = false, friend = false, protected = false }
		for k, v in pairs(extra or {}) do o[k] = v end
		return o
	end

	T.test("threat: friends, knocked, protected and unarmed players are not threats", function()
		T.eq(Threat.score(me, other("f", 20, "gun", { friend = true })), 0)
		T.eq(Threat.score(me, other("k", 20, "gun", { ko = true })), 0)
		T.eq(Threat.score(me, other("p", 20, "gun", { protected = true })), 0)
		T.eq(Threat.score(me, other("u", 20, "none")), 0)
		T.eq(Threat.score({ pos = me.pos, protected = true }, other("g", 20, "gun")), 0, "I am protected")
	end)

	T.test("threat: a gun counts out to its range, nearer is worse, aiming at me adds", function()
		local near, far = Threat.score(me, other("a", 30)), Threat.score(me, other("b", 250))
		T.truthy(near > far and far > 0)
		T.eq(Threat.score(me, other("c", 400)), 0)
		T.truthy(Threat.score(me, other("d", 100, "gun", { aimingAtMe = true })) > Threat.score(me, other("d", 100)))
	end)

	T.test("threat: flame and melee only count up close", function()
		T.truthy(Threat.score(me, other("a", 10, "flame")) > 0.5)
		T.eq(Threat.score(me, other("a", 60, "flame")), 0)
		T.truthy(Threat.score(me, other("m", 5, "melee")) > 0)
		T.eq(Threat.score(me, other("m", 40, "melee")), 0)
	end)

	T.test("threat: anti-bag needs a knocked body and someone near or closing", function()
		local down = { pos = V.new(0, 0, 0), ko = true, health = 0 }
		T.truthy((Threat.antiBag(down, { other("a", 8, "none") })))
		T.falsy((Threat.antiBag(down, { other("a", 40, "none") })))
		T.falsy((Threat.antiBag(me, { other("a", 8, "none") })), "not knocked")
		T.truthy((Threat.antiBag(down, { other("c", 30, "none", { vel = V.new(-40, 0, 0) }) })), "closing within a second")
		T.falsy((Threat.antiBag(down, { other("c", 30, "none", { vel = V.new(40, 0, 0) }) })), "moving away")
		T.truthy((Threat.antiBag(down, { other("t", 100, "none", { teleported = true }) })), "a teleporter near a knocked body")
		T.falsy((Threat.antiBag(down, { other("f", 3, "none", { friend = true }) })), "a friend may stand close")
		T.truthy(Threat.knocked({ ko = false, health = 3 }), "health at the floor counts")
	end)

	T.test("threat: anti-flame", function()
		T.truthy((Threat.antiFlame(me, { other("a", 20, "flame") })))
		T.falsy((Threat.antiFlame(me, { other("a", 60, "flame") })))
		T.truthy((Threat.antiFlame(me, { other("a", 45, "flame", { vel = V.new(-40, 0, 0) }) })), "closing")
		T.falsy((Threat.antiFlame(me, { other("a", 20, "gun") })), "a gun is not a flame")
	end)

	T.test("threat: teleport detection", function()
		T.truthy(Threat.teleport(V.new(0, 0, 0), V.new(200, 0, 0), 0.016))
		T.falsy(Threat.teleport(V.new(0, 0, 0), V.new(1, 0, 0), 0.016))
		T.falsy(Threat.teleport(V.new(0, 0, 0), V.new(200, 0, 0), 3), "a long gap is not a teleport")
	end)

	T.test("threat: a camper is an armed player standing still near the return spot", function()
		local home = V.new(0, 0, 0)
		T.truthy((Threat.camper(home, { other("a", 100, "gun", { still = 2 }) })))
		T.falsy((Threat.camper(home, { other("a", 100, "gun", { still = 0.2 }) })))
		T.falsy((Threat.camper(home, { other("a", 400, "gun", { still = 5 }) })))
		T.falsy((Threat.camper(home, { other("a", 100, "none", { still = 5 }) })))
	end)

	T.test("threat: assess folds it all together", function()
		local a = Threat.assess(me, { other("g", 50) }, nil, V.new(0, 0, 0))
		T.truthy(a.threatNear and a.unsafe and a.top.id == "g")
		local calm = Threat.assess(me, { other("g", 500), other("u", 10, "none") })
		T.falsy(calm.threatNear); T.falsy(calm.unsafe)
		local down = Threat.assess({ pos = V.new(0, 0, 0), ko = true }, { other("x", 6, "none") })
		T.truthy(down.antiBag and down.threatNear)
		T.truthy(#down.reasons == 1)
	end)

	-- ---- targeting
	local function cand(id, x, extra)
		local c = { id = id, name = id, pos = V.new(x, 0, 0), health = 100, armor = 0, ko = false, friend = false, visible = true }
		for k, v in pairs(extra or {}) do c[k] = v end
		return c
	end
	local ctx = { mePos = V.new(0, 0, 0) }

	T.test("targeting: hard filters", function()
		local F = Targeting.filter
		T.truthy((F(cand("a", 50), ctx)))
		T.falsy((F(cand("a", 50, { self = true }), ctx)))
		T.falsy((F(cand("a", 50, { ko = true }), ctx)))
		T.falsy((F(cand("a", 50, { safeZone = true }), ctx)))
		T.falsy((F(cand("a", 50, { friend = true }), ctx)))
		T.falsy((F(cand("a", 50, { visible = false }), ctx)))
		T.falsy((F(cand("a", 50, { aimAngle = 170 }), ctx)))
		T.falsy((F(cand("a", 2000), ctx)))
		T.truthy((F(cand("a", 50, { visible = false }), ctx, { walls = false })))
		T.falsy((F(cand("a", 50, { team = 1 }), { mePos = ctx.mePos, meTeam = 1 }, { teamCheck = true })))
		T.falsy((F(cand("a", 50), { mePos = ctx.mePos, targets = { b = true } })), "not on the list")
		T.truthy((F(cand("a", 50), { mePos = ctx.mePos, targets = { a = true } })), "on the list")
	end)

	T.test("targeting: modes choose different players", function()
		local list = { cand("near", 30, { health = 90, screenDist = 400 }), cand("weak", 120, { health = 10, screenDist = 300 }), cand("aimed", 80, { health = 100, screenDist = 5 }) }
		local function pick(mode)
			local id = Targeting.pick({}, list, 0, ctx, { mode = mode })
			return id
		end
		T.eq(pick("closest-to-me"), "near")
		T.eq(pick("lowest-health"), "weak")
		T.eq(pick("closest-to-mouse"), "aimed")
		local threats = { cand("quiet", 30, { threat = 0 }), cand("armed", 150, { threat = 0.9 }) }
		T.eq((Targeting.pick({}, threats, 0, ctx, { mode = "threat" })), "armed")
		local crowd = { cand("lone", 100, { crowd = 0 }), cand("busy", 100, { crowd = 4 }) }
		T.eq((Targeting.pick({}, crowd, 0, ctx, { mode = "threat" })), "lone")
	end)

	T.test("targeting: sticky until the wait is over and the new one is clearly better", function()
		local state = {}
		local cfg = { mode = "closest-to-me", switchWait = 0.5, hysteresis = 0.15 }
		local list = { cand("a", 100), cand("b", 150) }
		T.eq((Targeting.pick(state, list, 0, ctx, cfg)), "a")
		list = { cand("a", 100), cand("b", 20) }
		T.eq((Targeting.pick(state, list, 0.2, ctx, cfg)), "a", "wait not over")
		T.eq((Targeting.pick(state, list, 0.6, ctx, cfg)), "b", "wait over and b is much nearer")
		list = { cand("a", 95), cand("b", 100) }
		T.eq((Targeting.pick(state, list, 5, ctx, cfg)), "b", "a barely better one is not worth a switch")
	end)

	T.test("targeting: a held target that fails a filter is dropped at once", function()
		local state = {}
		local cfg = { mode = "closest-to-me", switchWait = 10 }
		Targeting.pick(state, { cand("a", 100), cand("b", 200) }, 0, ctx, cfg)
		T.eq(state.id, "a")
		T.eq((Targeting.pick(state, { cand("a", 100, { ko = true }), cand("b", 200) }, 0.01, ctx, cfg)), "b")
		T.eq((Targeting.pick(state, {}, 1, ctx, cfg)), nil)
	end)

	-- ---- fake position modes
	T.test("modes: static adds a world offset and keeps the rotation", function()
		local real = CF.new(10, 5, 10) * CF.Angles(0, math.rad(90), 0)
		local cf = Modes.compute("static", Modes.new(), real, { offset = V.new(0, -40, 0) }, 0, T.rng(1))
		T.vnear(cf.Position, V.new(10, -35, 10), 1e-9)
		T.vnear(cf.LookVector, real.LookVector, 1e-6)
	end)

	T.test("modes: follow turns with the body", function()
		local real = CF.new(0, 0, 0) * CF.Angles(0, math.rad(90), 0)
		local cf = Modes.compute("follow", Modes.new(), real, { offset = V.new(0, 0, 30) }, 0, T.rng(1))
		T.vnear(cf.Position, (real * CF.new(0, 0, 30)).Position, 1e-6)
		T.truthy(math.abs(cf.Position.X) > 29, "behind a body that faces sideways is along X")
	end)

	T.test("modes: jitter stays in the radius and re-rolls on the rate", function()
		local state, rng = Modes.new(), T.rng(3)
		local real = CF.new(0, 5, 0)
		local opts = { radius = 20, rate = 100 }
		local a = Modes.compute("jitter", state, real, opts, 0, rng).Position
		local same = Modes.compute("jitter", state, real, opts, 0.05, rng).Position
		T.vnear(a, same, 1e-9)
		local seen, maxR = {}, 0
		for i = 1, 400 do
			local p = Modes.compute("jitter", state, real, opts, i * 0.11, rng).Position
			seen[#seen + 1] = p
			maxR = math.max(maxR, V.new(p.X, 0, p.Z).Magnitude)
			T.near(p.Y, 5, 1e-9)
		end
		T.truthy(maxR <= 20 + 1e-6 and maxR > 15, "inside the radius and uses it: " .. maxR)
		T.truthy((seen[1] - seen[2]).Magnitude > 0, "re-rolled")
	end)

	T.test("modes: anchor holds a world place while the body moves", function()
		local state = Modes.new()
		local a = Modes.compute("anchor", state, CF.new(1, 2, 3), {}, 0, T.rng(1))
		local b = Modes.compute("anchor", state, CF.new(100, 2, 3), {}, 1, T.rng(1))
		T.vnear(a.Position, b.Position, 1e-9)
		Modes.setAnchor(state, CF.new(7, 7, 7))
		T.vnear(Modes.compute("anchor", state, CF.new(0, 0, 0), {}, 2, T.rng(1)).Position, V.new(7, 7, 7), 1e-9)
		Modes.clearAnchor(state)
		T.vnear(Modes.compute("anchor", state, CF.new(4, 4, 4), {}, 3, T.rng(1)).Position, V.new(4, 4, 4), 1e-9)
		T.eq(Modes.compute("nonsense", state, CF.new(), {}, 0, T.rng(1)), nil)
	end)
end
