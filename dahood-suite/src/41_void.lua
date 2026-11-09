-- ---- void: the body sent where nobody can reach it, in phases (see pure/voidsm.lua). The Desync block holds the body there
-- (the sky box over raknet, or a body swap far out) and brings it back for a strike; this module decides WHEN, and WHERE.
local SM = DH.F.voidsm()
local Void = {
	sm = nil, state = { voided = false, phase = "idle", holdLeft = 0 }, rng = Random.new(), waiting = false, ramps = 0, diedOnce = false,
	-- what the engine was given for the two big constants: (1.88e13, 1e29, 9.98e14) and (18812581888888, 99999999999999999999999999999, 998235235621111)
	NAN1 = Vector3.new(1.8812581888888e13, 9.9999999999999e29, 9.98235235621111e14),
	NAN2 = Vector3.new(18812581888888, 99999999999999999999999999999, 998235235621111),
}
DH.Void = Void

DH.define("monster.void.position", { kind = "dropdown", default = "sky", label = "Void position", group = "void",
	desc = "Sky: a random place high over the map, sent by raknet. Far: a body swap a billion studs out. NaN 1 / NaN 2: the two big constants. Orbit: the strafe.",
	options = { { "sky", "Sky (raknet, safe)" }, { "far", "Far (body swap)" }, { "nan1", "NaN 1 (clamped)" }, { "nan2", "NaN 2 (clamped)" }, { "orbit", "Orbit strafe" } } })
DH.define("monster.void.protect", { kind = "toggle", default = false, label = "Void when threatened", desc = "Go to the void while an armed player is near, come back after a calm hold.", group = "void" })
DH.define("monster.void.whenDead", { kind = "toggle", default = true, label = "Void when the target dies", desc = "Hide for a few seconds after a knock.", group = "void" })
DH.define("monster.void.whileWaiting", { kind = "toggle", default = false, label = "Void while waiting", desc = "Hide while the ragebot has nothing to shoot or is reloading.", group = "void" })
DH.define("monster.void.respawnRamp", { kind = "toggle", default = true, label = "Void after respawn", desc = "After a death: a long hold, then shorter ones, then out.", group = "void" })
DH.define("monster.void.key", { kind = "keybind", default = "None", label = "Void key", desc = "Hold / toggle the void with a key.", group = "void" })
DH.define("monster.void.keyMode", { kind = "dropdown", default = "Toggle", label = "Void key mode", group = "void", desc = "Hold, Toggle, or Always.",
	options = { { "Hold", "Hold" }, { "Toggle", "Toggle" }, { "Always", "Always" } } })

local function build()
	local K = DH.K.get
	return { baitDelay = K("VOID_BAIT"), hold = K("VOID_HOLD"), peek = K("VOID_PEEK"), ramp = { K("VOID_RAMP1"), K("VOID_RAMP2"), K("VOID_RAMP3"), K("VOID_RAMP4") } }
end
Void.sm = SM.new(build())

---Ask for the void (`ttl` seconds, or until cancelled).
function Void.request(source, ttl) Void.sm:request(source, os.clock(), ttl) end
function Void.cancel(source) Void.sm:cancel(source) end

---True while the body is to be voided (a request is held, or a respawn ramp is on, or the older toggle: Where = Void).
function Void.active()
	return Void.state.voided or (DH.get("monster.fake") == true and DH.get("monster.fakeWhere") == "void")
end
---"orbit" and "orbit-thunder" are what the ragebot's strafe forces; otherwise the setting.
function Void.style() return Void.forceStyle or DH.get("monster.void.position") end

---A body swap writes this to the REAL body, so it must stay a number the engine and the server can carry: the two big constants
---(1e29 and up) are what ends in "Error 260" (the server cannot read the position), so they are never written, only used as a style name.
Void.SWAP_MAX = 2e9 -- (the far box's own limit, measured to hold)
function Void.safe(v)
	if typeof(v) ~= "Vector3" then return nil end
	local m = Void.SWAP_MAX
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then return nil end -- NaN
	if math.abs(v.X) > m or math.abs(v.Y) > m or math.abs(v.Z) > m then return nil end -- inf and anything past the limit
	return v
end

---Where the body swap puts the server body for `style` (a Vector3). The sky box and the far box are the measured ones;
---NaN 1 / NaN 2 land in the far box too (guarded: `Void.guarded` counts how often a big constant was turned down).
function Void.spot(style)
	local r = Void.rng
	local want
	if style == "nan1" or style == "nan2" then
		Void.guarded = (Void.guarded or 0) + 1
		DH.warn("void.guard", "NaN void swapped for the far box (a 1e29 body swap ends in error 260)", 30)
		style = "far"
	end
	if style == "far" then want = Vector3.new(r:NextNumber(-1.5e9, 1.5e9), r:NextNumber(4e8, 2e9), r:NextNumber(-1.5e9, 1.5e9))
	else want = Vector3.new(r:NextNumber(-1000, 1000), r:NextNumber(600, 1000), r:NextNumber(-1000, 1000)) end
	return Void.safe(want) or Vector3.new(0, 800, 0)
end

---The key's request: Hold, Toggle or Always are handled by the key module, which calls this.
function Void.keyState(on)
	if on then Void.request("key") else Void.cancel("key") end
end

---The ragebot has (or no longer has) nothing to shoot.
function Void.setWaiting(on)
	if on == Void.waiting then return end
	Void.waiting = on
	if on and DH.get("monster.void.whileWaiting") then Void.request("waiting") else Void.cancel("waiting") end
end

function Void.targetDied()
	if DH.get("monster.void.whenDead") then Void.request("target-dead", DH.K.get("VOID_DEAD_HOLD")) end
end

local function onCharacter(character)
	if Void.diedOnce and DH.get("monster.void.respawnRamp") then
		Void.diedOnce = false
		Void.ramps += 1
		Void.sm:respawned(os.clock())
	end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then DH.janitor:add(humanoid.Died:Connect(function() Void.diedOnce = true end), "void.died") end
	end)
end

function Void.init()
	DH.janitor:add(DH.LP.CharacterAdded:Connect(onCharacter), "void.character")
	if DH.LP.Character then onCharacter(DH.LP.Character) end
	local acc = 0
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("void.step", function(dt)
		acc += dt
		if acc < 1 / 30 then return end
		acc = 0
		local cfg = build()
		Void.sm.cfg.baitDelay, Void.sm.cfg.hold, Void.sm.cfg.peek, Void.sm.cfg.ramp = cfg.baitDelay, cfg.hold, cfg.peek, cfg.ramp
		local near = DH.Defense ~= nil and DH.Defense.threatNear() or false
		Void.state = Void.sm:update(os.clock(), near)
	end)), "void.step")
end
function Void.enable() end
function Void.disable()
	Void.sm:reset()
	Void.state = { voided = false, phase = "idle", holdLeft = 0 }
	Void.waiting = false
end
function Void.status()
	local s = Void.state
	return { active = Void.active(), phase = s.phase, holdLeft = s.holdLeft, ramp = s.ramp, wanted = s.wanted, style = Void.style(), ramps = Void.ramps, releases = Void.sm.releases, guarded = Void.guarded or 0 }
end
DH.register("void", Void)
