return function(T, env)
	T.suite_("physrep+config")
	local V, CF = env.Vector3, env.CFrame
	local serde = require("@lune/serde")
	local PhysF = require("../pure/physcore")(env)
	local StoreF = require("../pure/cfgstore")()

	-- ---- physrep over a mock io
	local function world()
		local w = { clock = 0, props = {}, parts = {}, writes = {}, nilRejected = false, refuseWrite = false, refuseRead = false }
		local me = { name = "myRoot", pos = V.new(0, 0, 0) }
		local them = { name = "theirRoot", pos = V.new(10, 0, 0) }
		w.me, w.them = me, them
		w.parts[me], w.parts[them] = true, true
		w.io = {
			now = function() return w.clock end,
			isPart = function(x) return type(x) == "table" and x.name ~= nil end,
			inWorld = function(p) return w.parts[p] == true end,
			isLocal = function(p) return p == me end,
			localRoot = function() return me end,
			distance = function(a, b) return (a.pos - b.pos).Magnitude end,
			get = function(part, name)
				if w.refuseRead then return false, "unsupported property" end
				return true, w.props[part]
			end,
			set = function(part, name, value)
				if w.refuseWrite then return false, "access denied" end
				if value == nil and w.nilRejected then return false, "nil rejected" end
				w.writes[#w.writes + 1] = value
				w.props[part] = value
				return true
			end,
		}
		return w
	end

	T.test("physrep: attach saves the original, writes the target, detach restores", function()
		local w = world()
		local p = PhysF.new(w.io)
		T.truthy((p:attach(w.them)))
		T.truthy(p:isAttached()); T.eq(p:getTarget(), w.them)
		T.eq(w.props[w.me], w.them)
		p:detach("test")
		T.falsy(p:isAttached())
		T.eq(w.props[w.me], nil, "nil restored")
		T.eq(p:status().lastReason, "test")
		p:detach("again")
		T.eq(p.detaches, 1, "detach is idempotent")
	end)

	T.test("physrep: a nil that is refused is replaced by the local root", function()
		local w = world()
		w.nilRejected = true
		local p = PhysF.new(w.io)
		p:attach(w.them)
		p:detach("test")
		T.eq(w.props[w.me], w.me, "own root written back")
	end)

	T.test("physrep: refuses what it should", function()
		local w = world()
		local p = PhysF.new(w.io)
		T.falsy((p:attach(nil)))
		T.falsy((p:attach({ name = "gone" })), "not in the world")
		T.falsy((p:attach(w.me)), "own character")
		p:setPanic(true)
		local ok, why = p:attach(w.them)
		T.falsy(ok); T.eq(why, "panic")
		p:setPanic(false)
		p:setDefense(true)
		local _, why2 = p:attach(w.them)
		T.eq(why2, "defense void active")
	end)

	T.test("physrep: a refused write disables the feature and says why", function()
		local w = world()
		w.refuseWrite = true
		local p = PhysF.new(w.io)
		local ok, why = p:attach(w.them)
		T.falsy(ok)
		T.truthy(string.find(why, "access denied", 1, true))
		T.truthy(p:status().disabled)
		T.falsy((p:attach(w.them)), "stays disabled")
		local w2 = world()
		w2.refuseRead = true
		local p2 = PhysF.new(w2.io)
		local _, why2 = p2:attach(w2.them)
		T.truthy(string.find(why2, "unsupported property", 1, true))
	end)

	T.test("physrep: every reason lets go", function()
		local reasons = {
			{ { panic = true }, "panic" }, { { defense = true }, "defense void" }, { { localKO = true }, "local KO" },
			{ { localRespawned = true }, "local respawn" }, { { targetKO = true }, "target KO" }, { { targetDead = true }, "target dead" },
			{ { targetGone = true }, "target left" },
		}
		for _, case in ipairs(reasons) do
			local w = world()
			local p = PhysF.new(w.io)
			p:attach(w.them)
			local still, reason = p:tick(case[1])
			T.falsy(still, case[2]); T.eq(reason, case[2])
			T.eq(w.props[w.me], nil, "restored after " .. case[2])
		end
		-- the target's part destroyed (it respawned)
		local w = world(); local p = PhysF.new(w.io); p:attach(w.them)
		w.parts[w.them] = nil
		local _, why = p:tick({})
		T.eq(why, "target part gone (respawn)")
		-- a new target requested
		w = world(); p = PhysF.new(w.io); p:attach(w.them)
		local other = { name = "other", pos = V.new(5, 0, 0) }
		w.parts[other] = true
		local _, why2 = p:tick({ requested = other })
		T.eq(why2, "target changed")
		-- out of range
		w = world(); p = PhysF.new(w.io, { maxRange = 30 }); p:attach(w.them)
		T.truthy((p:tick({})), "in range")
		w.them.pos = V.new(100, 0, 0)
		local _, why3 = p:tick({})
		T.eq(why3, "out of range")
		-- attaching to another target detaches the first
		w = world(); p = PhysF.new(w.io); p:attach(w.them)
		local third = { name = "third", pos = V.new(3, 0, 0) }
		w.parts[third] = true
		p:attach(third)
		T.eq(p:getTarget(), third); T.eq(p.detaches, 1)
		-- shutdown
		p:shutdown()
		T.falsy(p:isAttached())
		T.falsy((p:attach(w.them)))
		T.eq(w.props[w.me], nil)
	end)

	T.test("physrep: nothing is left attached after any exit", function()
		local w = world()
		local p = PhysF.new(w.io)
		p:attach(w.them)
		p:setPanic(true)
		T.eq(w.props[w.me], nil)
		T.falsy(p:isAttached())
	end)

	T.test("physrep: priorities are in the order panic > defense > physrep > fakepos > normal", function()
		local P = PhysF.PRIORITY
		T.truthy(P.panic > P.defense and P.defense > P.physrep and P.physrep > P.fakepos and P.fakepos > P.normal)
	end)

	T.test("physrep: geometry", function()
		local targetCF = CF.new(50, 0, 0) * CF.Angles(0, math.rad(90), 0)
		local spot = PhysF.serverBody(targetCF, CF.new(0, 3, 0))
		T.vnear(spot.Position, V.new(50, 3, 0), 1e-6)
		-- handle 2 studs in front of the root: the shot leaves from the glued body's handle
		local rootCF = CF.new(0, 0, 0)
		local handleCF = CF.new(0, 0, -2)
		local origin = PhysF.shotOrigin(targetCF, CF.new(0, 3, 0), rootCF, handleCF)
		T.vnear(origin, (targetCF * CF.new(0, 3, 0) * CF.new(0, 0, -2)).Position, 1e-6)
		T.near((origin - spot.Position).Magnitude, 2, 1e-6, "2 studs from the glued body")
		T.vnear(PhysF.fallbackSpot(V.new(0, 0, 0), V.new(10, 0, 0), 0.2, V.new(0, 3, 0)), V.new(2, 3, 0), 1e-9)
	end)

	-- ---- config store
	local codec = {
		encode = function(t) return serde.encode("json", t) end,
		decode = function(s) return serde.decode("json", s) end,
	}
	local schema = {
		["monster.fakepos.on"] = { kind = "toggle", default = false },
		["monster.fakepos.radius"] = { kind = "slider", default = 10, min = 1, max = 100, step = 1 },
		["monster.fakepos.mode"] = { kind = "dropdown", default = "static", options = { { "static", "Static" }, { "jitter", "Jitter" } } },
		["monster.fakepos.anchorKey"] = { kind = "keybind", default = "None" },
	}

	T.test("config: coercion per kind", function()
		local C = StoreF.coerce
		T.eq((C(schema["monster.fakepos.on"], "true")), true)
		T.eq((C(schema["monster.fakepos.on"], "garbage")), false)
		T.eq((C(schema["monster.fakepos.radius"], 500)), 100)
		T.eq((C(schema["monster.fakepos.radius"], -3)), 1)
		T.eq((C(schema["monster.fakepos.radius"], "7.4")), 7)
		T.eq((C(schema["monster.fakepos.radius"], 0 / 0)), 10)
		T.eq((C(schema["monster.fakepos.radius"], {})), 10)
		T.eq((C(schema["monster.fakepos.mode"], "jitter")), "jitter")
		T.eq((C(schema["monster.fakepos.mode"], "sideways")), "static")
		T.eq((C(schema["monster.fakepos.anchorKey"], 5)), "None")
	end)

	T.test("config: load tolerates garbage, missing and extra keys, bad values", function()
		local s = StoreF.new(table.clone(schema), codec)
		T.falsy((s:load("")))
		T.falsy((s:load("not json at all {{{")))
		T.falsy((s:load("[1,2,3")))
		T.eq(s:get("monster.fakepos.radius"), 10, "defaults survive a bad file")
		T.truthy((s:load('{"version":1,"values":{"monster.fakepos.radius":55,"monster.fakepos.mode":"nonsense","monster.unknown.key":42,"monster.fakepos.on":"yes"}}')))
		T.eq(s:get("monster.fakepos.radius"), 55)
		T.eq(s:get("monster.fakepos.mode"), "static", "unknown option replaced by default")
		T.eq(s:get("monster.fakepos.on"), false, "wrong kind replaced by default")
		T.eq(s.extra["monster.unknown.key"], 42, "unknown keys kept")
		T.truthy(#s.rejected >= 2)
		-- a flat file with no wrapper loads too
		local s2 = StoreF.new(table.clone(schema), codec)
		T.truthy((s2:load('{"monster.fakepos.radius":12}')))
		T.eq(s2:get("monster.fakepos.radius"), 12)
	end)

	T.test("config: dump keeps only changes and unknown keys, and round-trips", function()
		local s = StoreF.new(table.clone(schema), codec)
		T.truthy(s:load('{"values":{"monster.keep.me":"x"}}'))
		s:set("monster.fakepos.radius", 33)
		s:set("monster.fakepos.on", true)
		local text = s:dump()
		local back = codec.decode(text)
		T.eq(back.values["monster.fakepos.radius"], 33)
		T.eq(back.values["monster.fakepos.on"], true)
		T.eq(back.values["monster.keep.me"], "x")
		T.eq(back.values["monster.fakepos.mode"], nil, "defaults are not written")
		local s2 = StoreF.new(table.clone(schema), codec)
		T.truthy(s2:load(text))
		T.eq(s2:get("monster.fakepos.radius"), 33)
	end)

	T.test("config: set coerces, notifies once per change, quiet does not mark dirty", function()
		local s = StoreF.new(table.clone(schema), codec)
		local seen = {}
		s:on("monster.fakepos.radius", function(new, old) seen[#seen + 1] = { new, old } end)
		s:set("monster.fakepos.radius", 500)
		T.eq(s:get("monster.fakepos.radius"), 100)
		s:set("monster.fakepos.radius", 100)
		T.eq(#seen, 1, "no event when nothing changed")
		T.truthy(s.dirty)
		local q = StoreF.new(table.clone(schema), codec)
		q:set("monster.fakepos.on", true, true)
		T.falsy(q.dirty)
		T.truthy(s:isDefault("monster.fakepos.on") and not s:isDefault("monster.fakepos.radius"))
	end)
end
