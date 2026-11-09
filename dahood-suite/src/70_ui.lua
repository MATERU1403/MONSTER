-- ---- ui: keybinds (Hold / Toggle / Always), the panic key, tabs, and the status panel. The values live in BasedHub's Config,
-- so every setting is saved with the profile and a missing, extra or odd value is tolerated (see pure/cfgstore.lua).
local UI = {}
DH.UI = UI

DH.define("monster.panic.key", { kind = "keybind", default = "End", label = "Panic key", desc = "Stops everything, restores the real position on both channels, takes the hooks off.", group = "suite" })

-- ---- keys
do
	local binds = {}
	---@param name string label for the toast
	---@param keyId string config id of the key  @param modeId string? config id of Hold/Toggle/Always
	---@param onState fun(on: boolean)
	function UI.bind(name, keyId, modeId, onState)
		local bind = { name = name, keyId = keyId, modeId = modeId, onState = onState, state = false, always = false }
		binds[#binds + 1] = bind
		return bind
	end
	local function set(bind, on, quiet)
		if bind.state == on then return end
		bind.state = on
		pcall(bind.onState, on)
		if not quiet then DH.notify(bind.name .. ": " .. (on and "on" or "off"), 2) end
	end
	local function matches(input, key)
		if not key then return false end
		if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then return input.KeyCode == key end
		return input.UserInputType == key
	end
	function UI.startKeys()
		DH.janitor:add(S.Input.InputBegan:Connect(DH.safe("ui.keydown", function(input)
			if S.Input:GetFocusedTextBox() then return end
			for _, bind in ipairs(binds) do
				local mode = bind.modeId and DH.get(bind.modeId) or "Toggle"
				if mode ~= "Always" and matches(input, DH.keyOf(DH.get(bind.keyId))) then
					if mode == "Hold" then set(bind, true) else set(bind, not bind.state) end
				end
			end
		end)), "ui.keydown")
		DH.janitor:add(S.Input.InputEnded:Connect(DH.safe("ui.keyup", function(input)
			for _, bind in ipairs(binds) do
				local mode = bind.modeId and DH.get(bind.modeId) or "Toggle"
				if mode == "Hold" and matches(input, DH.keyOf(DH.get(bind.keyId))) then set(bind, false) end
			end
		end)), "ui.keyup")
		local acc = 0
		DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("ui.always", function(dt)
			acc += dt
			if acc < 0.5 then return end
			acc = 0
			for _, bind in ipairs(binds) do
				local mode = bind.modeId and DH.get(bind.modeId) or "Toggle"
				if mode == "Always" and not bind.always then bind.always = true; set(bind, true)
				elseif mode ~= "Always" and bind.always then bind.always = false; set(bind, false) end
			end
		end)), "ui.always")
	end
	-- the panic key is not a mode bind: one press
	DH.janitor:add(S.Input.InputBegan:Connect(DH.safe("ui.panic", function(input)
		if S.Input:GetFocusedTextBox() then return end
		if matches(input, DH.keyOf(DH.get("monster.panic.key"))) then DH.panic("key") end
	end)), "ui.panic")
end

-- ---- panic and stop
function DH.panic(reason)
	if DH.panicked then return end
	DH.panicked = true
	DH.warn("panic", tostring(reason), 0.1)
	DH.fire("panic", reason)
	local root = DH.root()
	pcall(function() DH.Fakepos.panic() end)
	pcall(function() DH.set("monster.fake", false, true); DH.set("monster.desync", false, true) end)
	pcall(function() DH.Physrep.setPanic(true) end)
	pcall(function() DH.Rage.disable() end)
	pcall(function() DH.Void.disable() end)
	pcall(function() DH.Defense.disable() end)
	-- both channels back to the real place: the server body (raknet) and the desync/body-swap one
	pcall(function() DH.Net.release(root and root.CFrame) end)
	pcall(function() if DH.desyncStop then DH.desyncStop() end end)
	pcall(function() DH.Net.disable() end)
	pcall(function() DH.Probe.disable() end)
	DH.janitor:clean()
	pcall(function() DH.API.remove() end)
	DH.notify("PANIC: everything is off and unhooked (" .. tostring(reason) .. "). Reload MONSTER to use it again.", 6)
end

---Unload: every module off, every connection and hook released.
function DH.stop()
	if DH.stopped then return end
	DH.stopped = true
	DH.fire("unload")
	DH.disableAll("unload")
	pcall(function() if DH.desyncStop then DH.desyncStop() end end)
	DH.janitor:clean()
	DH.save()
	pcall(function() DH.API.remove() end)
end

