-- ---- ragebot: MONSTER's own fighter. It picks a target (pure/targeting.lua), shoots from where the server believes the body is,
-- stomps with the physrep ride, moves by the chosen mode, and lets a plugin replace where it stands (setStrafeOverride).
-- It does not run together with BasedHub's own ragebot (two of them would shoot twice): it waits while that one is on.
-- Server rules it is built on (measured 2026-10 on the 2-alt rig, memory da-hood-ragebot): a shot's origin must be within 17 studs of where
-- the server has the body; the hit point within 22 of the part; a hop of more than ~10 studs needs 0.10-0.23 s before shots count;
-- a stomp counts from 1.5 to 9.5 studs above a knocked body and does nothing during a reload.
local Targeting = DH.F.targeting()
local Patterns = DH.F.patterns(DH.ENV)
local Rage = {
	tstate = {}, entry = nil, player = nil, paused = false, resumeTo = nil, autoPaused = nil, override = nil,
	fired = 0, stomps = 0, reloads = 0, spread = 0, spot = nil, spotSince = 0, nextShot = 0, reloadUntil = 0, equipAt = 0, stompAt = 0,
	nextJump = 0, lastPick = -1, oneTapUntil = 0, stompingNow = false, lastSight = { t = -1 }, targetWasKO = false, kills = 0,
}
DH.Rage = Rage

local function defineRage(id, def) def.group = "rage"; DH.define("monster.rage." .. id, def) end
defineRage("on", { kind = "toggle", default = false, label = "Ragebot", desc = "Fights from the fake position. Off while BasedHub's own ragebot runs." })
defineRage("key", { kind = "keybind", default = "None", label = "Ragebot key", desc = "Turn it on and off with a key." })
defineRage("keyMode", { kind = "dropdown", default = "Toggle", label = "Key mode", desc = "Hold, Toggle, or Always.", options = { { "Hold", "Hold" }, { "Toggle", "Toggle" }, { "Always", "Always" } } })
defineRage("targetMode", { kind = "dropdown", default = "threat", label = "Target", desc = "Who it picks.",
	options = { { "threat", "Biggest threat" }, { "closest-to-mouse", "Closest to mouse" }, { "closest-to-me", "Closest to me" }, { "lowest-health", "Lowest health" } } })
defineRage("targets", { kind = "input", default = "", label = "Only these players", desc = "Names, comma between. Empty: everyone who is not a friend." })
defineRage("fov", { kind = "slider", default = 160, min = 10, max = 180, step = 5, label = "FOV", desc = "Degrees off your camera line.", suffix = "°" })
defineRage("walls", { kind = "toggle", default = true, label = "Wall check", desc = "Skip players behind walls." })
defineRage("teamCheck", { kind = "toggle", default = false, label = "Team check", desc = "Skip your own team." })
defineRage("switchWait", { kind = "slider", default = 0.14, min = 0, max = 2, step = 0.02, label = "Switch wait", desc = "Seconds before it changes target.", suffix = " s" })
defineRage("part", { kind = "dropdown", default = "head", label = "Aim part", desc = "Head or torso.", options = { { "head", "Head" }, { "torso", "Torso" } } })
defineRage("weapon", { kind = "input", default = "auto", label = "Weapon", desc = "auto, or part of a gun's name ([Rifle], Double)." })
defineRage("flame", { kind = "toggle", default = false, label = "Flamethrower", desc = "Use the flamethrower up close (not measured)." })
defineRage("salvo", { kind = "toggle", default = true, label = "Salvo", desc = "Shotguns send all five pellets." })
defineRage("pipeline", { kind = "toggle", default = true, label = "Pipeline", desc = "Send the next shot without waiting for the answer." })
defineRage("oneTap", { kind = "toggle", default = false, label = "One tap", desc = "Head only, then wait for the hit before the next." })
defineRage("snipe", { kind = "toggle", default = false, label = "Snipe", desc = "Far targets only when they stand still." })
defineRage("autoReload", { kind = "toggle", default = true, label = "Auto reload", desc = "Reload an empty gun." })
defineRage("smartReload", { kind = "toggle", default = true, label = "Smart reload", desc = "Top the gun up while nobody is in sight." })
defineRage("strafe", { kind = "toggle", default = false, label = "Strafe", desc = "Orbit strafe: the server sees you whirl high over them; each shot brings you back." })
defineRage("strafeStyle", { kind = "dropdown", default = "sky", label = "Strafe height", desc = "Sky stays inside what a packet can carry; Thunder goes 200000 up (body swap).",
	options = { { "sky", "Sky" }, { "thunder", "200000 up" } } })
