-- ============================================================================
--  MONSTER lab  -  an HvH test harness for the Da Hood ragebot
--
--  Run it on the MONSTER alt, after MONSTER itself has loaded:
--    loadstring(game:HttpGet("https://raw.githubusercontent.com/MATERU1403/MONSTER/claude/modest-allen-6akhtm/monster_lab.lua"))()
--
--  It changes nothing on its own. It only:
--    * writes  workspace/MONSTER/hvh_log.json  every 2 s: this round's kills, deaths, hits and
--      the rest of the ragebot's counters (since the round began), the score against each
--      player fought, the settings in use, and every finished round before it;
--    * reads   workspace/MONSTER/hvh_tune.json  every second. When its "round" number changes,
--      the round so far is closed and filed, and the new round's settings are put in.
--
--  hvh_tune.json:
--    {
--      "round": 2,                                  -- a new number starts a new round
--      "mark": ["VisionsAltName"],                  -- players to mark (optional)
--      "clearMarks": false,                         -- unmark everyone first (optional)
--      "preset": "main",                            -- a ragebot preset first (optional)
--      "settings": { "dahood.lure": false, "dahood.k.LAG": 0.18 },   -- any dahood.* setting
--      "on": true                                   -- switch the ragebot on or off (optional)
--    }
--  Only settings whose id starts with "dahood." are touched. Run it again to restart it;
--  getgenv().MONSTER_LAB.stop() stops it.
-- ============================================================================
local genv = getgenv()
if genv.MONSTER_LAB and genv.MONSTER_LAB.stop then genv.MONSTER_LAB.stop() end
local lab = { alive = true }
genv.MONSTER_LAB = lab
function lab.stop() lab.alive = false end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local DIR = "MONSTER"
local LOG, TUNE = DIR .. "/hvh_log.json", DIR .. "/hvh_tune.json"

local function waitFor(get, seconds)
	local giveUp = os.clock() + seconds
	local value = get()
	while not value and os.clock() < giveUp and lab.alive do
		task.wait(0.25)
		value = get()
	end
	return value
end

local B = waitFor(function() return genv.BASED end, 60)
local DH = B and waitFor(function() return B.DaHood and B.DaHood.api and B.DaHood end, 90)
if not DH then
	warn("[MONSTER lab] the Da Hood ragebot is not running here (load MONSTER in Da Hood first)")
	return
end
local Config = B.Config
if not isfolder(DIR) then makefolder(DIR) end

-- what is counted: every counter the ragebot keeps
local COUNTERS = { "kills", "deaths", "hits", "shots", "taken", "early", "stomps", "volleys", "crossed", "crossTaken", "salvoHeld",
	"lures", "lureHurt", "flakTries", "flakTaken", "ambushes", "ambushTaken", "pads", "padTaken", "presses", "pressTaken",
	"counters", "movedOn", "snipeTries", "snipeTaken", "pounceHurt" }
