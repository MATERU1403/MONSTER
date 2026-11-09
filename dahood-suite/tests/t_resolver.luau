return function(T, env)
	T.suite_("resolver")
	local Est = require("../pure/estimators")(env)
	local V = env.Vector3
	local DT = 1 / 60

	local function sample(t, pos, extra)
		local s = { t = t, pos = pos }
		for k, v in pairs(extra or {}) do s[k] = v end
		return s
	end

	local function run(fn, seconds)
		local list = {}
		local n = math.floor((seconds or 1) / DT)
		for i = 0, n do list[#list + 1] = fn(i * DT, i) end
		return list, (n * DT)
	end

	T.test("gate rejects NaN, bounds, jumps and speed", function()
		local base = sample(0, V.new(0, 10, 0))
		T.falsy((Est.gate(sample(DT, V.new(0 / 0, 0, 0)), base)))
		T.falsy((Est.gate(sample(DT, V.new(1e9, 5e8, 1e9)), nil)))
		T.falsy((Est.gate(sample(DT, V.new(0, 5000, 0)), nil)))
		T.falsy((Est.gate(sample(DT, V.new(0, -500, 0)), nil)))
		local ok, why = Est.gate(sample(DT, V.new(50, 10, 0)), base)
		T.falsy(ok); T.eq(why, "jump")
		T.truthy((Est.gate(sample(DT, V.new(0.4, 10, 0)), base)), "16 studs/s is fine")
		local ok2, why2 = Est.gate(sample(0.2, V.new(29, 10, 0)), base)
		T.falsy(ok2); T.eq(why2, "speed")
		T.truthy((Est.gate(sample(2, V.new(60, 10, 0)), base)), "a long gap is not a jump")
	end)

	T.test("a still honest body resolves to itself", function()
		local truth = V.new(10, 5, 20)
		local list, now = run(function(t) return sample(t, truth, { vel = V.new(0, 0, 0) }) end, 1)
		local r = Est.estimate(list, now)
		T.vnear(r.pos, truth, 0.01)
		T.truthy(r.confidence >= 0.35, "confident")
		T.eq(r.method, "raw")
	end)

	T.test("a walking body is followed", function()
		local list, now = run(function(t) return sample(t, V.new(16 * t, 5, 0), { vel = V.new(16, 0, 0) }) end, 1)
		local r = Est.estimate(list, now)
		T.vnear(r.pos, V.new(16 * now, 5, 0), 0.5)
	end)

	T.test("dead reckoning carries a body that goes into the void", function()
		local list, now = {}, 0
		for i = 0, 29 do
			local t = i * DT
			list[#list + 1] = sample(t, V.new(10 * t, 5, 0), { vel = V.new(10, 0, 0) })
		end
		local lastGood = list[#list]
		for i = 30, 50 do
			local t = i * DT
			list[#list + 1] = sample(t, V.new(1e9, 1e9, 1e9), { vel = V.new(0, 0, 0) })
			now = t
		end
		local r = Est.estimate(list, now)
		T.eq(r.method, "deadreckon")
		local expected = lastGood.pos + V.new(10, 0, 0) * (now - lastGood.t)
		T.vnear(r.pos, expected, 1.0)
	end)

	T.test("ring jitter resolves to the middle", function()
		local rng = T.rng(21)
		local truth = V.new(-30, 8, 60)
		local list, now = run(function(t)
			local a = rng:NextNumber() * 2 * math.pi
			return sample(t, truth + V.new(math.cos(a) * 40, 0, math.sin(a) * 40), { vel = V.new(0, 0, 0) })
		end, 1)
		local r = Est.estimate(list, now)
		T.eq(r.method, "pattern")
		T.lt((r.pos - truth).Magnitude, 3, "ring middle")
		T.truthy((list[#list].pos - truth).Magnitude > 30, "the raw sample is far off")
	end)

	T.test("disk jitter resolves close to the middle", function()
		local rng = T.rng(33)
		local truth = V.new(5, 8, 5)
		local errors = 0
		local trials = 20
		for _ = 1, trials do
			local list, now = run(function(t)
				local a, r = rng:NextNumber() * 2 * math.pi, math.sqrt(rng:NextNumber()) * 40
				return sample(t, truth + V.new(math.cos(a) * r, 0, math.sin(a) * r))
			end, 1)
			errors += (Est.estimate(list, now).pos - truth).Magnitude
		end
		T.lt(errors / trials, 9, "mean error of a disk of radius 40")
	end)

	T.test("two clusters taking turns: the parts say which is the body", function()
		local truth, fake = V.new(0, 5, 0), V.new(60, 5, 0)
		local list, now = run(function(t, i)
			local pos = (i % 2 == 0) and truth or fake
			return sample(t, pos, { parts = { Head = truth + V.new(0, 2, 0), Torso = truth } })
		end, 1)
		local r = Est.estimate(list, now)
		T.lt((r.pos - truth).Magnitude, 4, "picked the body")
	end)

	T.test("parts disagreeing with the root give the parts' place", function()
		local truth, shown = V.new(0, 5, 0), V.new(50, 5, 0)
		local list, now = run(function(t)
			return sample(t, shown, { vel = V.new(0, 0, 0), parts = { Head = truth + V.new(0, 2, 0), Torso = truth, Foot = truth - V.new(0, 3, 0) } })
		end, 1)
		local r = Est.estimate(list, now)
		T.lt((r.pos - truth).Magnitude, 4, "went to the parts")
	end)

	T.test("a frozen body that is told to walk is carried along by the cues", function()
		local frozen = V.new(0, 5, 0)
		local list, now = run(function(t)
			return sample(t, frozen, { vel = V.new(0, 0, 0), moveDir = V.new(0, 0, -1), walk = 16, moving = true })
		end, 1.2)
		local cue = Est.cues(list, now)
		T.truthy(cue, "cue fired")
		T.truthy((cue.pos - frozen).Magnitude > 10, "moved along the heading")
		T.lt(cue.confidence, 0.5, "and is not trusted much")
		T.near(cue.pos.Z, frozen.Z - 16 * 1.2, 1.5)
	end)

	T.test("a standing body with no walk cues is not called frozen", function()
		local list, now = run(function(t) return sample(t, V.new(0, 5, 0), { vel = V.new(0, 0, 0), moveDir = V.new(0, 0, 0), moving = false }) end, 1.2)
		T.eq(Est.cues(list, now), nil)
	end)

	T.test("combiner: agreeing guesses beat a loud outlier", function()
		local est = {
			{ pos = V.new(0, 0, 0), confidence = 0.6, method = "raw" },
			{ pos = V.new(1, 0, 0), confidence = 0.5, method = "parts" },
			{ pos = V.new(80, 0, 0), confidence = 0.9, method = "cues" },
		}
		local r = Est.combine(est)
		T.lt(r.pos.X, 2, "the agreeing pair")
		local alone = Est.combine({ est[3] })
		T.lt(alone.confidence, r.confidence + 1)
		local none = Est.combine({})
		T.eq(none.method, "none")
	end)

	T.test("learner keeps weights in bounds and decays back", function()
		local L = Est.learner()
		for _ = 1, 60 do L:reward("pattern", true) end
		T.near(L:weight("pattern"), 4, 1e-9)
		for _ = 1, 200 do L:reward("pattern", false) end
		T.near(L:weight("pattern"), 0.2, 1e-9)
		L:decay(10)
		T.truthy(L:weight("pattern") > 0.2)
		T.eq(L:weight("unknown"), 1)
		local r = Est.combine({ { pos = V.new(0, 0, 0), confidence = 0.5, method = "a" }, { pos = V.new(60, 0, 0), confidence = 0.5, method = "b" } }, { a = 0.2, b = 4 })
		T.truthy(r.pos.X > 50, "the weighted method wins")
	end)

	T.test("history keeps only the window", function()
		local h = Est.history(1.0)
		for i = 0, 299 do h:push(sample(i * DT, V.new(0, 0, 0))) end
		T.truthy(h:count() <= 62, "kept " .. h:count())
		T.truthy(h:count() >= 59)
		T.near(h:last().t, 299 * DT, 1e-9)
		h:clear()
		T.eq(h:count(), 0)
	end)

	-- a synthetic table, clearly not a live measurement: mean error with and without the resolver per desync mode
	T.test("synthetic error table (no resolver vs resolver)", function()
		local rng = T.rng(77)
		local truth = V.new(0, 8, 0)
		local modes = {
			static = function() return truth + V.new(30, 0, 0) end,
			follow = function() return truth + V.new(0, 0, 25) end,
			ring = function() local a = rng:NextNumber() * 2 * math.pi; return truth + V.new(math.cos(a) * 40, 0, math.sin(a) * 40) end,
			disk = function() local a, r = rng:NextNumber() * 2 * math.pi, math.sqrt(rng:NextNumber()) * 40; return truth + V.new(math.cos(a) * r, 0, math.sin(a) * r) end,
			blink = function() return (rng:NextNumber() < 0.5) and truth or (truth + V.new(60, 0, 0)) end,
			void = function() return V.new(1e9, 1e9, 1e9) end,
		}
		local rows = { "SYNTHETIC mode    baseline mean   resolver mean" }
		for _, name in ipairs({ "static", "follow", "ring", "disk", "blink", "void" }) do
			local base, res, trials = 0, 0, 12
			for _ = 1, trials do
				local list, now = run(function(t) return sample(t, modes[name](), { vel = V.new(0, 0, 0) }) end, 1)
				local last = list[#list].pos
				base += math.min((last - truth).Magnitude, 1e6)
				local r = Est.estimate(list, now)
				res += r.pos and (r.pos - truth).Magnitude or 1e6
			end
			table.insert(rows, string.format("SYNTHETIC %-8s %10.1f %14.1f", name, base / trials, res / trials))
		end
		T.note(table.concat(rows, "\n"))
	end)
end
