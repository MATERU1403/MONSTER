-- ---- defense: anti-bag, anti-flame, anti-bait, built on the void. Every decision is in pure/threat.lua (tested without a game);
-- this module only describes the world to it, ten times a second, and asks the void for what it decides.
local Threat = DH.F.threat()
local Defense = { assessment = nil, per = {}, lastTrigger = -math.huge, triggers = 0, last = 0, reasons = {} }
DH.Defense = Defense

DH.define("monster.defense.on", { kind = "toggle", default = false, label = "Defense", desc = "Void when a threat is near, as set below.", group = "defense" })
DH.define("monster.defense.antiBag", { kind = "toggle", default = true, label = "Anti bag", desc = "Knocked, with someone about to pick you up: go to the void.", group = "defense" })
DH.define("monster.defense.antiFlame", { kind = "toggle", default = true, label = "Anti flame", desc = "A flamethrower close or closing: go to the void.", group = "defense" })
DH.define("monster.defense.antiBait", { kind = "toggle", default = true, label = "Anti bait", desc = "An armed player waiting by your way back: stay hidden.", group = "defense" })

local function cfg()
	local K = DH.K.get
	return { safeDistance = K("DEF_SAFE"), gunRange = K("DEF_GUN"), flameRange = K("DEF_FLAME"), bagRange = K("DEF_BAG"), teleportJump = K("DEF_TELE") }
end

---What a held tool means for a fight.
function Defense.classify(tool)
	if not tool then return "none" end
	local name = string.lower(tool.Name)
	if string.find(name, "flame", 1, true) then return "flame" end
	if tool:FindFirstChild("Ammo") and tool:FindFirstChild("Handle") then return "gun" end
	if string.find(name, "combat", 1, true) or string.find(name, "knife", 1, true) or string.find(name, "bat", 1, true) or string.find(name, "sword", 1, true)
		or string.find(name, "katana", 1, true) or string.find(name, "machete", 1, true) or string.find(name, "pitchfork", 1, true) or string.find(name, "shovel", 1, true) then
		return "melee"
	end
	return "none"
end

local function isFriend(player)
	local roster = B and B.Roster
	return roster ~= nil and roster.friends ~= nil and roster.friends[player.UserId] == true
end

local function describe()
	local now = os.clock()
	local rootMe = DH.root()
	if not rootMe then return nil end
	local character = DH.character()
	local humanoid = DH.humanoid()
	local me = {
		pos = rootMe.Position, ko = DH.knocked(character), health = humanoid and humanoid.Health or 100,
		armor = DH.armor(character), protected = DH.hasShield(character),
	}
	local players = {}
	for _, player in ipairs(S.Players:GetPlayers()) do
		if player ~= DH.LP then
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local humanoidOther = c and c:FindFirstChildOfClass("Humanoid")
			if root and humanoidOther and humanoidOther.Health > 0 then
				local per = Defense.per[player] or { pos = root.Position, t = now, stillSince = now }
				Defense.per[player] = per
				local dt = now - per.t
				local moved = (root.Position - per.pos).Magnitude
				local teleported = Threat.teleport(per.pos, root.Position, dt, cfg())
				if teleported then per.teleAt = now end
				if moved > 0.5 then per.stillSince = now end
				per.pos, per.t = root.Position, now
				players[#players + 1] = {
					id = player.UserId, name = player.Name, pos = root.Position, vel = root.AssemblyLinearVelocity,
					ko = DH.knocked(c), friend = isFriend(player), protected = DH.hasShield(c),
					tool = Defense.classify(c:FindFirstChildOfClass("Tool")),
					still = now - per.stillSince, teleported = per.teleAt ~= nil and now - per.teleAt < 2,
				}
			end
		end
	end
	return me, players
end

---The picture, at most ten times a second.
function Defense.assess(force)
	local now = os.clock()
	if Defense.assessment and not force and now - Defense.last < 0.1 then return Defense.assessment end
	Defense.last = now
	local me, players = describe()
	if not me then Defense.assessment = nil; return nil end
	local returnPos = DH.Fakepos and DH.Fakepos.real and DH.Fakepos.real.Position or me.pos
	Defense.assessment = Threat.assess(me, players, cfg(), returnPos)
	Defense.me, Defense.players = me, players
	return Defense.assessment
end

local function wanted()
	return DH.get("monster.defense.on") == true or DH.get("monster.void.protect") == true
		or (DH.Void ~= nil and DH.Void.state.wanted == true) or (DH.Rage ~= nil and DH.Rage.on())
end

---How much one player threatens me right now (0..1), from the last picture.
function Defense.threatOf(player)
	local me = Defense.me
	if not me then return 0 end
	for _, other in ipairs(Defense.players or {}) do
		if other.id == player.UserId then return math.min(1, Threat.score(me, other, cfg())) end
	end
	return 0
end

function Defense.threatNear()
	if not wanted() then return false end
	local a = Defense.assess()
	return a ~= nil and a.threatNear == true
end
function Defense.unsafe()
	local a = Defense.assessment or Defense.assess()
	return a ~= nil and a.unsafe == true
end
---True for a moment after the defense asked for the void (physrep must be let go, the ride is outranked).
function Defense.active() return os.clock() - Defense.lastTrigger < 1.6 end

local function trigger(source, reason)
	Defense.lastTrigger = os.clock()
	Defense.triggers += 1
	Defense.reasons[source] = reason
	if DH.Physrep then DH.Physrep.detach("defense void") end
	if DH.Void then DH.Void.request("defense:" .. source, 1.5) end
end

function Defense.init()
	local acc = 0
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("defense.step", function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		if not wanted() then return end
		local a = Defense.assess(true)
		if not a then return end
		if DH.get("monster.defense.on") then
			if a.antiBag and DH.get("monster.defense.antiBag") then trigger("bag", a.reasons[1]) end
			if a.antiFlame and DH.get("monster.defense.antiFlame") then trigger("flame", a.reasons[#a.reasons]) end
			if a.camper and DH.get("monster.defense.antiBait") and DH.Void and DH.Void.state.voided then trigger("camper", "camper") end
		end
		if DH.get("monster.void.protect") and a.threatNear then trigger("protect", "threat near") end
	end)), "defense.step")
	DH.janitor:add(S.Players.PlayerRemoving:Connect(function(player) Defense.per[player] = nil end), "defense.leave")
end
function Defense.enable() end
function Defense.disable()
	Defense.assessment = nil
	Defense.lastTrigger = -math.huge
	if DH.Void then for _, source in ipairs({ "bag", "flame", "camper", "protect" }) do DH.Void.cancel("defense:" .. source) end end
end
function Defense.status()
	local a = Defense.assessment
	return {
		on = DH.get("monster.defense.on"), triggers = Defense.triggers, active = Defense.active(),
		threatNear = a and a.threatNear or false, unsafe = a and a.unsafe or false, top = a and a.top and a.top.name or nil,
		topScore = a and math.floor(a.topScore * 100) / 100 or 0, reasons = a and a.reasons or {},
	}
end
DH.register("defense", Defense)