-- ---- tabs
local function control(section, id)
	local def = DH.SCHEMA[id]
	if not def then return end
	local label, desc = def.label or id, def.desc
	if def.kind == "toggle" then section:toggle({ id = id, label = label, desc = desc, default = def.default })
	elseif def.kind == "slider" then section:slider({ id = id, label = label, desc = desc, min = def.min, max = def.max, step = def.step, default = def.default, suffix = def.suffix })
	elseif def.kind == "dropdown" then section:dropdown({ id = id, label = label, desc = desc, options = def.options, default = def.default })
	elseif def.kind == "keybind" then section:keybind({ id = id, label = label, desc = desc, default = def.default })
	elseif def.kind == "input" then section:input({ id = id, label = label, desc = desc, default = def.default })
	end
end
UI.control = control

local function controls(section, ids) for _, id in ipairs(ids) do control(section, id) end end

---Called from the Desync tab's own build: the new fake-position modes, the void, and physrep, beside the older controls.
function UI.extras(page)
	local fp = page:section({ title = "Fake position modes", icon = "map-pin", desc = "Pick Static, Follow, Jitter, Anchor or Orbit strafe under Where." })
	controls(fp, { "monster.fakepos.offX", "monster.fakepos.offY", "monster.fakepos.offZ", "monster.fakepos.radius", "monster.fakepos.rate",
		"monster.fakepos.anchorKey", "monster.fakepos.resetOnKO", "monster.fakepos.backend", "monster.fakepos.orbitAround", "monster.fakepos.moveReal" })
	local void = page:section({ title = "Void", icon = "orbit", desc = "Where the body goes, when, and for how long." })
	controls(void, { "monster.void.position", "monster.void.protect", "monster.void.whenDead", "monster.void.whileWaiting", "monster.void.respawnRamp", "monster.void.key", "monster.void.keyMode" })
	local ride = page:section({ title = "Ride the target", icon = "shuffle", desc = "PhysicsRepRootPart: the stomp spot moves with the target." })
	controls(ride, { "monster.physrep.on" })
end

