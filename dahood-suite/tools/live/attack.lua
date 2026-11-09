-- Attack test, run on the MONSTER account: the suite's ragebot against ONE named player (an owned alt), nothing else switched on.
-- Settings are memory only (quiet) and put back at the end; the ragebot is always turned off again, whatever happens.
-- Globals: ATK_TARGET (default gotham77r), ATK_SECONDS (default 45), ATK_LABEL (default a1), ATK_PATTERN (default ring), ATK_WEAPON (default auto)
-- Writes monster-build/results/attack_<label>.json, and leaves a short line in getgenv().ATTACK_DONE.
local g = getgenv()
local DH = g.MONSTER_DH
if type(DH) ~= "table" then return "MONSTER_DH is not loaded" end
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local target, seconds, label, pattern = g.ATK_TARGET or "gotham77r", g.ATK_SECONDS or 45, g.ATK_LABEL or "a1", g.ATK_PATTERN or "ring"
local function r1(v) return math.floor(v * 10 + 0.5) / 10 end
local function vec(v) return v and { r1(v.X), r1(v.Y), r1(v.Z) } or nil end

local wanted = {
	["monster.rage.targets"] = target, ["monster.rage.targetMode"] = "closest-to-me", ["monster.rage.fov"] = 180, ["monster.rage.walls"] = false,
	["monster.rage.pattern"] = pattern, ["monster.rage.strafe"] = false, ["monster.rage.chase"] = false, ["monster.rage.walk"] = false,
	["monster.rage.jump"] = false, ["monster.rage.stomp"] = true, ["monster.rage.weapon"] = g.ATK_WEAPON or "auto", ["monster.rage.safety"] = true,
	["monster.void.protect"] = false, ["monster.void.whileWaiting"] = false, ["monster.rakRate"] = 30,
}
local before = {}
for key, value in pairs(wanted) do before[key] = DH.get(key) end
-- pattern numbers (dahood.k.*) live in the BasedHub config: ATK_K = { HAUNT_APART = 6 } sets them quietly and they are put back
local B, kBefore = g.BASED, {}
if type(g.ATK_K) == "table" and B and B.Config then
	for name in pairs(g.ATK_K) do local ok, v = pcall(B.Config.get, "dahood.k." .. name); kBefore[name] = ok and v or nil end
end

local rows, events, startedAt = {}, {}, os.clock()
local function stamp(name, extra) events[#events + 1] = { name = name, t = r1(os.clock() - startedAt), extra = extra } end

task.spawn(function()
	local ok, err = pcall(function()
		for key, value in pairs(wanted) do DH.set(key, value, true) end
		for name, value in pairs(type(g.ATK_K) == "table" and g.ATK_K or {}) do pcall(B.Config.set, "dahood.k." .. name, value, true) end
		stamp("configured")
		DH.set("monster.rage.on", true, true)
		stamp("rage on")
		local lastFired, lastKo = 0, false
		while os.clock() - startedAt < seconds do
			task.wait(0.5)
			local me = DH.root()
			local p = Players:FindFirstChild(target)
			local c = p and p.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			local status = DH.Rage.status()
			local server = DH.Fakepos.server
			local row = {
				t = r1(os.clock() - startedAt), st = workspace:GetServerTimeNow(), why = status.why, me = me and vec(me.Position), server = server and vec(server.Position), net = DH.Net.on and 1 or 0,
				tgt = root and vec(root.Position), hp = hum and r1(hum.Health), armor = c and DH.armor(c), ko = c and DH.knocked(c) or false,
				fired = status.fired, reloads = status.reloads, stomps = status.stomps, kills = status.kills, target = status.target, paused = status.autoPaused,
				riding = status.riding, void = DH.Void.active() and 1 or 0,
			}
			local gun = c and DH.character() and DH.character():FindFirstChildOfClass("Tool")
			row.held = gun and gun.Name
			row.ammo = gun and gun:FindFirstChild("Ammo") and gun.Ammo.Value
			rows[#rows + 1] = row
			if status.fired ~= lastFired then stamp("shots", status.fired); lastFired = status.fired end
			if row.ko and not lastKo then stamp("target KO") end
			lastKo = row.ko
			if g.ATK_ABORT then stamp("abort"); break end
		end
	end)
	-- always: off, settings back, released
	pcall(function() DH.set("monster.rage.on", false, true); DH.Rage.stop() end)
	for key, value in pairs(before) do pcall(DH.set, key, value, true) end
	for name, value in pairs(kBefore) do pcall(B.Config.set, "dahood.k." .. name, value, true) end
	pcall(function() DH.Net.release(DH.root() and DH.root().CFrame) end)
	stamp("done")
	local status = DH.Rage.status()
	pcall(writefile, "monster-build/results/attack_" .. label .. ".json", Http:JSONEncode({
		label = label, target = target, seconds = seconds, pattern = pattern, error = (not ok) and tostring(err) or nil, rows = rows, events = events,
		rage = status, net = DH.Net.status(), fakepos = DH.Fakepos.status(), void = DH.Void.status(),
	}))
	g.ATTACK_DONE = label .. ": rows " .. #rows .. ", shots " .. tostring(status.fired) .. ", kills " .. tostring(status.kills) .. (ok and "" or (" ERROR " .. tostring(err)))
end)
g.ATTACK_DONE, g.ATK_ABORT = nil, nil
return "attack " .. label .. " vs " .. target .. " started (" .. seconds .. " s, pattern " .. pattern .. ")"
