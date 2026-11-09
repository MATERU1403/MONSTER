-- ---- net: the packet layer. Volt's raknet gives a send hook and send (no receive hook, measured 1.3.21.2); Da Hood's body is packet 0xA1.
-- While held, the engine's own body packets are blocked and ones carrying the server position are sent at a steady rate; released,
-- the real place is sent once and the engine's packets flow again. Anything that does not look like what was captured is passed
-- through untouched and logged once. Nothing here throws inside a hook.
local Codec = DH.F.codec()
DH.Codec = Codec
local Net = {
	on = false, available = false, denied = false, reason = nil,
	sent = 0, failed = 0, blocked = 0, unparsed = 0, noHeader = 0, hookFaults = 0,
	layouts = {}, hooks = { send = false, receive = false }, rxNames = {}, mode = "craft",
	rate = 0, lastHold = 0,
}
DH.Net = Net
genv.MONSTER_RAK = Net -- (what a test reads: on / sent / failed / blocked / available)

local rk = genv.raknet
local header, lastStamp, lastClock, needHeader = nil, 0, 0, false
local acc, want = 0, nil
local failStamps, rateCount, rateSince = {}, 0, os.clock()
local hookFn

-- ---- what raknet offers
local function scanRaknet()
	Net.available = type(rk) == "table" and type(rk.add_send_hook) == "function" and type(rk.send) == "function" and type(rk.remove_send_hook) == "function"
	Net.rxNames = {}
	if type(rk) == "table" then
		for key, value in pairs(rk) do
			local lower = string.lower(tostring(key))
			if typeof(value) == "function" and (string.find(lower, "recv", 1, true) or string.find(lower, "receive", 1, true)) then
				Net.rxNames[#Net.rxNames + 1] = tostring(key)
			end
		end
		if type(rk.is_enabled) == "function" then
			local ok, enabled = pcall(rk.is_enabled)
			if ok and enabled == false then Net.available, Net.reason = false, "raknet library is switched off in the executor" end
		end
	end
	Net.hooks.receive = #Net.rxNames > 0 -- (seen but not used: the incoming layout is not decoded, so the resolver polls)
end

---Stop crafting: the server is given the real place and the engine's packets flow. The caller falls back to the body swap.
function Net.deny(reason)
	if Net.denied then return end
	Net.denied, Net.reason, Net.available, Net.on = true, reason, false, false
	want = nil
	DH.warn("net.denied", reason, 0.1)
	DH.fire("net-denied", reason)
end

local function noteFailure()
	Net.failed += 1
	local now, window = os.clock(), DH.K.get("NET_FAIL_WINDOW")
	failStamps[#failStamps + 1] = now
	while failStamps[1] and now - failStamps[1] > window do table.remove(failStamps, 1) end
	if #failStamps >= DH.K.get("NET_FAIL_COUNT") then Net.deny("raknet.send failed " .. #failStamps .. " times in " .. window .. " s") end
end

-- ---- the send hook
local function onSend(packet)
	if packet.PacketId ~= Codec.ID then return end
	local s = packet.AsString
	if #s < 36 then return end
	local parsed = Codec.parse(s)
	if not parsed then
		-- not a layout that was captured: pass it through, remember the header of the body, say so once
		Net.unparsed += 1
		header = string.sub(s, 1, 34)
		DH.warn("net.unparsed", "a 0xA1 packet of " .. #s .. " bytes did not decode; passed through", 30)
		return
	end
	if parsed.stamp > lastStamp then lastStamp, lastClock = parsed.stamp, os.clock() end
	header, needHeader = string.sub(s, 1, 34), false
	Net.layouts[parsed.len] = (Net.layouts[parsed.len] or 0) + 1
	if Net.on and not Net.denied then
		packet:Block()
		Net.blocked += 1
	end
end

local function installHook()
	if hookFn or not Net.available then return Net.hooks.send end
	if genv.MONSTER_RAK_HOOK then pcall(rk.remove_send_hook, genv.MONSTER_RAK_HOOK); genv.MONSTER_RAK_HOOK = nil end
	hookFn = function(packet)
		local ok, err = pcall(onSend, packet)
		if not ok then Net.hookFaults += 1; Net.lastHookError = tostring(err) end
	end
	local ok, err = pcall(rk.add_send_hook, hookFn)
	if ok then
		Net.hooks.send = true
		genv.MONSTER_RAK_HOOK = hookFn
	else
		hookFn, Net.available, Net.reason = nil, false, "add_send_hook: " .. tostring(err)
	end
	return Net.hooks.send
end

local function removeHook()
	if hookFn and type(rk) == "table" then pcall(rk.remove_send_hook, hookFn) end
	if genv.MONSTER_RAK_HOOK == hookFn then genv.MONSTER_RAK_HOOK = nil end
	hookFn, Net.hooks.send = nil, false
end

-- a new body needs a new header before anything is sent
DH.janitor:add(DH.LP.CharacterAdded:Connect(function() header = nil; needHeader = false end), "net.respawn")

-- a disconnect prompt means the server did not like something: stop crafting
pcall(function()
	DH.janitor:add(S.Gui.ErrorMessageChanged:Connect(function()
		local message = ""
		pcall(function() message = tostring(S.Gui:GetErrorMessage()) end)
		if message ~= "" and Net.on then Net.deny("disconnect prompt: " .. string.sub(message, 1, 80)) end
	end), "net.errorprompt")
end)

-- ---- sending
---Send one body packet: the live header, a new stamp, and `framed` (length + payload).
local function sendFramed(framed)
	if not header then
		Net.noHeader += 1
		return false
	end
	local stamp = math.max(lastStamp + 1, lastStamp + math.floor((os.clock() - lastClock) * 240))
	local packet = Codec.build(header, stamp, framed)
	if not pcall(rk.send, buffer.fromstring(packet)) then
		noteFailure()
		return false
	end
	lastStamp, lastClock = stamp, os.clock()
	Net.sent += 1
	rateCount += 1
	local now = os.clock()
	if now - rateSince >= 1 then Net.rate, rateCount, rateSince = rateCount / (now - rateSince), 0, now end
	return true
end

---Tell the server the body is at `cframe` now (needs one real packet of this body seen first).
---@param cframe CFrame
---@return boolean
function Net.send(cframe)
	if Net.denied then return false end
	local p = cframe.Position
	local look = cframe.LookVector
	local payload = Codec.payload(p.X, p.Y, p.Z, math.atan2(-look.X, -look.Z))
	if not payload then
		Net.failed += 1
		return false
	end
	return sendFramed(Codec.frame(payload))
end

---Hold the server body at `cframe`, re-sent at the chosen rate (the first right away).
---@param cframe CFrame
---@param root BasePart
---@param dt number
---@param everyStep boolean? send on every call, not at the chosen rate
function Net.hold(cframe, root, dt, everyStep)
	if Net.denied or not Net.available then return end
	local first = not Net.on
	Net.on, want = true, cframe
	Net.lastHold = os.clock()
	if not header and root then
		-- (a body standing still sends nothing: a 0.02-stud shift makes one, which is blocked and read)
		needHeader = true
		root.CFrame = root.CFrame + Vector3.new(0.02, 0, 0)
		return
	end
	acc += dt
	local rate = DH.get("monster.rakRate") or 30
	if first or everyStep or acc >= 1 / math.max(rate, 5) then
		acc = 0
		Net.send(want)
	end
end

---Let go: the server is given the real place once, then the body's own packets flow again.
---@param cframe CFrame?
function Net.release(cframe)
	if not Net.on then return end
	if cframe then Net.send(cframe) end
	Net.on, want, acc = false, nil, 0
end

---The server body as the API asks for it: a CFrame holds it (the fake-position driver does the sending), nil lets go.
function Net.setServerCFrame(cframe)
	if DH.Fakepos then DH.Fakepos.setSource("net", cframe) end
end

function Net.needsHeader() return needHeader end
function Net.ready() return Net.available and not Net.denied and header ~= nil end

-- ---- incoming: Volt has no receive hook, so other players' bodies are read as the engine shows them, once a frame
do
	local subs, conn = {}, nil
	local function sampleOf(player, now)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return nil end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local parts = {}
		for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso" }) do
			local part = character:FindFirstChild(name)
			if part then parts[name] = part.Position end
		end
		local move = humanoid and humanoid.MoveDirection or ZERO
		return {
			t = now, serverT = workspace:GetServerTimeNow(), pos = root.Position, vel = root.AssemblyLinearVelocity, look = root.CFrame.LookVector,
			parts = parts, moveDir = move, walk = humanoid and humanoid.WalkSpeed or 16, moving = move.Magnitude > 0.1,
			tool = (character:FindFirstChildOfClass("Tool") or {}).Name,
		}
	end
	local function poll()
		local now = os.clock()
		for _, player in ipairs(S.Players:GetPlayers()) do
			if player ~= DH.LP then
				local ok, s = pcall(sampleOf, player, now)
				if ok and s then
					for _, fn in ipairs(subs) do
						local okFn, err = pcall(fn, player, s)
						if not okFn then DH.fail("net.onIncoming", err) end
					end
				end
			end
		end
	end
	---Watch other players' replicated bodies. `fn(player, sample)` runs once a frame for each (sample: t, serverT, pos, vel, look, parts, moveDir, walk, moving, tool).
	---@return table connection with :Disconnect()
	function Net.onIncoming(fn)
		subs[#subs + 1] = fn
		if not conn then conn = DH.janitor:add(S.Run.Heartbeat:Connect(poll), "net.incoming") end
		return { Disconnect = function()
			for i, f in ipairs(subs) do if f == fn then table.remove(subs, i) break end end
			if #subs == 0 and conn then conn:Disconnect(); conn = nil end
		end }
	end
	Net.incomingSource = "poll"
	function Net.sampleOf(player) return sampleOf(player, os.clock()) end
end

-- ---- capture and diff: how the position field was found (and how to find it again after an update)
---Log this client's outgoing packets for `seconds`: every 0xA1 whole (hex) with where the body was, other ids counted.
function Net.capture(seconds, label, done)
	if not Net.available then if done then done({ error = "raknet unavailable" }) end return end
	local rows, others, snap = {}, {}, nil
	local started = os.clock()
	local snapConn = S.Run.PostSimulation:Connect(function()
		local root = DH.root()
		if root then local cf = root.CFrame; snap = { x = cf.X, y = cf.Y, z = cf.Z, t = os.clock() } end
	end)
	local function hex(s) local out = table.create(#s); for i = 1, #s do out[i] = string.format("%02x", string.byte(s, i)) end return table.concat(out) end
	local function hook(packet)
		pcall(function()
			local s = packet.AsString
			if packet.PacketId == Codec.ID then
				rows[#rows + 1] = { t = os.clock() - started, hex = hex(s), hrp = snap }
			else
				local key = string.format("%02X", packet.PacketId)
				local o = others[key] or { n = 0, min = math.huge, max = 0 }
				others[key] = o
				o.n += 1; o.min = math.min(o.min, #s); o.max = math.max(o.max, #s)
			end
		end)
	end
	pcall(rk.add_send_hook, hook)
	task.delay(seconds, function()
		pcall(rk.remove_send_hook, hook)
		snapConn:Disconnect()
		local result = { label = label, seconds = seconds, a1 = rows, others = others }
		pcall(writefile, "monster-build/results/net_capture_" .. tostring(label) .. ".json", S.Http:JSONEncode(result))
		if done then done(result) end
	end)
end

---Which byte offsets (1-based, within the packet) differ between two captures' packets of the same length?
---@return table offset -> number of packet pairs that differ there
function Net.diff(rowsA, rowsB)
	local function unhex(h) local out = {}; for i = 1, #h, 2 do out[#out + 1] = string.char(tonumber(string.sub(h, i, i + 1), 16)) end return table.concat(out) end
	local counts = {}
	for i = 1, math.min(#rowsA, #rowsB) do
		local a, b = unhex(rowsA[i].hex), unhex(rowsB[i].hex)
		if #a == #b then
			for at = 1, #a do
				if string.byte(a, at) ~= string.byte(b, at) then counts[at] = (counts[at] or 0) + 1 end
			end
		end
	end
	return counts
end

---Check the codec against captured rows: median position error (studs) and how many decoded.
function Net.verify(rows)
	local errors, decoded = {}, 0
	local function unhex(h) local out = {}; for i = 1, #h, 2 do out[#out + 1] = string.char(tonumber(string.sub(h, i, i + 1), 16)) end return table.concat(out) end
	for _, row in ipairs(rows) do
		local parsed = Codec.parse(unhex(row.hex))
		if parsed then
			decoded += 1
			if row.hrp then errors[#errors + 1] = math.sqrt((parsed.x - row.hrp.x) ^ 2 + (parsed.y - row.hrp.y) ^ 2 + (parsed.z - row.hrp.z) ^ 2) end
		end
	end
	table.sort(errors)
	return { rows = #rows, decoded = decoded, median = errors[math.max(1, math.ceil(#errors / 2))], max = errors[#errors] }
end

-- ---- lifecycle
local lastCheck = 0
function Net.init()
	scanRaknet()
	if Net.available then installHook() end
	DH.janitor:add(S.Run.Heartbeat:Connect(function()
		-- a held body whose driver stopped asking is let go (a stalled loop must not leave the server body behind)
		local now = os.clock()
		if Net.on and now - Net.lastHold > 0.5 then
			DH.warn("net.stale", "hold went stale: releasing", 5)
			local root = DH.root()
			Net.release(root and root.CFrame)
		end
		if now - lastCheck > 2 then
			lastCheck = now
			if type(rk) == "table" and type(rk.is_enabled) == "function" and Net.on then
				local ok, enabled = pcall(rk.is_enabled)
				if ok and enabled == false then Net.deny("raknet library was switched off") end
			end
		end
	end), "net.watch")
end
function Net.enable() if Net.available then installHook() end end
function Net.disable()
	local root = DH.root()
	Net.release(root and root.CFrame)
	Net.on = false
	removeHook()
end
Net.stop = Net.disable -- (the older block's name for it)
function Net.status()
	return {
		available = Net.available, denied = Net.denied, reason = Net.reason, on = Net.on, hooks = Net.hooks, rxNames = Net.rxNames,
		sent = Net.sent, failed = Net.failed, blocked = Net.blocked, unparsed = Net.unparsed, noHeader = Net.noHeader, hookFaults = Net.hookFaults,
		rate = math.floor(Net.rate * 10) / 10, layouts = Net.layouts, headerKnown = header ~= nil, incoming = Net.incomingSource, mode = Net.mode,
	}
end
DH.register("net", Net)
