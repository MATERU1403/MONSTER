-- The same attack test with the older, proven ragebot that ships in the hub (B.DaHood, "dahood.on") and the void strike
-- (the sky void over raknet: every packet inside the decoded format, so no error 260). Compare with attack.lua, the suite's new ragebot.
-- Globals: ATK_TARGET (default gotham77r), ATK_SECONDS (default 40), ATK_LABEL (default L1), ATK_ROUND (void | none)
-- Settings are memory only (quiet) and put back; the ragebot and the fake are always turned off again.
local g = getgenv()
local B = g.BASED
if type(B) ~= "table" or not B.Config or not B.DaHood then return "BASED / DaHood is not loaded" end
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
local Config, DaHood = B.Config, B.DaHood
local target, seconds, label, round = g.ATK_TARGET or "gotham77r", g.ATK_SECONDS or 40, g.ATK_LABEL or "L1", g.ATK_ROUND or "void"
local victim = Players:FindFirstChild(target)
if not victim then return "no player " .. target end
local function r1(v) return math.floor(v * 10 + 0.5) / 10 end

local SETUPS = {
	void = { { "monster.fakeWhere", "void" }, { "monster.strikeSpread", 12 }, { "monster.fake", true } },
	none = {},
}
local changed = {}
local function set(key, value)
	changed[#changed + 1] = { key, Config.get(key) }
	Config.set(key, value, true)
end

local rows, events, started = {}, {}, os.clock()
local function stamp(name, extra) events[#events + 1] = { name = name, t = r1(os.clock() - started), extra = extra } end
local rak, strike = g.MONSTER_RAK, g.MONSTER_STRIKE
local base = { hits = DaHood.hits or 0, taken = DaHood.taken or 0, sent = rak and rak.sent or 0, delayed = strike and strike.delayed or 0, direct = strike and strike.direct or 0 }

task.spawn(function()
	local ok, err = pcall(function()
		for _, change in ipairs(SETUPS[round] or {}) do set(change[1], change[2]) end
		DaHood.mark(victim, true)
		set("dahood.on", true)
		stamp("on")
		local lastHits = base.hits
		while os.clock() - started < seconds do
			task.wait(0.5)
			local c = victim.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			local be = c and c:FindFirstChild("BodyEffects")
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local tool = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
			local row = {
				t = r1(os.clock() - started), st = workspace:GetServerTimeNow(), hp = hum and r1(hum.Health), armor = be and be:FindFirstChild("Armor") and be.Armor.Value,
				ko = be and be:FindFirstChild("K.O") and be["K.O"].Value or false, tgt = root and { r1(root.Position.X), r1(root.Position.Y), r1(root.Position.Z) } or nil,
				hits = (DaHood.hits or 0) - base.hits, sent = rak and rak.sent - base.sent or 0, held = tool and tool.Name, ammo = tool and tool:FindFirstChild("Ammo") and tool.Ammo.Value,
				delayed = strike and strike.delayed - base.delayed or 0, direct = strike and strike.direct - base.direct or 0,
			}
			rows[#rows + 1] = row
			if row.hits ~= lastHits then stamp("hits", row.hits); lastHits = row.hits end
			if g.ATK_ABORT then stamp("abort"); break end
		end
	end)
	pcall(function() Config.set("dahood.on", false, true) end)
	for i = #changed, 1, -1 do pcall(Config.set, changed[i][1], changed[i][2], true) end
	pcall(function() DaHood.mark(victim, false) end)
	stamp("done")
	pcall(writefile, "monster-build/results/attack_" .. label .. ".json", Http:JSONEncode({
		label = label, target = target, seconds = seconds, round = round, error = (not ok) and tostring(err) or nil, rows = rows, events = events,
		hits = (DaHood.hits or 0) - base.hits, taken = (DaHood.taken or 0) - base.taken,
	}))
	g.ATTACK_DONE = label .. ": rows " .. #rows .. ", hits " .. tostring((DaHood.hits or 0) - base.hits) .. (ok and "" or (" ERROR " .. tostring(err)))
end)
g.ATTACK_DONE, g.ATK_ABORT = nil, nil
return "legacy attack " .. label .. " (" .. round .. ") vs " .. target .. " started (" .. seconds .. " s)"
