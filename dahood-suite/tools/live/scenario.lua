-- The faking client: run one fake-position mode for a while with the suite, and log the truth (its real body and what the
-- suite handed the server) each frame with server time. Runs in its own thread; writes monster-build/results/truth_<label>.json.
-- Globals: RIG_MODE (static|follow|jitter|anchor|void|thunder|orbit|none), RIG_SECONDS (hold, default 4), RIG_LEAD (s before, default 1.5),
--          RIG_TAIL (s after, default 2), RIG_LABEL, RIG_OFFX/OFFY/OFFZ (default 40, 0, 0), RIG_RADIUS (default 25), RIG_RATE (ms, default 120)
-- Settings are set quietly (memory only): nothing here is saved into the shared profile.
local g = getgenv()
local DH = g.MONSTER_DH
if type(DH) ~= "table" then return "MONSTER_DH is not loaded" end
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local mode, hold, lead, tail, label = g.RIG_MODE or "static", g.RIG_SECONDS or 4, g.RIG_LEAD or 1.5, g.RIG_TAIL or 2, g.RIG_LABEL or mode
local rows, events = {}, {}
local function r2(v) return math.floor(v * 100 + 0.5) / 100 end
local function stamp(name) events[#events + 1] = { name = name, t = workspace:GetServerTimeNow() } end

local conn = RunService.PostSimulation:Connect(function()
	local root = DH.root()
	if not root then return end
	local p = root.Position
	local row = { t = workspace:GetServerTimeNow(), x = r2(p.X), y = r2(p.Y), z = r2(p.Z) }
	local server = DH.Fakepos.server
	if server then row.sx, row.sy, row.sz = r2(server.X), r2(server.Y), r2(server.Z) end
	rows[#rows + 1] = row
end)

task.spawn(function()
	local ok, err = pcall(function()
		DH.set("monster.rakRate", 30, true)
		DH.set("monster.fakepos.orbitAround", g.RIG_ORBIT or "target", true)
		DH.set("monster.fakepos.offX", g.RIG_OFFX or 40, true)
		DH.set("monster.fakepos.offY", g.RIG_OFFY or 0, true)
		DH.set("monster.fakepos.offZ", g.RIG_OFFZ or 0, true)
		DH.set("monster.fakepos.radius", g.RIG_RADIUS or 25, true)
		DH.set("monster.fakepos.rate", g.RIG_RATE or 120, true)
		stamp("start")
		task.wait(lead)
		if mode ~= "none" then
			if mode == "void" then
				DH.set("monster.fakeWhere", "void", true)
			else
				DH.set("monster.fakeWhere", mode, true)
			end
			DH.set("monster.fake", true, true)
			stamp("on")
		end
		task.wait(hold)
		DH.set("monster.fake", false, true)
		stamp("off")
		task.wait(tail)
		stamp("end")
	end)
	conn:Disconnect()
	DH.set("monster.fake", false, true)
	writefile("monster-build/results/truth_" .. label .. ".json", Http:JSONEncode({ label = label, mode = mode, rows = rows, events = events, error = (not ok) and tostring(err) or nil,
		net = DH.Net.status(), fakepos = DH.Fakepos.status() }))
	g.SCENARIO_DONE = label .. ":" .. #rows .. (ok and "" or (" ERROR " .. tostring(err)))
end)
g.SCENARIO_DONE = nil
return "scenario " .. mode .. " (" .. label .. ") started"
