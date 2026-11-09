-- ---- resolver: where a player's real body is now, with a confidence (estimators and the vote: pure/estimators.lua).
-- Volt has no receive hook, so the history is read from the engine's replicated bodies (Net.onIncoming), a sample a frame.
local Est = DH.F.estimators(DH.ENV)
local Resolver = { per = {}, pending = {}, shots = 0, confirmed = 0, missed = 0, lastCfgAt = -1, cfg_ = nil }
DH.Resolver = Resolver

DH.define("monster.resolver.on", { kind = "toggle", default = true, label = "Resolver", desc = "Aim at where a hiding body really is, not where it shows.", group = "resolver" })
DH.define("monster.resolver.skipLow", { kind = "toggle", default = true, label = "Skip unsure shots", desc = "Below the minimum confidence: no shot. Off: shoot anyway.", group = "resolver" })
DH.define("monster.resolver.learn", { kind = "toggle", default = true, label = "Learn from shots", desc = "A guess that gets hits counts more for that player (this session only).", group = "resolver" })
DH.define("monster.resolver.overlay", { kind = "toggle", default = false, label = "Show every guess", desc = "A colour per estimator on the target; the winner in green.", group = "resolver" })

local COLORS = {
	raw = Color3.fromRGB(235, 235, 235), parts = Color3.fromRGB(70, 220, 255), pattern = Color3.fromRGB(255, 90, 220),
	cues = Color3.fromRGB(255, 225, 70), deadreckon = Color3.fromRGB(255, 150, 50), result = Color3.fromRGB(60, 255, 110),
}

local function cfg()
	local now = os.clock()
	if Resolver.cfg_ and now - Resolver.lastCfgAt < 1 then return Resolver.cfg_ end
	local K = DH.K.get
	Resolver.cfg_ = {
		windowSeconds = K("RES_WINDOW"), maxJump = K("RES_MAX_JUMP"), maxSpeed = K("RES_MAX_SPEED"), agreeSigma = K("RES_SIGMA"), minConfidence = K("RES_MIN_CONF"),
	}
	Resolver.lastCfgAt = now
	return Resolver.cfg_
end

local function record(player)
	local rec = Resolver.per[player]
	if not rec then
		rec = { history = Est.history(DH.K.get("RES_WINDOW")), learner = Est.learner(), memory = {}, cache = nil }
		Resolver.per[player] = rec
	end
	return rec
end

local function onSample(player, sample)
	local rec = record(player)
	rec.history.seconds = DH.K.get("RES_WINDOW")
	local previous = rec.history:last()
	rec.history:push(sample)
	if Est.gate(sample, previous, cfg()) then rec.memory.sample = sample end
	rec.cache = nil
end

