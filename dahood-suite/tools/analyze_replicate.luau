-- Did the other client see the fake? Compares truth_<label>.json (the faking client) with watch_<label>.json (the watching one).
--   lune run tools/analyze_replicate <label>
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local label = process.args[1] or "rep1"
local truth = serde.decode("json", fs.readFile("results/truth_" .. label .. ".json"))
local watch = serde.decode("json", fs.readFile("results/watch_" .. label .. ".json"))

local ev = {}
for _, e in ipairs(truth.events) do ev[e.name] = e.t end
local onT, offT = ev.on, ev.off
if not (onT and offT) then print("no on/off events in truth"); process.exit(1) end

local function dist(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2) end
local function median(list)
	table.sort(list)
	return list[math.max(1, math.ceil(#list / 2))]
end
local function stats(list)
	if #list == 0 then return "n/a" end
	table.sort(list)
	local sum = 0
	for _, v in ipairs(list) do sum += v end
	return string.format("mean %.2f, median %.2f, 95th %.2f, max %.2f (n=%d)", sum / #list, list[math.max(1, math.ceil(#list * 0.5))], list[math.max(1, math.ceil(#list * 0.95))], list[#list], #list)
end

-- the faker's own screen: how far did its real body move over the whole run?
local first = truth.rows[1]
local p0 = { first.x, first.y, first.z }
local drift, rx, ry, rz = 0, {}, {}, {}
for _, r in ipairs(truth.rows) do
	drift = math.max(drift, dist({ r.x, r.y, r.z }, p0))
	table.insert(rx, r.x); table.insert(ry, r.y); table.insert(rz, r.z)
end
local real = { median(rx), median(ry), median(rz) }

-- what the suite handed the server while it was on
local sx, sy, sz = {}, {}, {}
for _, r in ipairs(truth.rows) do
	if r.sx and r.t >= onT + 0.3 and r.t <= offT then table.insert(sx, r.sx); table.insert(sy, r.sy); table.insert(sz, r.sz) end
end
local fake = #sx > 0 and { median(sx), median(sy), median(sz) } or nil

print(string.format("== %s  (mode %s)", label, truth.mode))
print(string.format("faker's own body: real place (%.1f, %.1f, %.1f), moved at most %.3f studs over the run", real[1], real[2], real[3], drift))
if fake then
	print(string.format("server body held at (%.1f, %.1f, %.1f): %.1f studs from the real place", fake[1], fake[2], fake[3], dist(fake, real)))
else
	print("the suite published no server body (fake did not engage)")
end
local ns = truth.net
print(string.format("net: sent %d, blocked %d, failed %d, denied %s, rate %.1f/s", ns.sent, ns.blocked, ns.failed, tostring(ns.denied), ns.rate))

local before, during, after = {}, {}, {}
local seenAt, backAt
for _, r in ipairs(watch.rows) do
	local p = { r.x, r.y, r.z }
	if r.t < onT - 0.1 and r.t > onT - 1.2 then table.insert(before, dist(p, real)) end
	if fake and r.t >= onT + 1.0 and r.t <= offT - 0.1 then table.insert(during, dist(p, fake)) end
	if r.t >= offT + 1.2 then table.insert(after, dist(p, real)) end
	if fake and not seenAt and r.t >= onT and dist(p, fake) < 3 then seenAt = r.t - onT end
	if not backAt and r.t >= offT and dist(p, real) < 3 then backAt = r.t - offT end
end
print("the watcher saw (distance from the REAL place) before the fake: " .. stats(before))
if fake then print("the watcher saw (distance from the FAKE place) during the hold: " .. stats(during)) end
print(string.format("fake first seen %s after it was set; real first seen %s after it was cleared (watcher rows %d, ping %.0f ms)",
	seenAt and string.format("%.2f s", seenAt) or "never", backAt and string.format("%.2f s", backAt) or "never", #watch.rows, watch.ping or -1))
print("the watcher saw (distance from the REAL place) after clearing: " .. stats(after))