defineRage("chase", { kind = "toggle", default = false, label = "Chase", desc = "Your own body runs at the target." })
defineRage("walk", { kind = "toggle", default = false, label = "Walk to target", desc = "Your own body walks up to 15 studs from the target." })
defineRage("jump", { kind = "toggle", default = false, label = "Jump at target", desc = "Your own body jumps while closing in." })
defineRage("stomp", { kind = "toggle", default = true, label = "Stomp", desc = "Finish a knocked target from above." })
defineRage("pattern", { kind = "dropdown", default = "none", label = "Pattern", desc = "Where the server sees you, round the target.",
	options = { { "none", "None" }, { "ring", "Ring" }, { "pounce", "Pounce" }, { "lure", "Lure" }, { "haunt", "Haunt" }, { "ambush", "Ambush" }, { "press", "Press" }, { "swarm", "Swarm" } } })
defineRage("safety", { kind = "toggle", default = true, label = "Safety pauses", desc = "Pause when knocked, loading, in a vehicle, or a dangerous player is near." })

local function opt(id) return DH.get("monster.rage." .. id) end
function Rage.on() return opt("on") == true end

-- ---- the other players, as the targeting module wants them
local function isFriend(player)
	local roster = B and B.Roster
	return roster ~= nil and roster.friends ~= nil and roster.friends[player.UserId] == true
end

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local function clear(from, to, ignoreA, ignoreB)
	sightParams.FilterDescendantsInstances = { ignoreA, ignoreB, workspace.CurrentCamera }
	return workspace:Raycast(from, to - from, sightParams) == nil
end

local function screenInfo(pos)
	local camera = workspace.CurrentCamera
	if not camera then return 1e4, 180 end
	local v, on = camera:WorldToViewportPoint(pos)
	local mouse = S.Input:GetMouseLocation()
	local dist = on and (Vector2.new(v.X, v.Y) - mouse).Magnitude or 1e4
	local dir = pos - camera.CFrame.Position
	local angle = dir.Magnitude > 0 and math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(dir.Unit), -1, 1))) or 0
	return dist, angle
end