-- the settings written into the log with each round (the resolver's numbers, dahood.k.*, are added from DH.TUNE)
local KEYS = { "on", "preset", "part", "fire", "guns", "stance", "priority", "stick", "threatWeight", "spreadWeight", "predict", "lead",
	"leadBase", "leadMult", "learn", "seen", "arrive", "shieldLead", "margin", "switchWait", "salvo", "salvoWait", "pipeline", "cross",
	"stomp", "stompUp", "stompEvery", "finish", "oneTap", "hover", "frenzy", "never", "radius", "jitter", "motion", "motionSpeed",
	"motionSize", "swarmHold", "swarmShake", "wait", "voidRoam", "flak", "flakOpen", "lure", "ringLure", "bait", "ambush", "pounce",
	"press", "snipe", "padTrap", "walls", "bunker", "noclip", "exposeMax", "armorSafe", "autoArmor", "armorBelow", "smartReload" }

local function plain(value)
	local kind = type(value)
	if kind == "number" or kind == "string" or kind == "boolean" then return value end
	if kind == "table" then
		local out = {}
		for key, item in pairs(value) do
			local clean = plain(item)
			if clean ~= nil and (type(key) == "number" or type(key) == "string") then out[key] = clean end
		end
		return out
	end
	return nil                                   -- (colours and other userdata are left out of the log)
end

local function settingsNow()
	local out = {}
	for _, key in ipairs(KEYS) do
		local ok, value = pcall(Config.get, "dahood." .. key)
		if ok then out[key] = plain(value) end
	end
	for _, entry in ipairs(DH.TUNE or {}) do
		if entry.id then
			local ok, value = pcall(Config.get, entry.id)
			if ok then out[entry.id] = plain(value) end
		end
	end
	return out
end

local function countersNow()
	local out = {}
	for _, key in ipairs(COUNTERS) do out[key] = tonumber(DH[key]) or 0 end
	return out
end

local function scoresNow()
	local out = {}
	for userId, score in pairs(DH.scores or {}) do
		out[tostring(userId)] = { name = score.name, kills = score.kills or 0, deaths = score.deaths or 0 }
	end
	return out
end

local function since(now, base)
	local out = {}
	for key, value in pairs(now) do out[key] = value - (base[key] or 0) end
	return out
end

local function scoresSince(now, base)
	local out = {}
	for id, score in pairs(now) do
		local was = base[id] or { kills = 0, deaths = 0 }
		local kills, deaths = score.kills - was.kills, score.deaths - was.deaths
		if kills ~= 0 or deaths ~= 0 then out[id] = { name = score.name, kills = kills, deaths = deaths } end
	end
	return out
end

local history = {}
local round

local function openRound(id, applied, problems)
	round = { id = id, began = os.clock(), startedAt = os.time(), counters = countersNow(), scores = scoresNow(), applied = applied or {},
		problems = problems or {}, settings = settingsNow() }
end

local function roundReport(closing)
	local counters, scores = countersNow(), scoresNow()
	local report = {
		round = round.id,
		seconds = math.floor((os.clock() - round.began) * 10 + 0.5) / 10,
		startedAt = round.startedAt,
		applied = round.applied,
		problems = round.problems,
		settings = round.settings,
		totals = since(counters, round.counters),
		vs = scoresSince(scores, round.scores),
	}
	if not closing then report.live = true end
	return report
end

local function findPlayer(name)
	local wanted = string.lower(tostring(name))
	for _, player in ipairs(Players:GetPlayers()) do
		if string.lower(player.Name) == wanted or string.lower(player.DisplayName) == wanted then return player end
	end
	return nil
end

-- put a tune file's round in; returns what was applied and what could not be
local function apply(tune)
	local applied, problems = {}, {}
	if tune.clearMarks and DH.clearMarks then DH.clearMarks() end
	if type(tune.preset) == "string" and DH.applyPreset then
		local ok, why = pcall(DH.applyPreset, tune.preset)
		if ok then applied.preset = tune.preset else problems[#problems + 1] = "preset " .. tune.preset .. ": " .. tostring(why) end
	end
	if type(tune.settings) == "table" then
		for key, value in pairs(tune.settings) do
			if type(key) == "string" and string.sub(key, 1, 7) == "dahood." and key ~= "dahood.on" then
				local ok, why = pcall(Config.set, key, value)
				if ok then applied[key] = plain(value) else problems[#problems + 1] = key .. ": " .. tostring(why) end
			else
				problems[#problems + 1] = tostring(key) .. ": not a dahood.* setting, left alone"
			end
		end
	end
	if type(tune.mark) == "table" then
		for _, name in ipairs(tune.mark) do
			local player = findPlayer(name)
			if player and DH.mark then DH.mark(player, true); applied["mark:" .. player.Name] = true
			else problems[#problems + 1] = "mark " .. tostring(name) .. ": no such player here" end
		end
	end
	if type(tune.on) == "boolean" then
		pcall(Config.set, "dahood.on", tune.on)
		applied["dahood.on"] = tune.on
	end
	return applied, problems
end

local function readTune()
	if not isfile(TUNE) then return nil end
	local okRead, text = pcall(readfile, TUNE)
	if not okRead or type(text) ~= "string" or text == "" then return nil end
	local okJson, tune = pcall(HttpService.JSONDecode, HttpService, text)
	if not okJson or type(tune) ~= "table" then return nil end
	return tune
end

local function writeLog()
	local log = {
		updated = os.time(),
		me = LP.Name,
		placeId = game.PlaceId,
		jobId = game.JobId,
		players = #Players:GetPlayers(),
		status = DH.status,
		target = DH.target and DH.target.Name or nil,
		lag = DH.lag,
		answer = DH.answer,
		current = roundReport(false),
		history = history,
	}
	local ok, text = pcall(HttpService.JSONEncode, HttpService, log)
	if ok then pcall(writefile, LOG, text) end
end

-- a round 0 from now, whatever is set: then whatever the tune file says
openRound(0)
local lastLog = 0
task.spawn(function()
	while lab.alive and B.alive ~= false do
		local tune = readTune()
		if tune and tonumber(tune.round) and tonumber(tune.round) ~= round.id then
			history[#history + 1] = roundReport(true)
			while #history > 60 do table.remove(history, 1) end
			local applied, problems = apply(tune)
			openRound(tonumber(tune.round), applied, problems)
			lastLog = 0
		end
		if os.clock() - lastLog >= 2 then
			lastLog = os.clock()
			writeLog()
		end
		task.wait(1)
	end
end)

if B.Window and B.Window.toast then
	B.Window.toast({ title = "MONSTER lab running", text = "Logging to " .. LOG .. ", tuning from " .. TUNE .. ".", icon = "flask-conical", time = 4 })
end
