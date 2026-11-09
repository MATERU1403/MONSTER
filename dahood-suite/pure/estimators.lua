-- Resolver estimators. Pure: each one reads a short history of samples of one player and returns a guess of where the
-- body really is, with a confidence in 0..1; `combine` votes them. Nothing here touches Roblox, so each runs under Lune.
--
-- A sample is { t = clock seconds, pos = Vector3 (HumanoidRootPart), vel = Vector3?, look = Vector3?,
--               parts = { Name = Vector3 }?, moveDir = Vector3?, walk = number?, moving = boolean? }.
-- `list` is an array of samples, oldest first.
return function(env)
	local Vector3 = env.Vector3
	local Est = {}
	local sqrt, abs, max, min, floor, exp, huge = math.sqrt, math.abs, math.max, math.min, math.floor, math.exp, math.huge
	local ZERO = Vector3.new(0, 0, 0)

	Est.DEFAULT = {
		windowSeconds = 1.0,
		minSamples = 6,
		-- sanity gate
		maxJump = 30,      -- studs between two samples
		maxSpeed = 140,    -- studs/s a body can really reach (walk 16, sprint ~22, speed lock 40, a car ~100, a fall)
		mapHalf = 4000, mapTop = 1500, mapBottom = -60,
		-- dead reckoning
		extrapMax = 1.0, accelMax = 80,
		-- body parts
		partsDisagree = 6, partsStable = 3,
		-- animation / state cues
		stillDisp = 1.0, stillVel = 0.5, cueMin = 0.4, maxWalk = 40,
		-- pattern recognition
		hopMin = 6, hopRate = 0.35, clusterMinSep = 8, ringRadiusMin = 3, ringResidual = 0.35,
		-- combiner
		agreeSigma = 6, minConfidence = 0.35,
	}

	local function finite(v)
		return v ~= nil and v.X == v.X and v.Y == v.Y and v.Z == v.Z and abs(v.X) < huge and abs(v.Y) < huge and abs(v.Z) < huge
	end
	local function flat(v) return Vector3.new(v.X, 0, v.Z) end
	local META = { __index = Est.DEFAULT }
	local function cfgOf(cfg)
		if not cfg or cfg == Est.DEFAULT then return Est.DEFAULT end
		if getmetatable(cfg) ~= META then setmetatable(cfg, META) end
		return cfg
	end

	-- ---- history: a ring of samples, the last `seconds` of them
	function Est.history(seconds)
		local h = { items = {}, seconds = seconds or Est.DEFAULT.windowSeconds }
		function h:push(sample)
			local items = self.items
			items[#items + 1] = sample
			local cut = sample.t - self.seconds
			local drop = 0
			while drop < #items - 1 and items[drop + 1].t < cut do drop += 1 end
			if drop > 0 then
				local n = #items
				table.move(items, drop + 1, n, 1)
				for i = n - drop + 1, n do items[i] = nil end
			end
		end
		function h:list() return self.items end
		function h:last() return self.items[#self.items] end
		function h:count() return #self.items end
		function h:clear() self.items = {} end
		return h
	end

	-- ---- 1. sanity gate: is this sample a place a body can be?
	---@param sample table
	---@param prev table? the sample before it
	---@return boolean, string?
	function Est.gate(sample, prev, cfg)
		cfg = cfgOf(cfg)
		local p = sample.pos
		if not finite(p) then return false, "nan" end
		if abs(p.X) > cfg.mapHalf or abs(p.Z) > cfg.mapHalf or p.Y > cfg.mapTop or p.Y < cfg.mapBottom then return false, "bounds" end
		if prev and finite(prev.pos) then
			local d = (p - prev.pos).Magnitude
			local dt = max(sample.t - prev.t, 1 / 240)
			if d > cfg.maxJump and dt < 0.5 then return false, "jump" end
			if d > 2 and d / dt > cfg.maxSpeed then return false, "speed" end
		end
		return true
	end

	---Run the gate down a list: flags[i] = true when sample i passes.
	function Est.gated(list, cfg)
		local flags, reasons = {}, {}
		for i, sample in ipairs(list) do
			local ok, why = Est.gate(sample, list[i - 1], cfg)
			flags[i], reasons[i] = ok, why
		end
		return flags, reasons
	end

	---Index of the newest sample that passed the gate.
	function Est.lastGoodIndex(list, cfg)
		local flags = Est.gated(list, cfg)
		for i = #list, 1, -1 do if flags[i] then return i, flags end end
		return nil, flags
	end

	-- ---- 2. last known good, advanced by its velocity and the recent acceleration
	---@param memory table? { sample = the newest good sample ever seen }: used when the window holds none (a body that has been voided for a while)
	function Est.deadReckon(list, now, cfg, memory)
		cfg = cfgOf(cfg)
		local index, flags = Est.lastGoodIndex(list, cfg)
		if not index then
			local kept = memory and memory.sample
			if not (kept and finite(kept.pos)) then return nil end
			local age = max(now - kept.t, 0)
			local vel = finite(kept.vel) and kept.vel or ZERO
			if vel.Magnitude > cfg.maxSpeed then vel = vel.Unit * cfg.maxSpeed end
			local dt = min(age, cfg.extrapMax)
			return { pos = kept.pos + vel * dt, confidence = 0.5 * exp(-age / 0.8), method = "deadreckon", age = age, remembered = true }
		end
		local good = list[index]
		local dt = min(max(now - good.t, 0), cfg.extrapMax)
		local vel = good.vel
		if not finite(vel) then
			local before = list[index - 1]
			vel = before and (good.pos - before.pos) / max(good.t - before.t, 1 / 240) or ZERO
		end
		if vel.Magnitude > cfg.maxSpeed then vel = vel.Unit * cfg.maxSpeed end
		local accel = ZERO
		local a, b = list[index - 2], list[index - 1]
		if a and b and flags[index - 2] and flags[index - 1] and finite(a.vel) and finite(b.vel) then
			local span = max(good.t - a.t, 1 / 120)
			accel = (vel - a.vel) / span
			if accel.Magnitude > cfg.accelMax then accel = accel.Unit * cfg.accelMax end
			if dt > 0.5 then accel = accel * 0.5 end
		end
		local pos = good.pos + vel * dt + accel * (0.5 * dt * dt)
		local goodCount = 0
		for i = 1, #list do if flags[i] then goodCount += 1 end end
		local conf = exp(-dt / 0.8) * sqrt(goodCount / max(#list, 1))
		return { pos = pos, confidence = conf, method = "deadreckon", age = dt }
	end

	-- ---- the sample as the engine shows it: used when nothing says it is fake
	function Est.raw(list, cfg)
		cfg = cfgOf(cfg)
		local last = list[#list]
		if not last then return nil end
		local ok = Est.gate(last, list[#list - 1], cfg)
		return { pos = last.pos, confidence = ok and 0.6 or 0, method = "raw", gated = not ok }
	end

	-- ---- 3. body parts: the centroid of the parts that did not come from the root
	---Where the parts are now (mean over the newest few samples), whether or not the root agrees: what a hopping root is judged by.
	function Est.partsHint(list)
		local sum, count = ZERO, 0
		for i = #list, max(1, #list - 4), -1 do
			local sample = list[i]
			if sample.parts then
				for _, position in pairs(sample.parts) do
					if finite(position) then sum += position; count += 1 end
				end
			end
		end
		if count == 0 then return nil end
		return { pos = sum / count, confidence = 0.5, method = "parts" }
	end

	function Est.partsCentroid(list, cfg)
		cfg = cfgOf(cfg)
		local ds, newest, n = {}, nil, 0
		for _, sample in ipairs(list) do
			if sample.parts and finite(sample.pos) then
				local sum, count = ZERO, 0
				for _, position in pairs(sample.parts) do
					if finite(position) then sum += position; count += 1 end
				end
				if count > 0 then
					local centroid = sum / count
					ds[#ds + 1] = sample.pos - centroid
					newest, n = centroid, n + 1
				end
			end
		end
		if n < 3 then return nil end
		local mean = ZERO
		for _, d in ipairs(ds) do mean += d end
		mean = mean / n
		local spread = 0
		for _, d in ipairs(ds) do spread += (d - mean).Magnitude ^ 2 end
		spread = sqrt(spread / n)
		if mean.Magnitude > cfg.partsDisagree and spread < cfg.partsStable then
			local conf = min(0.95, mean.Magnitude / (cfg.partsDisagree * 3) + 0.3) * (1 - 0.5 * spread / cfg.partsStable)
			return { pos = newest, confidence = conf, method = "parts", disagree = mean.Magnitude }
		end
		return nil
	end

	-- ---- 4. animation / state cues: the body is told to move but the position stands still
	function Est.cues(list, now, cfg)
		cfg = cfgOf(cfg)
		local first, last = list[1], list[#list]
		if not (first and last) or #list < cfg.minSamples then return nil end
		local disp = (flat(last.pos) - flat(first.pos)).Magnitude
		local vel = last.vel and flat(last.vel).Magnitude or 0
		local moving = 0
		for _, sample in ipairs(list) do if sample.moving or (sample.moveDir and sample.moveDir.Magnitude > 0.1) then moving += 1 end end
		local frac = moving / #list
		if disp < cfg.stillDisp and vel < cfg.stillVel and frac > 0.7 and last.t - first.t >= cfg.cueMin then
			local dir = last.moveDir
			if not dir or dir.Magnitude < 0.1 then dir = last.look or ZERO end
			dir = flat(dir)
			local speed = min(last.walk or 16, cfg.maxWalk)
			local elapsed = min(last.t - first.t, 2)
			local pos = last.pos
			if dir.Magnitude > 0.01 then pos = pos + dir.Unit * speed * elapsed end
			return { pos = pos, confidence = 0.4 * exp(-elapsed / 3), method = "cues", frozen = true }
		end
		return nil
	end

	-- ---- 5. patterns: samples that hop about instead of travelling
	-- circle through the points in the ground plane (least squares): centre and radius, and how far the points stray from it
	local function fitCircle(points)
		local n = #points
		if n < 4 then return nil end
		-- (centred first: the sums of cubes of map coordinates are too big to keep the system well conditioned)
		local mx, mz = 0, 0
		for _, p in ipairs(points) do mx += p.X; mz += p.Z end
		mx, mz = mx / n, mz / n
		local sx, sz, sxx, szz, sxz, sxxx, szzz, sxzz, sxxz = 0, 0, 0, 0, 0, 0, 0, 0, 0
		for _, p in ipairs(points) do
			local x, z = p.X - mx, p.Z - mz
			sx += x; sz += z; sxx += x * x; szz += z * z; sxz += x * z
			sxxx += x * x * x; szzz += z * z * z; sxzz += x * z * z; sxxz += x * x * z
		end
		-- normal equations of  x^2 + z^2 + D x + E z + F = 0
		local a11, a12, a13 = sxx, sxz, sx
		local a22, a23 = szz, sz
		local b1, b2, b3 = -(sxxx + sxzz), -(sxxz + szzz), -(sxx + szz)
		-- solve the 3x3 system by Cramer's rule
		local function det(m11, m12, m13, m21, m22, m23, m31, m32, m33)
			return m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)
		end
		local d = det(a11, a12, a13, a12, a22, a23, a13, a23, n)
		if abs(d) < 1e-9 then return nil end
		local D = det(b1, a12, a13, b2, a22, a23, b3, a23, n) / d
		local E = det(a11, b1, a13, a12, b2, a23, a13, b3, n) / d
		local F = det(a11, a12, b1, a12, a22, b2, a13, a23, b3) / d
		local cx, cz = -D / 2, -E / 2
		local r2 = cx * cx + cz * cz - F
		if r2 <= 0 then return nil end
		local r = sqrt(r2)
		local resid = 0
		for _, p in ipairs(points) do resid += (sqrt((p.X - mx - cx) ^ 2 + (p.Z - mz - cz) ^ 2) - r) ^ 2 end
		return cx + mx, cz + mz, r, sqrt(resid / n)
	end

	local function median(values)
		table.sort(values)
		local n = #values
		if n == 0 then return 0 end
		if n % 2 == 1 then return values[(n + 1) / 2] end
		return (values[n / 2] + values[n / 2 + 1]) / 2
	end

	-- two clusters (k-means, k = 2, started at the two farthest points)
	local function twoClusters(points)
		local a, b, far = points[1], points[1], -1
		for i = 1, #points do
			for j = i + 1, #points do
				local d = (points[i] - points[j]).Magnitude
				if d > far then a, b, far = points[i], points[j], d end
			end
		end
		local ca, cb = a, b
		local sa, sb, na, nb, assign = ZERO, ZERO, 0, 0, {}
		for _ = 1, 5 do
			sa, sb, na, nb = ZERO, ZERO, 0, 0
			for i, p in ipairs(points) do
				if (p - ca).Magnitude <= (p - cb).Magnitude then assign[i] = 1; sa += p; na += 1 else assign[i] = 2; sb += p; nb += 1 end
			end
			if na > 0 then ca = sa / na end
			if nb > 0 then cb = sb / nb end
		end
		local va, vb = 0, 0
		for i, p in ipairs(points) do
			if assign[i] == 1 then va += (p - ca).Magnitude ^ 2 else vb += (p - cb).Magnitude ^ 2 end
		end
		local switches = 0
		for i = 2, #points do if assign[i] ~= assign[i - 1] then switches += 1 end end
		return { a = ca, b = cb, na = na, nb = nb, sa = na > 0 and sqrt(va / na) or 0, sb = nb > 0 and sqrt(vb / nb) or 0,
			sep = (ca - cb).Magnitude, switches = switches }
	end

	---A body that hops about (jitter, orbit, blink): where the hops are centred, or which of two clusters is the body.
	---`hint` is another estimate (the parts centroid) used to choose between two clusters.
	function Est.pattern(list, cfg, hint)
		cfg = cfgOf(cfg)
		local n = #list
		if n < cfg.minSamples then return nil end
		local points, hops = {}, 0
		for i, sample in ipairs(list) do
			if finite(sample.pos) then points[#points + 1] = sample.pos end
			if i > 1 and finite(sample.pos) and finite(list[i - 1].pos) and (sample.pos - list[i - 1].pos).Magnitude > cfg.hopMin then hops += 1 end
		end
		if #points < cfg.minSamples then return nil end
		local rate = hops / max(#points - 1, 1)
		if rate < cfg.hopRate then return nil end
		if #points > 40 then
			-- (the newest 40 are enough to see a pattern, and the clustering is quadratic)
			local keep = {}
			for i = #points - 39, #points do keep[#keep + 1] = points[i] end
			points = keep
		end

		local ys = {}
		for _, p in ipairs(points) do ys[#ys + 1] = p.Y end
		local sum = ZERO
		for _, p in ipairs(points) do sum += p end
		local centroid = sum / #points

		-- two clusters that take turns
		local c = twoClusters(points)
		if c.sep > cfg.clusterMinSep and (c.sa + c.sb) / 2 < c.sep * 0.25 and c.switches >= #points * 0.5 then
			local pick, share = c.a, c.na / #points
			if hint and finite(hint.pos) and (c.b - hint.pos).Magnitude < (c.a - hint.pos).Magnitude then pick, share = c.b, c.nb / #points end
			if not (hint and finite(hint.pos)) and c.nb > c.na then pick, share = c.b, c.nb / #points end
			return { pos = pick, confidence = min(0.8, 0.35 + rate * 0.4) * (hint and 1 or 0.7), method = "pattern", kind = "blink", rate = rate, share = share }
		end

		-- a ring or a disk about the body: its middle is the body
		local cx, cz, r, resid = fitCircle(points)
		if cx and r > cfg.ringRadiusMin and resid / r < cfg.ringResidual then
			return { pos = Vector3.new(cx, median(ys), cz), confidence = min(0.85, 0.4 + rate * 0.4) * (1 - 0.5 * resid / r), method = "pattern", kind = "ring", rate = rate, radius = r }
		end
		return { pos = Vector3.new(centroid.X, median(ys), centroid.Z), confidence = min(0.7, 0.3 + rate * 0.35), method = "pattern", kind = "scatter", rate = rate }
	end

	-- ---- learning: per target, per method weights nudged by whether shots at the guess did damage
	function Est.learner()
		local L = { weights = {}, shots = {} }
		function L:weight(method) return self.weights[method] or 1 end
		function L:reward(method, hit)
			local w = self.weights[method] or 1
			w = w * (hit and 1.15 or 0.93)
			self.weights[method] = min(max(w, 0.2), 4)
			local s = self.shots[method] or { hit = 0, miss = 0 }
			if hit then s.hit += 1 else s.miss += 1 end
			self.shots[method] = s
		end
		function L:decay(dt)
			for method, w in pairs(self.weights) do self.weights[method] = w + (1 - w) * min(dt * 0.02, 1) end
		end
		return L
	end

	-- ---- combiner: a weighted vote of the guesses that agree
	---@param estimates table[] each { pos, confidence, method }
	---@param weights table? method -> weight
	---@return table
	function Est.combine(estimates, weights, cfg)
		cfg = cfgOf(cfg)
		local usable = {}
		for _, e in ipairs(estimates) do
			if e and finite(e.pos) and e.confidence and e.confidence > 0 then
				usable[#usable + 1] = { e = e, s = e.confidence * ((weights and weights[e.method]) or 1) }
			end
		end
		if #usable == 0 then return { pos = nil, confidence = 0, method = "none", all = estimates } end
		local best, bestSupport, total = nil, -1, 0
		for _, u in ipairs(usable) do total += u.s end
		for _, u in ipairs(usable) do
			local support = 0
			for _, v in ipairs(usable) do
				local d = (u.e.pos - v.e.pos).Magnitude / cfg.agreeSigma
				support += v.s * exp(-d * d)
			end
			if support > bestSupport then best, bestSupport = u, support end
		end
		local sum, weight, topConf = ZERO, 0, 0
		for _, v in ipairs(usable) do
			if (v.e.pos - best.e.pos).Magnitude <= 2 * cfg.agreeSigma then
				sum += v.e.pos * v.s
				weight += v.s
				if v.e.confidence > topConf then topConf = v.e.confidence end
			end
		end
		local agreeShare = total > 0 and weight / total or 0
		return {
			pos = sum / weight,
			confidence = min(1, agreeShare * topConf * (1 + 0.15 * (#usable - 1))),
			method = best.e.method,
			all = estimates,
		}
	end

	---Every estimator on one history, then the vote.
	---@param list table[] samples, oldest first
	---@param now number
	---@param cfg table?
	---@param weights table? per-method weights from the learner
	function Est.estimate(list, now, cfg, weights, memory)
		cfg = cfgOf(cfg)
		local raw = Est.raw(list, cfg)
		local parts = Est.partsCentroid(list, cfg)
		local pattern = Est.pattern(list, cfg, parts or Est.partsHint(list))
		local cues = Est.cues(list, now, cfg)
		local reckon = Est.deadReckon(list, now, cfg, memory)
		-- a root that hops, or that the parts disagree with, or that stands still while told to walk, is not the place
		-- it shows: what is made from the root alone stops counting
		if pattern or parts then
			if raw then raw.confidence = raw.confidence * 0.2 end
			if reckon then reckon.confidence = reckon.confidence * 0.2 end
		elseif cues then
			if raw then raw.confidence = raw.confidence * 0.4 end
			if reckon then reckon.confidence = reckon.confidence * 0.4 end
		end
		-- (appended one by one: a nil in the middle of a table literal would end the list for ipairs)
		local estimates = {}
		for _, e in ipairs({ raw or false, parts or false, pattern or false, cues or false, reckon or false }) do
			if e then estimates[#estimates + 1] = e end
		end
		local result = Est.combine(estimates, weights, cfg)
		if raw and raw.gated and result.method == "raw" then result.method = reckon and "deadreckon" or "raw" end
		return result
	end

	return Est
end
