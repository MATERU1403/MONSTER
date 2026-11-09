-- ---- core: shared helpers, the K table, config, cleanup list, logging
local genv = getgenv()
DH.version, DH.build = "1.0", "__DH_BUILD__"
DH.GAME_ID = 1008451066
DH.isDaHood = game.GameId == DH.GAME_ID
DH.errors, DH.logs = 0, {}

local function service(name)
	local s = game:GetService(name)
	if cloneref then
		local ok, c = pcall(cloneref, s)
		if ok and c then return c end
	end
	return s
end
local S = {
	Players = service("Players"), Run = service("RunService"), Input = service("UserInputService"), Stats = service("Stats"),
	Http = service("HttpService"), Rep = service("ReplicatedStorage"), Gui = service("GuiService"),
}
DH.S = S
local LocalPlayer = S.Players.LocalPlayer
DH.LP = LocalPlayer
DH.ENV = { Vector3 = Vector3, CFrame = CFrame }
local ZERO = Vector3.new(0, 0, 0)
DH.ZERO = ZERO

-- ---- the cleanup list: every connection, hook, drawing and thread the suite makes is added here and released together
do
	local Janitor = {}
	Janitor.__index = Janitor
	function Janitor.new() return setmetatable({ items = {} }, Janitor) end
	function Janitor:add(item, label)
		if item ~= nil then self.items[#self.items + 1] = { item = item, label = label } end
		return item
	end
	local function dispose(item)
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then item:Disconnect()
		elseif kind == "function" then item()
		elseif kind == "Instance" then item:Destroy()
		elseif kind == "thread" then pcall(task.cancel, item)
		elseif kind == "table" then
			if item.Disconnect then item:Disconnect()
			elseif item.Destroy then item:Destroy()
			elseif item.Remove then item:Remove()
			elseif item.disable then item:disable() end
		end
	end
	function Janitor:clean()
		for i = #self.items, 1, -1 do
			local entry = self.items[i]
			local ok, err = pcall(dispose, entry.item)
			if not ok then DH.warn("janitor:" .. tostring(entry.label), tostring(err)) end
		end
		self.items = {}
	end
	function Janitor:size() return #self.items end
	DH.Janitor = Janitor
	DH.janitor = Janitor.new()
end

-- ---- logging: rate limited per key, kept in a small ring for the status panel; nothing here runs per packet
do
	local lastShown = {}
	function DH.warn(key, message, interval)
		local now = os.clock()
		if lastShown[key] and now - lastShown[key] < (interval or 5) then return end
		lastShown[key] = now
		local entry = { t = now, key = key, msg = tostring(message) }
		DH.logs[#DH.logs + 1] = entry
		if #DH.logs > 60 then table.remove(DH.logs, 1) end
		warn("[MONSTER] " .. key .. ": " .. entry.msg)
	end
	function DH.fail(where, err)
		DH.errors += 1
		DH.lastError = where .. ": " .. tostring(err)
		DH.warn("error:" .. where, tostring(err), 3)
	end
	---Wrap fn so an error is recorded and swallowed instead of thrown (hooks and connections never throw).
	function DH.safe(where, fn)
		return function(...)
			local ok, a, b, c = pcall(fn, ...)
			if not ok then DH.fail(where, a); return nil end
			return a, b, c
		end
	end
end

-- ---- events between the modules and from plugins ("unload", "panic", ...)
do
	local listeners = {}
	function DH.on(name, fn)
		local list = listeners[name] or {}
		listeners[name] = list
		list[#list + 1] = fn
		return { Disconnect = function() for i, f in ipairs(list) do if f == fn then table.remove(list, i) break end end end }
	end
	function DH.fire(name, ...)
		for _, fn in ipairs(table.clone(listeners[name] or {})) do
			local ok, err = pcall(fn, ...)
			if not ok then DH.fail("event:" .. name, err) end
		end
	end
end

-- ---- config: BasedHub's own Config holds the values (so the user's saved profiles keep working); a pure store stands in without it
DH.SCHEMA = {}
do
	local store
	local function backend()
		if Config then return Config end
		if not store then
			store = DH.F.cfgstore().new(DH.SCHEMA, {
				encode = function(t) return S.Http:JSONEncode(t) end,
				decode = function(s) return S.Http:JSONDecode(s) end,
			})
			local ok, text = pcall(readfile, "monster_dh.json")
			if ok and type(text) == "string" then store:load(text) end
			store.on_ = store.on
		end
		return store
	end
	---Register a setting. def = { kind, default, min, max, step, options, label, desc, group }
	function DH.define(id, def)
		DH.SCHEMA[id] = def
		local cfg = backend()
		if cfg == store then cfg:define(id, def.default, def) else cfg.define(id, def.default) end
		return id
	end
	function DH.get(id)
		local cfg = backend()
		local v
		if cfg == store then v = cfg:get(id) else v = cfg.get(id) end
		if v == nil and DH.SCHEMA[id] then return DH.SCHEMA[id].default end
		return v
	end
	---@param quiet boolean? true keeps it out of the saved profile (memory only)
	function DH.set(id, value, quiet)
		local cfg = backend()
		local def = DH.SCHEMA[id]
		if def then value = DH.F.cfgstore().coerce(def, value) end
		if cfg == store then return cfg:set(id, value, quiet) end
		return cfg.set(id, value, quiet)
	end
	function DH.watch(id, fn)
		local cfg = backend()
		if cfg == store then return cfg:on(id, fn) end
		local ok, conn = pcall(cfg.on, id, fn)
		return ok and conn or nil
	end
	---Fix saved values that no longer fit (a slider out of range, an option that was removed).
	function DH.sanitize()
		local fixed = 0
		local coerce = DH.F.cfgstore().coerce
		for id, def in pairs(DH.SCHEMA) do
			local v = DH.get(id)
			local ok, nv, changed = pcall(coerce, def, v)
			if ok and changed then DH.set(id, nv, true); fixed += 1 end
		end
		return fixed
	end
	function DH.save()
		if store and store.dirty then pcall(writefile, "monster_dh.json", store:dump() or "{}"); store.dirty = false end
	end
end

-- ---- K: every number that came from tuning, editable from the UI (ids monster.k.<NAME>)
do
	local DEFS = {
		-- name, default, min, max, step, group, description
		{ "INTERP", 0.18, 0, 0.6, 0.005, "net", "Roblox's interpolation buffer in seconds (lead = ping + this). Measured 2026-11-09 on Volt, two alts: 0.180 s (total shift 0.240 s, pings 59 ms)." },
		{ "NET_FAIL_COUNT", 20, 3, 200, 1, "net", "Send failures inside the window that count as raknet being denied." },
		{ "NET_FAIL_WINDOW", 2, 0.5, 10, 0.5, "net", "Seconds of the send-failure window." },
		{ "VOID_BAIT", 0.1, 0, 2, 0.05, "void", "Seconds the body is still shown before it goes (bait delay)." },
		{ "VOID_HOLD", 0.6, 0.1, 5, 0.05, "void", "Seconds with no threat near before the void is let go." },
		{ "VOID_PEEK", 0.12, 0.02, 1, 0.02, "void", "Seconds the body comes back between respawn holds." },
		{ "VOID_RAMP1", 3.2, 0.2, 10, 0.1, "void", "Respawn: first hold (s)." },
		{ "VOID_RAMP2", 0.55, 0.05, 5, 0.05, "void", "Respawn: second hold (s)." },
		{ "VOID_RAMP3", 0.25, 0.05, 5, 0.05, "void", "Respawn: third hold (s)." },
		{ "VOID_RAMP4", 0.15, 0.05, 5, 0.05, "void", "Respawn: last hold (s)." },
		{ "VOID_DEAD_HOLD", 4, 0.5, 20, 0.5, "void", "Seconds to void after the target dies." },
		{ "ORBIT_SPEED", 28, 1, 120, 1, "orbit", "Orbit: radians a second." },
		{ "ORBIT_RADIUS", 135, 5, 600, 1, "orbit", "Orbit: ring radius in studs." },
		{ "ORBIT_H1", 200000, 0, 1000000, 500, "orbit", "Orbit: height, high flip." },
		{ "ORBIT_H2", 199500, 0, 1000000, 500, "orbit", "Orbit: height, low flip." },
		{ "ORBIT_FLIP", 20, 1, 60, 1, "orbit", "Orbit: height flips a second." },
		{ "ORBIT_JIT_H", 10, 0, 60, 1, "orbit", "Orbit: horizontal jitter (studs)." },
		{ "ORBIT_JIT_V", 5, 0, 60, 1, "orbit", "Orbit: vertical jitter (studs)." },
		{ "ORBIT_JIT_RATE", 80, 1, 200, 1, "orbit", "Orbit: jitter rate (rad/s)." },
		{ "ORBIT_VEL", 420, 0, 1000, 10, "orbit", "Orbit: real-body speed when it is pushed round (studs/s)." },
		{ "ORBIT_GROUND_CAP", 38, 5, 100, 1, "orbit", "Real-body speed cap on the ground (the game's speed lock is 40)." },
		{ "PHYS_RANGE", 60, 5, 300, 1, "physrep", "PhysicsRepRootPart ride lets go past this distance (studs)." },
		{ "PHYS_UP", 3, 0, 12, 0.5, "physrep", "Default height above the target root while riding (studs)." },
		{ "RES_WINDOW", 1.0, 0.3, 3, 0.1, "resolver", "Seconds of history each estimator reads." },
		{ "RES_MAX_JUMP", 30, 5, 200, 1, "resolver", "A move this big in one sample is a teleport, not a body (studs)." },
		{ "RES_MAX_SPEED", 140, 20, 600, 5, "resolver", "Fastest a body can really go (studs/s)." },
		{ "RES_MIN_CONF", 0.35, 0, 1, 0.01, "resolver", "Below this the ragebot skips the shot (or spreads, by setting)." },
		{ "RES_SIGMA", 6, 1, 40, 1, "resolver", "Guesses closer than this agree (studs)." },
		{ "RES_WATCH", 0.6, 0.2, 2, 0.05, "resolver", "Seconds a shot is watched for damage (hit-confirm learning)." },
		{ "DEF_SAFE", 90, 10, 400, 5, "defense", "An armed player inside this is a threat (studs)." },
		{ "DEF_BAG", 12, 3, 60, 1, "defense", "Someone this close to a knocked body is a bagger (studs)." },
		{ "DEF_FLAME", 25, 5, 100, 1, "defense", "A flamethrower reaches this far (studs)." },
		{ "DEF_GUN", 300, 50, 1000, 10, "defense", "A gun counts out to this range (studs)." },
		{ "DEF_TELE", 80, 20, 400, 5, "defense", "A jump this big in a sample is a teleport (studs)." },
		{ "RAGE_ARRIVE", 0.25, 0.05, 1, 0.01, "rage", "Seconds the server must have the body at a new place before a shot is sent." },
		{ "RAGE_RANGE", 250, 30, 900, 10, "rage", "Longest shot (studs) when the weapon does not say." },
		{ "RAGE_STOMP", 3, 1.5, 9, 0.5, "rage", "Stomp height above the target (studs)." },
		{ "RAGE_RELOAD_AT", 0, 0, 10, 1, "rage", "Reload when the magazine is at or below this (0 = only when empty)." },
	}
	local byName = {}
	for _, d in ipairs(DEFS) do byName[d[1]] = d end
	DH.KDEFS = DEFS
	DH.K = {}
	function DH.K.def(name) return byName[name] end
	function DH.K.id(name) return "monster.k." .. name end
	function DH.K.get(name)
		local d = byName[name]
		local v = DH.get("monster.k." .. name)
		if v == nil then return d and d[2] end
		return v
	end
	for _, d in ipairs(DEFS) do
		DH.define("monster.k." .. d[1], { kind = "slider", default = d[2], min = d[3], max = d[4], step = d[5], label = d[1], desc = d[7], group = d[6] })
	end
end
local K = DH.K.get

-- ---- character helpers (the health gate used everywhere)
function DH.character() return LocalPlayer.Character end
function DH.root(character)
	character = character or LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
function DH.humanoid(character)
	character = character or LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
function DH.effects(character) return character and character:FindFirstChild("BodyEffects") end
function DH.knocked(character)
	local fx = DH.effects(character)
	local ko = fx and fx:FindFirstChild("K.O")
	return ko ~= nil and ko.Value == true
end
function DH.armor(character)
	local fx = DH.effects(character)
	local a = fx and fx:FindFirstChild("Armor")
	return a and a.Value or 0
end
---A body that is loaded, alive and standing: HumanoidRootPart, Humanoid, Head, LowerTorso, BodyEffects, Armor, FULLY_LOADED_CHAR, and not KO.
---@return boolean, string?
function DH.ready(character)
	if not character then return false, "no character" end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (character:FindFirstChild("HumanoidRootPart") and humanoid and character:FindFirstChild("Head") and character:FindFirstChild("LowerTorso")) then return false, "parts" end
	local fx = character:FindFirstChild("BodyEffects")
	if not (fx and fx:FindFirstChild("Armor")) then return false, "effects" end
	if not character:FindFirstChild("FULLY_LOADED_CHAR") then return false, "loading" end
	if humanoid.Health <= 0 then return false, "dead" end
	if DH.knocked(character) then return false, "ko" end
	return true
end
function DH.hasShield(character) return character ~= nil and character:FindFirstChildOfClass("ForceField") ~= nil end

---Ping in seconds, and the lead a remote body needs: ping plus Roblox's interpolation buffer (measured, not a fixed 0.22).
do
	local item
	pcall(function() item = S.Stats.Network.ServerStatsItem:FindFirstChild("Data Ping") end)
	function DH.ping()
		local ok, v = pcall(function() return item and item:GetValue() or 100 end)
		return (ok and v or 100) / 1000
	end
	function DH.lag() return DH.ping() + K("INTERP") end
end

---A key setting ("E", "MouseButton2", "None") as something InputBegan can compare.
function DH.keyOf(name)
	if type(name) ~= "string" or name == "None" or name == "" then return nil end
	local ok, code = pcall(function() return Enum.KeyCode[name] end)
	if ok and code then return code end
	ok, code = pcall(function() return Enum.UserInputType[name] end)
	if ok and code then return code end
	return nil
end

-- ---- modules: each has init / enable / disable / status; panic and unload go through here
DH.modules = {}
function DH.register(name, module)
	module.name = name
	DH.modules[name] = module
	return module
end
function DH.status()
	local out = { build = DH.build, errors = DH.errors, lastError = DH.lastError }
	for name, module in pairs(DH.modules) do
		local ok, status = pcall(function() return module.status and module.status() or nil end)
		out[name] = ok and status or { error = tostring(status) }
	end
	return out
end
function DH.disableAll(reason)
	for name, module in pairs(DH.modules) do
		local ok, err = pcall(function() if module.disable then module.disable(reason) end end)
		if not ok then DH.fail("disable:" .. name, err) end
	end
end
