-- ---- api: the same entry points a plugin written for the Unnamed Enhancements ragebot calls (set_ragebot, get_target, set_desync_cframe ...),
-- so such plugins run against MONSTER unchanged. Both call styles work: api.f(x) and api:f(x). Identity (CFrame.new()) means off.
local API = {}
DH.API = API

local function method(fn)
	return function(first, ...)
		if first == API then return fn(...) end
		return fn(first, ...)
	end
end

function DH.notify(text, seconds)
	local ok = pcall(function() Window.toast({ title = "MONSTER", text = tostring(text), icon = "skull", time = seconds or 3 }) end)
	if not ok then DH.warn("notify", tostring(text), 1) end
end

API.set_ragebot = method(function(state) return DH.Rage.set(state) end)

---kind: "ragebot" (the current target), "silent" or "aimbot" (the player nearest the mouse who is not a friend).
API.get_target = method(function(kind)
	if kind == "ragebot" or kind == nil then return DH.Rage.target() end
	local best, bestDist
	for _, entry in ipairs(DH.Rage.candidates()) do
		if not entry.friend and not entry.ko and entry.visible and (not bestDist or entry.screenDist < bestDist) then best, bestDist = entry.player, entry.screenDist end
	end
	return best
end)

API.get_character_cache = method(function(player)
	local character = typeof(player) == "Instance" and player.Character
	if not character then return nil end
	local cache = { Character = character, Humanoid = character:FindFirstChildOfClass("Humanoid") }
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") then cache[part.Name] = part end
	end
	return cache
end)

API.get_status_cache = method(function(player)
	local character = typeof(player) == "Instance" and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	return {
		ko = DH.knocked(character), dead = humanoid.Health <= 0, armor = DH.armor(character), health = humanoid.Health, maxHealth = humanoid.MaxHealth,
		shield = DH.hasShield(character), tool = (character:FindFirstChildOfClass("Tool") or {}).Name, state = humanoid:GetState().Name,
		sitting = humanoid.SeatPart ~= nil or humanoid.Sit,
	}
end)

---Both put the server body at `cframe` (it is the same idea here); the identity CFrame withdraws it.
API.set_server_cframe = method(function(cframe) DH.Fakepos.setSource("api", cframe) end)
API.set_desync_cframe = method(function(cframe) DH.Fakepos.setSource("api", cframe) end)

API.teleport = method(function(cframe)
	local root = DH.root()
	if root and typeof(cframe) == "CFrame" then root.CFrame = cframe end
end)
API.notify = method(function(text, seconds) DH.notify(text, seconds) end)
API.on_event = method(function(name, fn) return DH.on(name, fn) end)
API.PauseRageBot = method(function() DH.Rage.pause() end)
API.ResumeRageBot = method(function() DH.Rage.resume() end)
API.ragebot_strafe_override = method(function(fn) if fn == nil then DH.Rage.clearStrafeOverride() else DH.Rage.setStrafeOverride(fn) end end)
API.setStrafeOverride = API.ragebot_strafe_override

-- the UI keys a plugin reads
local OPTION = {
	ragebot_active = "monster.rage.on", ragebot_keybind = "monster.rage.key", ragebot_strafe = "monster.rage.strafe", ragebot_chase = "monster.rage.chase",
	ragebot_walk_to_target = "monster.rage.walk", ragebot_jump_at_target = "monster.rage.jump", ragebot_targets = "monster.rage.targets",
	ragebot_weapon = "monster.rage.weapon", ragebot_flame = "monster.rage.flame", ragebot_stomp_offset = "monster.k.RAGE_STOMP",
	character_prot_void = "monster.void.protect",
}
API.get_option = method(function(key) local id = OPTION[key]; return id and DH.get(id) or nil end)
API.set_option = method(function(key, value) local id = OPTION[key]; if id then DH.set(id, value, true); return true end return false end)

API.status = method(function() return DH.status() end)
API.panic = method(function() DH.panic("api") end)
API.probe = method(function(options) return DH.Probe.run(options) end)
API.version = DH.version

function API.install()
	genv.MONSTER_API = API
	genv.MONSTER_DH = DH
end
function API.remove()
	if genv.MONSTER_API == API then genv.MONSTER_API = nil end
	if genv.MONSTER_DH == DH then genv.MONSTER_DH = nil end
end
