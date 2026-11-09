return function(T, env)
	T.suite_("orbit+patterns")
	local Orbit = require("../pure/orbit")(env)
	local Patterns = require("../pure/patterns")(env)
	local V, CF = env.Vector3, env.CFrame
	local center = V.new(100, 20, -50)

	T.test("thunder preset at t = 0 matches the algorithm", function()
		local cf, vel, info = Orbit.step(0, center, V.new(100, 20, -50))
		-- angle 0: ring point (0, 0, 135); high; jitter (0, +5, 10)
		T.vnear(cf.Position, center + V.new(0, 200005, 145), 0.05) -- (float32 datatypes: 200005 is only good to ~0.01)
		T.eq(info.height, 200000)
		T.truthy(info.high)
	end)

	T.test("height flips between the two values twenty times a second", function()
		local seen = {}
		for i = 0, 99 do
			local _, _, info = Orbit.step(i / 100 + 0.001, center, center)
			seen[info.height] = (seen[info.height] or 0) + 1
		end
		T.eq(seen[200000], 50); T.eq(seen[199500], 50)
		local _, _, a = Orbit.step(0.01, center, center)
		local _, _, b = Orbit.step(0.06, center, center)
		T.eq(a.height, 200000); T.eq(b.height, 199500)
	end)

	T.test("the ring radius stays within the jitter of 135", function()
		for i = 1, 2000 do
			local t = i * 0.0137
			local cf = Orbit.step(t, center, center)
			local horizontal = V.new(cf.Position.X - center.X, 0, cf.Position.Z - center.Z).Magnitude
			T.truthy(horizontal >= 135 - 10 - 1e-6 and horizontal <= 135 + 10 + 1e-6, "radius " .. horizontal)
			local up = cf.Position.Y - center.Y
			T.truthy(math.abs(up - 200000) <= 5 + 1e-6 or math.abs(up - 199500) <= 5 + 1e-6, "height " .. up)
		end
	end)

	T.test("the jitter is 5 up or down, flipping every 0.025 s", function()
		local _, _, a = Orbit.step(0.001, center, center)
		local _, _, b = Orbit.step(0.026, center, center)
		T.near(a.jitter.Y, 5, 1e-9); T.near(b.jitter.Y, -5, 1e-9)
	end)

	T.test("velocity is 420 and never points at the centre", function()
		local rng = T.rng(5)
		for _ = 1, 500 do
			local me = center + V.new(rng:NextNumber(-300, 300), 0, rng:NextNumber(-300, 300))
			local t = rng:NextNumber(0, 50)
			local _, vel = Orbit.step(t, center, me)
			if vel.Magnitude > 0 then
				T.near(vel.Magnitude, 420, 1e-2, "speed")
				local toCenter = V.new(center.X - me.X, 0, center.Z - me.Z)
				if toCenter.Magnitude > 1e-3 then
					T.truthy(vel:Dot(toCenter.Unit) <= 1e-2, "no inward component")
				end
				T.near(vel.Y, 0, 1e-9, "flat")
			end
		end
	end)

	T.test("no velocity when the body is already where it should go", function()
		local t = 3.3
		local ring = center + V.new(math.sin(t * 28) * 135, 0, math.cos(t * 28) * 135)
		local _, vel = Orbit.step(t, center, ring)
		T.near(vel.Magnitude, 0, 1e-6)
	end)

	T.test("the body looks along the ground", function()
		-- (Lune's CFrame.lookAt mirrors the Z of the direction, so only that the look is level and upright is asserted here;
		-- the heading is CFrame.lookAt's job in the client)
		for _, t in ipairs({ 0.3, 1.7, 5.1, 9.9 }) do
			local cf = Orbit.step(t, center, center)
			T.near(cf.LookVector.Y, 0, 1e-3, "level")
			T.near(V.new(cf.LookVector.X, 0, cf.LookVector.Z).Magnitude, 1, 1e-3, "unit heading")
			T.near(cf.UpVector.Y, 1, 1e-3, "upright")
		end
	end)

	T.test("presets and overrides", function()
		local low = Orbit.resolve("low")
		T.eq(low.radius, 10); T.eq(low.heightHigh, 0)
		local custom = Orbit.resolve({ radius = 50 })
		T.eq(custom.radius, 50); T.eq(custom.speed, 28)
		local cf = Orbit.step(2, center, center, "low")
		T.near((cf.Position - center).Magnitude, 10, 1e-6, "low orbit stays 10 out at the target's height")
		T.near(cf.Position.Y, center.Y, 1e-9)
		local sky = Orbit.step(0.5, center, center, "sky")
		T.truthy(sky.Position.Y - center.Y > 800)
	end)

	T.test("fit keeps a position inside the packet format", function()
		local inside = CF.new(10, 20, 30)
		local same, cut = Orbit.fit(inside)
		T.falsy(cut); T.vnear(same.Position, inside.Position, 1e-9)
		local far, wasCut = Orbit.fit(CF.new(5000, 10, -9000))
		T.truthy(wasCut)
		T.vnear(far.Position, V.new(1000, 10, -1000), 1e-6)
	end)

	-- patterns
	local K = Patterns.DEFAULT_K
	local function horizontal(cf, target) return V.new(cf.Position.X - target.X, 0, cf.Position.Z - target.Z).Magnitude end

	T.test("every pattern is finite, deterministic and inside its reach", function()
		for _, name in ipairs(Patterns.list) do
			local lo, hi = Patterns.reach[name](K)
			for i = 1, 2000 do
				local t = i * 0.0731
				local cf = Patterns.get(name)(center, t, K, { vel = V.new(8, 0, 3), look = V.new(0, 0, -1) })
				local p = cf.Position
				T.truthy(p.X == p.X and p.Y == p.Y and p.Z == p.Z and math.abs(p.X) < 1e7, name .. " finite")
				local h = horizontal(cf, center)
				T.truthy(h >= lo - 1e-2 and h <= hi + 1e-2, string.format("%s radius %.2f outside [%.1f, %.1f]", name, h, lo, hi))
				local again = Patterns.get(name)(center, t, K, { vel = V.new(8, 0, 3), look = V.new(0, 0, -1) })
				T.vnear(again.Position, p, 1e-9, name .. " deterministic")
			end
		end
	end)

	T.test("patterns respect k overrides", function()
		local cf = Patterns.ring(center, 1, { RING_CLEAR = 50 })
		T.near(horizontal(cf, center), 50, 1e-6)
		local cf2 = Patterns.press(center, 0, { PRESS_NEAR = 20, PRESS_OUTSIDE = 0 })
		T.near(horizontal(cf2, center), 20, 1e-6)
	end)

	T.test("pounce drops in for POUNCE_STAY then goes back up", function()
		local down = Patterns.pounce(center, 0.1, K)
		local up = Patterns.pounce(center, 1.0, K)
		T.near(down.Position.Y - center.Y, 0, 1e-9)
		T.near(up.Position.Y - center.Y, K.POUNCE_HIGH, 1e-9)
		T.near(horizontal(down, center), K.POUNCE_LOW, 1e-6)
		T.near(horizontal(up, center), K.POUNCE_OUT, 1e-6)
	end)

	T.test("lure shows then hides", function()
		local shown = Patterns.lure(center, 0.1, K)
		local hidden = Patterns.lure(center, 0.5, K)
		T.near(shown.Position.Y - center.Y, K.LURE_RISE, 1e-9)
		T.near(hidden.Position.Y - center.Y, K.LURE_HIGH, 1e-9)
	end)

	T.test("ring steps the arc between places", function()
		local a = Patterns.ring(center, 0.0, K)
		local b = Patterns.ring(center, K.RING_HOLD + 0.001, K)
		local chord = (a.Position - b.Position).Magnitude
		local expected = 2 * K.RING_CLEAR * math.sin(K.RING_STEP / (2 * K.RING_CLEAR))
		T.near(chord, expected, 1e-2)
	end)

	T.test("haunt stays behind the way the target is heading", function()
		local cf = Patterns.haunt(center, 0, K, { vel = V.new(10, 0, 0) })
		T.vnear(cf.Position, center - V.new(K.HAUNT_APART, 0, 0), 1e-6)
	end)
end
