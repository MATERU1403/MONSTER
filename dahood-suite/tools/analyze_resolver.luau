-- Resolver accuracy from live data: for each run, the watcher's view of a STATIONARY faker (truth: its real body) is fed to the pure
-- estimators exactly as the suite feeds them (a second of history, a guess every 0.1 s). Baseline = the body as the engine shows it.
--   lune run tools/analyze_resolver <label> [<label> ...]
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local V = roblox.Vector3
local Est = require("../pure/estimators")({ Vector3 = V, CFrame = roblox.CFrame })

local function dist(a, b) return (a - b).Magnitude end
local function pct(list, p)
	table.sort(list)
	return list[math.max(1, math.ceil(#list * p))]
end
local function mean(list)
	local s = 0
	for _, v in ipairs(list) do s += v end
	return s / math.max(#list, 1)
end

local rows = {}
local header = "mode          samples  baseline: mean  p95   hit<=22 | resolver: mean   p95   hit<=22  answered  conf   methods"
print(header)
for _, label in ipairs(process.args) do
	local truth = serde.decode("json", fs.readFile("results/truth_" .. label .. ".json"))
	local watch = serde.decode("json", fs.readFile("results/watch_" .. label .. ".json"))
	local onT, offT
	for _, e in ipairs(truth.events) do if e.name == "on" then onT = e.t elseif e.name == "off" then offT = e.t end end
	local startT
	for _, e in ipairs(truth.events) do if e.name == "start" then startT = e.t end end
	if truth.mode == "none" then onT, offT = startT + 1.0, startT + 1.0 + 4 end
	local xs, ys, zs = {}, {}, {}
	for _, r in ipairs(truth.rows) do table.insert(xs, r.x); table.insert(ys, r.y); table.insert(zs, r.z) end
	table.sort(xs); table.sort(ys); table.sort(zs)
	local real = V.new(xs[#xs // 2 + 1], ys[#ys // 2 + 1], zs[#zs // 2 + 1])

	local samples = {}
	for _, r in ipairs(watch.rows) do
		local parts = {}
		for name, p in pairs(r.parts or {}) do parts[name] = V.new(p[1], p[2], p[3]) end
		table.insert(samples, { t = r.t, pos = V.new(r.x, r.y, r.z), vel = V.new(r.vx, r.vy, r.vz), parts = parts })
	end

	local base, res, confs, methods, asked, answered = {}, {}, {}, {}, 0, 0
	local memory = {}
	local history = Est.history(1.0)
	local nextAt = onT + 1.0
	for i, s in ipairs(samples) do
		history:push(s)
		if Est.gate(s, samples[i - 1]) then memory.sample = s end
		if s.t >= nextAt and s.t <= offT - 0.1 and history:count() >= 6 then
			nextAt = s.t + 0.1
			asked += 1
			table.insert(base, dist(s.pos, real))
			local r = Est.estimate(history:list(), s.t, nil, nil, memory)
			if r.pos then
				answered += 1
				table.insert(res, dist(r.pos, real))
				table.insert(confs, r.confidence)
				methods[r.method] = (methods[r.method] or 0) + 1
			else
				table.insert(res, dist(s.pos, real)) -- no guess: the body as shown is what the ragebot would use
			end
		end
	end
	if asked > 0 then
		local function hit(list) local n = 0; for _, v in ipairs(list) do if v <= 22 then n += 1 end end; return n / #list end
		local top = {}
		for m, n in pairs(methods) do table.insert(top, string.format("%s %d%%", m, math.floor(n / math.max(answered, 1) * 100 + 0.5))) end
		table.sort(top)
		print(string.format("%-12s %7d  %14.1f %5.1f %8.0f%% | %13.1f %5.1f %8.0f%% %8.0f%% %5.2f  %s", label, asked, mean(base), pct(base, 0.95), hit(base) * 100,
			mean(res), pct(res, 0.95), hit(res) * 100, answered / asked * 100, mean(confs), table.concat(top, ", ")))
	else
		print(string.format("%-12s no samples (watch rows %d, on %s off %s)", label, #samples, tostring(onT), tostring(offT)))
	end
end