function Rage.candidates()
	local list = {}
	local me = DH.root()
	local character = DH.character()
	if DH.Defense then DH.Defense.assess() end
	for _, player in ipairs(S.Players:GetPlayers()) do
		if player ~= DH.LP then
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local humanoid = c and c:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				local pos = root.Position
				local screenDist, angle = screenInfo(pos)
				local entry = {
					id = player.UserId, name = string.lower(player.Name), player = player, pos = pos, health = humanoid.Health, armor = DH.armor(c),
					ko = DH.knocked(c) or humanoid.Health <= 1.5, dead = humanoid.Health <= 0, friend = isFriend(player), team = player.Team,
					forceField = DH.hasShield(c), screenDist = screenDist, aimAngle = angle, root = root, character = c, humanoid = humanoid,
				}
				if me and opt("walls") then entry.visible = clear(me.Position + Vector3.new(0, 1.5, 0), pos, character, c) else entry.visible = true end
				list[#list + 1] = entry
			end
		end
	end
	-- threat and crowding for the threat mode
	for _, a in ipairs(list) do
		local crowd = 0
		for _, b in ipairs(list) do
			if a ~= b and not b.ko and (a.pos - b.pos).Magnitude < 60 then crowd += 1 end
		end
		a.crowd = crowd
		a.threat = (DH.Defense and DH.Defense.threatOf and DH.Defense.threatOf(a.player)) or 0
	end
	return list
end

local function targetSet()
	local text = opt("targets")
	if type(text) ~= "string" or text == "" then return nil end
	local set = {}
	for name in string.gmatch(text, "[^,%s]+") do set[string.lower(name)] = true end
	return next(set) and set or nil
end

---Pick (and keep) a target, at 10 Hz.
function Rage.pick(now)
	if now - Rage.lastPick < 0.1 then return Rage.entry end
	Rage.lastPick = now
	local root = DH.root()
	local cfgPick = {
		mode = opt("targetMode"), fov = opt("fov"), walls = opt("walls"), teamCheck = opt("teamCheck"), switchWait = opt("switchWait"),
		range = 2000, ignoreFriends = true,
	}
	local ctx = { mePos = root and root.Position, meTeam = DH.LP.Team, targets = targetSet() }
	local list = Rage.candidates()
	-- a knocked target is kept for the stomp even though the filter drops knocked players
	local held = Rage.entry and Rage.tstate.id == Rage.entry.id and Rage.entry
	local id, _, entry = Targeting.pick(Rage.tstate, list, now, ctx, cfgPick)
	if not entry and held then
		for _, c in ipairs(list) do
			if c.id == held.id and c.ko and not c.dead and opt("stomp") then entry = c; Rage.tstate.id = c.id end
		end
	end
	Rage.entry = entry
	Rage.player = entry and entry.player or nil
	return entry
end

function Rage.target() return Rage.player end

-- ---- weapons
local function toolValue(tool, name, default)
	local v = tool:FindFirstChild(name)
	return v and tonumber(v.Value) or default
end
local function spareAmmo(tool)
	local data = DH.LP:FindFirstChild("DataFolder")
	local inv = data and data:FindFirstChild("Inventory")
	local held = inv and inv:FindFirstChild(tool.Name)
	return held and tonumber(held.Value) or 0
end
local function isShotgun(tool)
	local n = string.lower(tool.Name)
	return string.find(n, "shotgun", 1, true) ~= nil or string.find(n, "double-barrel", 1, true) ~= nil or string.find(n, "sg]", 1, true) ~= nil
end
function Rage.gunRange(tool) return toolValue(tool, "Range", DH.K.get("RAGE_RANGE")) end -- (the tool's own Range value; the K number when it has none)

local function allGuns()
	local out, character = {}, DH.character()
	local function scan(parent)
		for _, item in ipairs(parent and parent:GetChildren() or {}) do
			if item:IsA("Tool") and item:FindFirstChild("Ammo") and item:FindFirstChild("Handle") then out[#out + 1] = item end
		end
	end
	scan(character); scan(DH.LP:FindFirstChildOfClass("Backpack"))
	return out
end

local function configuredOrder()
	local ok, list = pcall(function() return Config and Config.get("dahood.guns") end)
	return (ok and type(list) == "table") and list or {}
end

---The gun to use now (nil when none has a round and none can be reloaded).
function Rage.pickGun(distance)
	local guns = allGuns()
	if #guns == 0 then return nil end
	local want = string.lower(tostring(opt("weapon") or "auto"))
	if opt("flame") and distance and distance <= DH.K.get("DEF_FLAME") then
		for _, g in ipairs(guns) do if string.find(string.lower(g.Name), "flame", 1, true) and g.Ammo.Value > 0 then return g end end
	end
	if want ~= "auto" and want ~= "" then
		for _, g in ipairs(guns) do if string.find(string.lower(g.Name), want, 1, true) then return g end end
		return nil
	end
	local character = DH.character()
	local held = character and character:FindFirstChildOfClass("Tool")
	if held and held:FindFirstChild("Ammo") and held.Ammo.Value > 0 then return held end
	for _, name in ipairs(configuredOrder()) do
		for _, g in ipairs(guns) do if g.Name == name and (g.Ammo.Value > 0 or spareAmmo(g) > 0) then return g end end
	end
	for _, g in ipairs(guns) do if g.Ammo.Value > 0 then return g end end
	for _, g in ipairs(guns) do if spareAmmo(g) > 0 then return g end end
	return nil
end

local function equip(gun, now)
	local character, humanoid = DH.character(), DH.humanoid()
	if gun.Parent == character then return true end
	if humanoid and now >= Rage.equipAt then
		Rage.equipAt = now + 0.4
		pcall(function() humanoid:EquipTool(gun) end)
	end
	return false
end

local function remoteMain() return S.Rep:FindFirstChild("MainEvent") end

function Rage.reload(gun, now)
	if now < Rage.reloadUntil then return false end
	local remote = remoteMain()
	if not remote or spareAmmo(gun) <= 0 then return false end
	remote:FireServer("Reload", gun)
	Rage.reloadUntil = now + 3
	Rage.reloads += 1
	return true
end

-- ---- what to aim at
---@return table? { pos, part, info, how }, string? why
function Rage.aim(entry, gun)
	local c = entry.character
	local wantHead = opt("part") == "head" or opt("oneTap") == true
	local partName = wantHead and "Head" or "UpperTorso"
	local part = c:FindFirstChild(partName) or c:FindFirstChild("HumanoidRootPart")
	if not part then return nil, "no part" end
	local lead = DH.lag()
	local pos, info, why = DH.Resolver.aimAt(entry.player, partName, lead)
	if pos then return { pos = pos, part = part, info = info, how = "resolver" } end
	if why == "low confidence" then return nil, why end
	local vel = entry.root.AssemblyLinearVelocity
	if vel.Magnitude > DH.K.get("RES_MAX_SPEED") then vel = Vector3.new(0, 0, 0) end
	return { pos = part.Position + vel * lead, part = part, how = "replicated" }
end

---Where the server will see the shot leave from: the glued body, a raknet fake, or the real handle.
function Rage.serverOrigin(handle)
	if DH.Physrep.isAttached() then return DH.Physrep.originFor(handle) end
	local root, server = DH.root(), DH.Fakepos.server
	if server and root and DH.Net.on then return handle.Position + (server.Position - root.Position) end
	return handle.Position
end

---Everything that has to be true before a shot is sent.
function Rage.canFire(entry, gun, aim, now)
	local handle = gun:FindFirstChild("Handle")
	if not handle then return false, "no handle" end
	if now < Rage.nextShot then return false, "cooldown" end
	if now < Rage.reloadUntil then return false, "reloading" end
	if now < Rage.oneTapUntil then return false, "waiting for the hit" end
	local origin = Rage.serverOrigin(handle)
	if not origin then return false, "no origin" end
	local dist = (aim.pos - origin).Magnitude
	if dist > Rage.gunRange(gun) then return false, "out of range" end
	-- arrival: the server counts shots from a new place only after a delay (0.10-0.23 s measured); riding and strikes handle their own
	local void = DH.Void.active()
	-- (the wait follows the ping, capped by RAGE_ARRIVE: a fixed 0.25 s equalled the ring's own hold, so a shot almost never got a window)
	local arrive = math.min(DH.K.get("RAGE_ARRIVE"), math.clamp(DH.ping() + DH.K.get("RAGE_ARRIVE_PAD"), 0.08, 0.4))
	if not void and not DH.Physrep.isAttached() and now - Rage.spotSince < arrive then return false, "arriving" end
	if opt("snipe") and dist > 150 and entry.root.AssemblyLinearVelocity.Magnitude > 2 then return false, "snipe: target is moving" end
	if now - Rage.lastSight.t > 0.1 then
		Rage.lastSight = { t = now, ok = clear(origin, aim.pos, DH.character(), entry.character) }
	end
	if opt("walls") and not Rage.lastSight.ok then return false, "no line" end
	return true
end

function Rage.shoot(gun, entry, aim, now)
	local remote, handle, ammo = remoteMain(), gun:FindFirstChild("Handle"), gun:FindFirstChild("Ammo")
	if not (remote and handle and ammo) then return false end
	if ammo.Value <= 0 then
		if opt("autoReload") then Rage.reload(gun, now) end
		return false
	end
	local cooldown = toolValue(gun, "ShootingCooldown", 0.3)
	Rage.nextShot = now + cooldown + (opt("pipeline") and 0.03 or (DH.ping() * 2 + 0.05))
	-- riding: the origin is the glued body's; otherwise the natural handle position (the shot hook moves it for a raknet fake)
	local origin = DH.Physrep.isAttached() and DH.Physrep.originFor(handle) or handle.Position
	local up = Vector3.new(0, 1, 0)
	if isShotgun(gun) and opt("salvo") then
		local stamp = workspace:GetServerTimeNow()
		Rage.spread += 1
		for pellet = 1, 5 do remote:FireServer("ShootGun", handle, origin, aim.pos, aim.part, up, stamp, Rage.spread, pellet) end
	else
		remote:FireServer("ShootGun", handle, origin, aim.pos, aim.part, up)
	end
	Rage.fired += 1
	if opt("oneTap") then Rage.oneTapUntil = now + 0.5 end
	if aim.info then DH.Resolver.noteShot(entry.player, aim.info) end
	return true
end

-- ---- where it stands
local function patternK()
	local k = {}
	for name, default in pairs(Patterns.DEFAULT_K) do
		local ok, v = pcall(function() return Config and Config.get("dahood.k." .. name) end)
		k[name] = (ok and type(v) == "number") and v or default
	end
	return k
end

---Replace where the ragebot stands. fn(position, unsafe, part) -> CFrame | nil (nil: use the default). Last registered wins.
function Rage.setStrafeOverride(fn) Rage.override = fn end
function Rage.clearStrafeOverride() Rage.override = nil end

---The target's position, for the orbit strafe (the Desync block asks).
function Rage.centre()
	return Rage.entry and Rage.entry.root and Rage.entry.root.Position or nil
end

function Rage.engaged()
	return Rage.on() and not Rage.paused and Rage.autoPaused == nil and Rage.entry ~= nil
end

---The fake-position source: the server body's place for this step (nil: the configured mode, or the real place).
function Rage.stand(real)
	if not Rage.engaged() then return nil end
	local entry = Rage.entry
	local root = entry.root
	if not (root and root.Parent) then return nil end
	local now = os.clock()
	local cf
	if entry.ko and opt("stomp") and not DH.Physrep.isAttached() and not Rage.stompingNow then
		cf = nil
	elseif Rage.stompingNow and not DH.Physrep.isAttached() then
		local spot = DH.Physrep.fallbackSpot(root, Vector3.new(0, DH.K.get("RAGE_STOMP"), 0))
		cf = CFrame.new(spot)
	elseif opt("pattern") ~= "none" and not entry.ko then
		cf = Patterns[opt("pattern")](root.Position, now, patternK(), { vel = root.AssemblyLinearVelocity, look = root.CFrame.LookVector })
	end
	local hook = Rage.override
	if hook then
		local base = (cf or real).Position
		local ok, replaced = pcall(hook, base, DH.Defense and DH.Defense.unsafe() or false, entry.character:FindFirstChild("Head") or root)
		if ok and typeof(replaced) == "CFrame" then cf = replaced elseif not ok then DH.fail("strafeOverride", replaced) end
	end
	if cf then
		local packets = DH.Net.on or DH.Net.ready()
		if packets then cf = DH.Orbit.fit(cf, 1000) end
		if not Rage.spot or (cf.Position - Rage.spot).Magnitude > 12 then Rage.spotSince = now end
		Rage.spot = cf.Position
	else
		Rage.spot = nil
	end
	return cf
end

-- ---- safety
local function autoPauseReason()
	if opt("safety") ~= true then return nil end
	if B and B.DaHood and B.DaHood.on == true then return "BasedHub's ragebot is on" end
	local character = DH.character()
	local ready, why = DH.ready(character)
	if not ready then return "me: " .. tostring(why) end
	local humanoid = DH.humanoid()
	if humanoid and (humanoid.SeatPart ~= nil or humanoid.Sit) then return "seated" end
	local a = DH.Defense and DH.Defense.assessment
	if a and a.top and Rage.player and a.top.id ~= Rage.player.UserId and a.topScore >= 0.6 and a.top.tool ~= "none"
		and (a.top.pos - (DH.root() and DH.root().Position or a.top.pos)).Magnitude <= DH.K.get("DEF_SAFE") and not DH.hasShield(character) then
		return "dangerous: " .. tostring(a.top.name)
	end
	return nil
end

function Rage.pause()
	if Rage.paused then return end
	Rage.resumeTo, Rage.paused = Rage.on(), true
end
function Rage.resume()
	if not Rage.paused then return end
	Rage.paused = false
	if Rage.resumeTo then DH.set("monster.rage.on", true, true) end
	Rage.resumeTo = nil
end
---`set_ragebot(true|false|nil)`: nil toggles.
function Rage.set(state)
	if state == nil then state = not Rage.on() end
	DH.set("monster.rage.on", state == true, true)
	if state ~= true then Rage.stop() end
	return Rage.on()
end

-- ---- the step
local function realBody(entry, now)
	local humanoid, root = DH.humanoid(), DH.root()
	if not (humanoid and root) or DH.Physrep.isAttached() or DH.Void.active() then return end
	local tpos = entry.root.Position
	local dist = (tpos - root.Position).Magnitude
	if opt("chase") then
		humanoid:MoveTo(tpos + entry.root.AssemblyLinearVelocity * 0.25)
	elseif opt("walk") then
		if dist > 15 then humanoid:MoveTo(tpos) else humanoid:Move(Vector3.new(0, 0, 0)) end
	end
	if opt("jump") and dist < 60 and now >= Rage.nextJump then
		Rage.nextJump = now + 1.1
		humanoid.Jump = true
	end
end

local function stompStep(entry, now)
	if not opt("stomp") then return end
	local root = entry.root
	local height = DH.K.get("RAGE_STOMP")
	Rage.stompingNow = true
	if not DH.Physrep.isAttached() then
		local ok = DH.Physrep.attach(root, CFrame.new(0, height, 0))
		if not ok then Rage.stompingNow = true end -- (world spot with the velocity lead takes over in stand())
	end
	if now >= Rage.stompAt and now >= Rage.reloadUntil then
		local remote = remoteMain()
		if remote and (not DH.Physrep.isAttached() or now - DH.Physrep.core.since >= DH.K.get("RAGE_ARRIVE")) then
			remote:FireServer("Stomp")
			Rage.stomps += 1
			Rage.stompAt = now + 0.55
		end
	end
end

function Rage.stop()
	Rage.entry, Rage.player, Rage.spot, Rage.stompingNow = nil, nil, nil, false
	Rage.tstate = {}
	if DH.Physrep then DH.Physrep.detach("ragebot stopped") end
	if DH.Void then DH.Void.cancel("rage-strafe"); DH.Void.forceStyle = nil; DH.Void.setWaiting(false) end
	DH.Fakepos.clearSource("rage")
end

local function step(dt)
	local now = os.clock()
	if not Rage.on() then
		if Rage.entry or Rage.stompingNow then Rage.stop() end
		Rage.autoPaused, Rage.why = nil, "off"
		return
	end
	Rage.autoPaused = autoPauseReason()
	if Rage.paused or Rage.autoPaused then
		Rage.why = "paused: " .. (Rage.paused and "by a plugin" or tostring(Rage.autoPaused))
		DH.Fakepos.clearSource("rage")
		if Rage.entry then Rage.entry, Rage.player = nil, nil end
		if DH.Physrep.isAttached() then DH.Physrep.detach("ragebot paused") end
		return
	end
	local entry = Rage.pick(now)
	DH.Fakepos.setSource("rage", function(real) return Rage.stand(real) end)
	if not entry then
		Rage.why = "no target"
		Rage.stompingNow = false
		if DH.Physrep.isAttached() then DH.Physrep.detach("no target") end
		DH.Void.setWaiting(true)
		DH.Void.cancel("rage-strafe"); DH.Void.forceStyle = nil
		-- smart reload while nobody is in sight
		if opt("smartReload") then
			local gun = Rage.pickGun(nil)
			local held = DH.character() and DH.character():FindFirstChildOfClass("Tool")
			local ammo = held and held:FindFirstChild("Ammo")
			if held and ammo and toolValue(held, "MaxAmmo", ammo.Value) > ammo.Value then Rage.reload(held, now) end
			if gun then equip(gun, now) end
		end
		return
	end
	DH.Void.setWaiting(false)
	local dist = (entry.root.Position - (DH.root() and DH.root().Position or entry.root.Position)).Magnitude

	-- the target went down
	if entry.ko and not Rage.targetWasKO then Rage.kills += 1; DH.Void.targetDied() end
	Rage.targetWasKO = entry.ko
	if entry.dead or not entry.ko then Rage.stompingNow = false; if DH.Physrep.isAttached() and not entry.ko then DH.Physrep.detach("target up") end end

	-- the strafe is the void with the orbit for its place; the strike inside it brings the body back for a shot
	if opt("strafe") and not entry.ko then
		DH.Void.forceStyle = opt("strafeStyle") == "thunder" and "orbit-thunder" or "orbit"
		DH.Void.request("rage-strafe", 0.5)
	else
		DH.Void.cancel("rage-strafe"); DH.Void.forceStyle = nil
	end

	if entry.ko then
		Rage.why = opt("stomp") and "target down: stomping" or "target down"
		stompStep(entry, now)
		return
	end
	realBody(entry, now)
	local gun = Rage.pickGun(dist)
	if not gun then Rage.why = "no gun with a round or spare ammo"; return end
	if not equip(gun, now) then Rage.why = "equipping " .. gun.Name; return end
	local aim, aimWhy = Rage.aim(entry, gun)
	if not aim then Rage.why = "aim: " .. tostring(aimWhy); return end
	local ok, why = Rage.canFire(entry, gun, aim, now)
	Rage.why = ok and "firing" or tostring(why)
	if ok then Rage.shoot(gun, entry, aim, now) end
	if opt("autoReload") and gun.Ammo.Value <= DH.K.get("RAGE_RELOAD_AT") then Rage.reload(gun, now) end
end

function Rage.init()
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("rage.step", step)), "rage.step")
end
function Rage.enable() DH.set("monster.rage.on", true, true) end
function Rage.disable() DH.set("monster.rage.on", false, true); Rage.stop() end
function Rage.status()
	local entry = Rage.entry
	return {
		on = Rage.on(), paused = Rage.paused, autoPaused = Rage.autoPaused, target = Rage.player and Rage.player.Name or nil,
		ko = entry and entry.ko or nil, fired = Rage.fired, stomps = Rage.stomps, reloads = Rage.reloads, kills = Rage.kills,
		riding = DH.Physrep and DH.Physrep.isAttached() or false, override = Rage.override ~= nil, why = Rage.why,
	}
end
DH.register("ragebot", Rage)
