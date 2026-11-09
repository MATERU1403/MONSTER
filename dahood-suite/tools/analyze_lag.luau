-- How late does another client see a walking body? Finds the time shift L that best lines the watcher's view up with the walker's own
-- positions, per run. L is ping (one way each) plus Roblox's interpolation buffer; the buffer is what is left once the pings are taken off.
--   lune run tools/analyze_lag <label> [pingA_ms] [pingB_ms]
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local label = process.args[1] or "lag1"
local truth = serde.decode("json", fs.readFile("results/truth_" .. label .. ".json"))
local watch = serde.decode("json", fs.readFile("results/watch_" .. label .. ".json"))
local pingA, pingB = tonumber(process.args[2]) or 0, tonumber(process.args[3]) or watch.ping or 0

local A = truth.rows
-- the walking stretch: where the walker's speed is over 5 studs/s
local moving = {}
for i = 2, #A do
	local dt = A[i].t - A[i - 1].t
	if dt > 0 then
		local speed = math.sqrt((A[i].x - A[i - 1].x) ^ 2 + (A[i].z - A[i - 1].z) ^ 2) / dt
		if speed > 5 then table.insert(moving, A[i].t) end
	end
end
if #moving < 10 then print("the walker did not move enough"); process.exit(1) end
local t0, t1 = moving[1] + 0.3, moving[#moving] - 0.3

local function atTime(t)
	-- the walker's position at server time t (linear between rows)
	local lo, hi = 1, #A
	if t <= A[1].t then return A[1].x, A[1].z end
	if t >= A[#A].t then return A[#A].x, A[#A].z end
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if A[mid].t <= t then lo = mid else hi = mid end
	end
	local f = (t - A[lo].t) / math.max(A[hi].t - A[lo].t, 1e-9)
	return A[lo].x + (A[hi].x - A[lo].x) * f, A[lo].z + (A[hi].z - A[lo].z) * f
end

local best, bestErr = 0, math.huge
local curve = {}
for step = 0, 120 do
	local L = step * 0.005
	local sum, n = 0, 0
	for _, r in ipairs(watch.rows) do
		if r.t - L >= t0 and r.t - L <= t1 then
			local x, z = atTime(r.t - L)
			sum += math.sqrt((r.x - x) ^ 2 + (r.z - z) ^ 2)
			n += 1
		end
	end
	if n > 5 then
		local err = sum / n
		curve[#curve + 1] = { L, err }
		if err < bestErr then best, bestErr = L, err end
	end
end
local speed = (A[#A].x - A[1].x)
local sorted = {}
for _, c in ipairs(curve) do table.insert(sorted, c) end
table.sort(sorted, function(a, b) return a[2] < b[2] end)
print(string.format("== %s: walker moved %d studs; best shift L = %.3f s (mean position error %.3f studs there)", label, math.floor(math.sqrt((A[#A].x - A[1].x) ^ 2 + (A[#A].z - A[1].z) ^ 2)), best, bestErr))
print(string.format("   2nd and 3rd best: %.3f s (%.3f), %.3f s (%.3f)", sorted[2][1], sorted[2][2], sorted[3][1], sorted[3][2]))
local oneWay = (pingA + pingB) / 2 / 1000
print(string.format("   pings (round trip): walker %.0f ms, watcher %.0f ms: both one-way trips = %.3f s; interpolation buffer = L - that = %.3f s", pingA, pingB, oneWay, best - oneWay))
print("   (both clients' GetServerTimeNow() are used as the common clock: an offset between them moves L by the same amount)")