---@param player Player
---@return table? { pos, cf, confidence, method, low, all }
function Resolver.get(player)
	local rec = Resolver.per[player]
	if not rec then return nil end
	local list = rec.history:list()
	if #list == 0 then return nil end
	local now = os.clock()
	if rec.cache and now - rec.cacheT < 0.004 then return rec.cache end
	local r = Est.estimate(list, now, cfg(), rec.learner.weights, rec.memory)
	r.low = r.pos == nil or r.confidence < cfg().minConfidence
	if r.pos then
		local look = list[#list].look or Vector3.new(0, 0, -1)
		local flat = Vector3.new(look.X, 0, look.Z)
		r.cf = flat.Magnitude > 0.01 and CFrame.lookAt(r.pos, r.pos + flat.Unit) or CFrame.new(r.pos)
	end
	rec.cache, rec.cacheT = r, now
	return r
end

local DEFAULT_OFFSET = { Head = Vector3.new(0, 1.6, 0), UpperTorso = Vector3.new(0, 0.6, 0), LowerTorso = Vector3.new(0, -0.3, 0), HumanoidRootPart = Vector3.new(0, 0, 0) }
---Where to aim for `partName`: the resolver's body place plus the part's offset from the root, led by `lead` seconds.
---@return Vector3?, table? info (the resolver result), string? why
function Resolver.aimAt(player, partName, lead)
	if DH.get("monster.resolver.on") ~= true then return nil, nil, "off" end
	local r = Resolver.get(player)
	if not r or not r.pos then return nil, r, "no estimate" end
	if r.low and DH.get("monster.resolver.skipLow") then return nil, r, "low confidence" end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = character and character:FindFirstChild(partName)
	local offset = DEFAULT_OFFSET[partName] or Vector3.new(0, 0, 0)
	if root and part then
		local seen = part.Position - root.Position
		if seen.Magnitude < 8 then offset = seen end
	end
	local list = Resolver.per[player].history:list()
	local last = list[#list]
	local vel = (last and last.vel and last.vel.Magnitude < DH.K.get("RES_MAX_SPEED")) and last.vel or Vector3.new(0, 0, 0)
	return r.pos + offset + vel * (lead or 0), r
end

---A shot was sent at a guess: watch the target for damage and nudge that method's weight.
function Resolver.noteShot(player, result)
	if DH.get("monster.resolver.learn") ~= true or not result then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	Resolver.shots += 1
	Resolver.pending[#Resolver.pending + 1] = { player = player, method = result.method, life = humanoid.Health + DH.armor(character), t = os.clock() }
end

local function judge()
	local now, window = os.clock(), DH.K.get("RES_WATCH")
	for i = #Resolver.pending, 1, -1 do
		local p = Resolver.pending[i]
		if now - p.t >= window then
			table.remove(Resolver.pending, i)
			local character = p.player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rec = Resolver.per[p.player]
			if humanoid and rec then
				local hit = humanoid.Health + DH.armor(character) < p.life - 0.5
				rec.learner:reward(p.method, hit)
				if hit then Resolver.confirmed += 1 else Resolver.missed += 1 end
			end
		end
	end
end

-- ---- overlay: one mark per estimator on the target, the winner in green
local marks = {}
local function mark(key)
	local m = marks[key]
	if m then return m end
	local ok, square = pcall(function() return Drawing.new("Square") end)
	local okText, text = pcall(function() return Drawing.new("Text") end)
	if not (ok and okText) then return nil end
	square.Filled, square.Thickness, square.Size, square.Color, square.Visible = false, 1.5, Vector2.new(10, 10), COLORS[key] or COLORS.result, false
	text.Size, text.Color, text.Outline, text.Center, text.Visible = 12, COLORS[key] or COLORS.result, true, false, false
	DH.janitor:add(function() pcall(function() square:Remove() end); pcall(function() text:Remove() end) end, "resolver.mark")
	m = { square = square, text = text }
	marks[key] = m
	return m
end
local function hideMarks() for _, m in pairs(marks) do m.square.Visible = false; m.text.Visible = false end end

local function draw()
	if DH.get("monster.resolver.overlay") ~= true then if next(marks) then hideMarks() end return end
	local target = DH.Rage and DH.Rage.target and DH.Rage.target() or nil
	local r = target and Resolver.get(target)
	local camera = workspace.CurrentCamera
	if not (r and camera) then hideMarks(); return end
	local shown = {}
	local function put(key, pos, label)
		local m = mark(key)
		if not m then return end
		local point, onScreen = camera:WorldToViewportPoint(pos)
		m.square.Visible, m.text.Visible = onScreen, onScreen
		if onScreen then
			m.square.Position = Vector2.new(point.X - 5, point.Y - 5)
			m.text.Position = Vector2.new(point.X + 8, point.Y - 6)
			m.text.Text = label
		end
		shown[key] = true
	end
	for _, e in ipairs(r.all or {}) do
		if e and e.pos and e.confidence and e.confidence > 0 then put(e.method, e.pos, string.format("%s %.2f", e.method, e.confidence)) end
	end
	if r.pos then put("result", r.pos, string.format("= %s %.2f", r.method, r.confidence)) end
	for key, m in pairs(marks) do if not shown[key] then m.square.Visible, m.text.Visible = false, false end end
end

function Resolver.init()
	Resolver.conn = DH.Net.onIncoming(DH.safe("resolver.sample", onSample))
	DH.janitor:add(Resolver.conn, "resolver.incoming")
	local acc = 0
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("resolver.step", function(dt)
		acc += dt
		for _, rec in pairs(Resolver.per) do rec.learner:decay(dt) end
		if acc < 0.1 then return end
		acc = 0
		judge()
	end)), "resolver.step")
	DH.janitor:add(S.Run.PreRender:Connect(DH.safe("resolver.draw", draw)), "resolver.draw")
	DH.janitor:add(S.Players.PlayerRemoving:Connect(function(player) Resolver.per[player] = nil end), "resolver.leave")
end
function Resolver.enable() end
function Resolver.disable() hideMarks(); Resolver.pending = {} end
function Resolver.status()
	local target = DH.Rage and DH.Rage.target and DH.Rage.target() or nil
	local r = target and Resolver.get(target)
	local count = 0
	for _ in pairs(Resolver.per) do count += 1 end
	return {
		on = DH.get("monster.resolver.on"), tracked = count, target = target and target.Name or nil,
		method = r and r.method or nil, confidence = r and math.floor(r.confidence * 100) / 100 or nil, low = r and r.low or nil,
		shots = Resolver.shots, confirmed = Resolver.confirmed, missed = Resolver.missed, source = DH.Net.incomingSource,
	}
end
DH.register("resolver", Resolver)