local function addPage(id, title, icon, build)
	task.spawn(function()
		local giveUp = os.clock() + 60
		while not (Window.pages and Window.pages["dahood.ragebot"]) and os.clock() < giveUp and GUI.Parent do task.wait(0.25) end
		local rage = Window.pages and Window.pages["dahood.ragebot"]
		if not rage or DH.stopped then return end
		local last = rage.order
		for _, page in ipairs(Window.order) do
			if page.group == rage.group and page.order > last then last = page.order end
		end
		Window.page({ id = id, title = title, icon = icon, group = rage.group, order = last + 1, eyebrow = rage.eyebrow, build = build })
		UI.pages = UI.pages or {}
		UI.pages[#UI.pages + 1] = id
	end)
end

local STATUS = {}
local function statusText()
	local fp, net, void, rage, res, def, phys = DH.Fakepos.status(), DH.Net.status(), DH.Void.status(), DH.Rage.status(), DH.Resolver.status(), DH.Defense.status(), DH.Physrep.status()
	return {
		string.format("Fake position: %s via %s%s  owner %s%s", tostring(fp.mode), tostring(fp.backend), fp.degraded and " (DEGRADED)" or "", tostring(fp.owner), fp.suspended and " (suspended)" or ""),
		string.format("Raknet: %s  sent %d  blocked %d  failed %d  %.1f/s%s", net.available and "ready" or ("off: " .. tostring(net.reason)), net.sent, net.blocked, net.failed, net.rate, net.denied and "  DENIED" or ""),
		string.format("Void: %s%s  Defense: threat %s", void.phase, void.ramp and (" ramp " .. void.ramp) or "", def.threatNear and (tostring(def.top) .. " " .. def.topScore) or "none"),
		string.format("Target: %s  fired %d  stomps %d  kills %d%s", rage.target or "none", rage.fired, rage.stomps, rage.kills, rage.autoPaused and ("  PAUSED: " .. rage.autoPaused) or ""),
		string.format("Resolver: %s %s  shots %d (hit %d)", res.method or "-", res.confidence and string.format("%.2f", res.confidence) or "-", res.shots, res.confirmed),
		string.format("Ride: %s  Last error: %s", phys.attached and "on" or (phys.why or "off"), tostring(DH.lastError or "none")),
	}
end

function UI.init()
	UI.bind("Ragebot", "monster.rage.key", "monster.rage.keyMode", function(on) DH.Rage.set(on) end)
	UI.bind("Void", "monster.void.key", "monster.void.keyMode", function(on) DH.Void.keyState(on) end)
	UI.startKeys()
	-- the anchor key is one press
	DH.janitor:add(S.Input.InputBegan:Connect(DH.safe("ui.anchor", function(input)
		if S.Input:GetFocusedTextBox() then return end
		local key = DH.keyOf(DH.get("monster.fakepos.anchorKey"))
		if key and ((typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode and input.KeyCode == key) or input.UserInputType == key) then
			DH.notify("Anchor: " .. (DH.Fakepos.toggleAnchor() and "held here" or "let go"), 2)
		end
	end)), "ui.anchor")

	addPage("dahood.mrage", "Rage", "skull", function(page)
		local a = page:section({ title = "Ragebot", icon = "skull", desc = "MONSTER's own fighter: shoots from the fake position." })
		controls(a, { "monster.rage.on", "monster.rage.key", "monster.rage.keyMode", "monster.rage.safety" })
		local t = page:section({ title = "Targets", icon = "search", desc = "Who it picks, and who it never does." })
		controls(t, { "monster.rage.targetMode", "monster.rage.targets", "monster.rage.fov", "monster.rage.walls", "monster.rage.teamCheck", "monster.rage.switchWait" })
		local f = page:section({ title = "Firing", icon = "settings-2", desc = "The gun, and how it is fired." })
		controls(f, { "monster.rage.part", "monster.rage.weapon", "monster.rage.flame", "monster.rage.salvo", "monster.rage.pipeline", "monster.rage.oneTap", "monster.rage.snipe", "monster.rage.autoReload", "monster.rage.smartReload" })
		local m = page:section({ title = "Movement", icon = "orbit", desc = "Where it stands and how your own body moves." })
		controls(m, { "monster.rage.strafe", "monster.rage.strafeStyle", "monster.rage.pattern", "monster.rage.chase", "monster.rage.walk", "monster.rage.jump", "monster.rage.stomp" })
	end)
	addPage("dahood.mresolver", "Resolver", "radio", function(page)
		local a = page:section({ title = "Resolver", icon = "radio", desc = "Finds the real body of a player who hides." })
		controls(a, { "monster.resolver.on", "monster.resolver.skipLow", "monster.resolver.learn", "monster.resolver.overlay" })
		local k = page:section({ title = "Tuning", icon = "settings-2", desc = "The numbers the estimators use." })
		for _, def in ipairs(DH.KDEFS) do if def[6] == "resolver" then control(k, DH.K.id(def[1])) end end
	end)
	addPage("dahood.mdefense", "Defense", "shield", function(page)
		local a = page:section({ title = "Defense", icon = "shield", desc = "Anti bag, anti flame, anti bait: all by going to the void." })
		controls(a, { "monster.defense.on", "monster.defense.antiBag", "monster.defense.antiFlame", "monster.defense.antiBait" })
		local k = page:section({ title = "Tuning", icon = "settings-2", desc = "Distances and holds." })
		for _, def in ipairs(DH.KDEFS) do if def[6] == "defense" or def[6] == "void" then control(k, DH.K.id(def[1])) end end
	end)
	addPage("dahood.msuite", "Suite", "settings-2", function(page)
		local s = page:section({ title = "Status", icon = "radio", desc = "What the suite is doing now." })
		STATUS.lines = {}
		for i = 1, 6 do STATUS.lines[i] = s:label("") end
		local acc = 0
		STATUS.conn = DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("ui.status", function(dt)
			acc += dt
			if acc < 0.25 then return end
			acc = 0
			if not STATUS.lines[1].frame.Parent then return end
			for i, text in ipairs(statusText()) do STATUS.lines[i].set(text) end
		end)), "ui.status")
		local act = page:section({ title = "Actions", icon = "shield", desc = "Panic stops and unhooks everything." })
		act:button({ label = "Panic", text = "Stop all", style = "danger", desc = "Everything off, real position restored, hooks removed. Reload to use it again.", run = function() DH.panic("button") end })
		act:button({ label = "Probe", text = "Run", desc = "What this executor can do: written to monster_probe.json.", run = function()
			DH.Probe.run({ done = function(r) DH.notify("Probe done: raknet " .. tostring(r.scan.raknet.present) .. ", receive hooks " .. tostring(#r.scan.receive)) end })
		end })
		controls(act, { "monster.panic.key" })
		local groups, order = {}, {}
		for _, def in ipairs(DH.KDEFS) do
			if def[6] ~= "resolver" and def[6] ~= "defense" and def[6] ~= "void" then
				if not groups[def[6]] then groups[def[6]] = {}; order[#order + 1] = def[6] end
				table.insert(groups[def[6]], def[1])
			end
		end
		for _, name in ipairs(order) do
			local sec = page:section({ title = "Tuning: " .. name, icon = "settings-2", desc = "Numbers from measurement; change with care." })
			for _, k in ipairs(groups[name]) do control(sec, DH.K.id(k)) end
		end
	end)
end
function UI.enable() end
function UI.disable()
	for _, id in ipairs(UI.pages or {}) do pcall(function() if Window.pages and Window.pages[id] then Window.removePage(id) end end) end
	UI.pages = {}
end
function UI.status() return { pages = UI.pages and #UI.pages or 0 } end
DH.register("ui", UI)
