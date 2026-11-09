-- Capture this client's outgoing packets for CAP_SECONDS (default 4) and write monster-build/results/cap_<label>.json.
-- Reads only: the hook never changes or drops a packet and is removed at the end. Every 0xA1 is stored whole (hex) with the
-- root's CFrame as it was after the last physics step (the engine builds the packet right after), so the decode can be checked
-- against what the body really did. Other packets are only counted by id: count, sizes, first sample.
local g = getgenv()
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local lp = game:GetService("Players").LocalPlayer
local label = g.CAP_LABEL or "cap"
local seconds = g.CAP_SECONDS or 4
if g.CAP_STOP then pcall(g.CAP_STOP) end

local rows, others, shape, faults = {}, {}, nil, 0
local snap
local conn = RunService.PostSimulation:Connect(function()
	local c = lp.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r then
		local cf = r.CFrame
		local look = cf.LookVector
		snap = { t = os.clock(), x = cf.X, y = cf.Y, z = cf.Z, lx = look.X, lz = look.Z, vx = r.AssemblyLinearVelocity.X, vy = r.AssemblyLinearVelocity.Y, vz = r.AssemblyLinearVelocity.Z }
	end
end)

local function hex(s)
	local out = table.create(#s)
	for i = 1, #s do out[i] = string.format("%02x", string.byte(s, i)) end
	return table.concat(out)
end

local started = os.clock()
local function hook(packet)
	local ok = pcall(function()
		local id = packet.PacketId
		if not shape then
			shape = { luaType = typeof(packet), id = id }
			local okMeta, meta = pcall(getrawmetatable, packet)
			if okMeta and type(meta) == "table" then
				local names = {}
				for k in pairs(meta) do names[#names + 1] = tostring(k) end
				table.sort(names)
				shape.meta = table.concat(names, ",")
				local idx = rawget(meta, "__index")
				if type(idx) == "table" then
					local members = {}
					for k in pairs(idx) do members[#members + 1] = tostring(k) end
					table.sort(members)
					shape.members = table.concat(members, ",")
				end
			end
		end
		local s = packet.AsString
		if id == 0xA1 then
			local row = { t = os.clock() - started, n = #s, hex = hex(s) }
			if snap then row.hrp = snap; row.age = os.clock() - snap.t end
			rows[#rows + 1] = row
		else
			local key = string.format("%02X", id)
			local o = others[key]
			if not o then o = { n = 0, min = math.huge, max = 0, sample = hex(string.sub(s, 1, 24)) }; others[key] = o end
			o.n += 1
			o.min = math.min(o.min, #s)
			o.max = math.max(o.max, #s)
		end
	end)
	if not ok then faults += 1 end
end

local active = true
local function finish()
	if not active then return end
	active = false
	pcall(raknet.remove_send_hook, hook)
	conn:Disconnect()
	local seconds_ = os.clock() - started
	for _, o in pairs(others) do o.perSecond = math.floor(o.n / seconds_ * 10 + 0.5) / 10; if o.min == math.huge then o.min = nil end end
	local ok, err = pcall(writefile, "monster-build/results/cap_" .. label .. ".json", Http:JSONEncode({
		label = label, seconds = seconds_, a1 = rows, others = others, shape = shape, faults = faults, executor = (identifyexecutor and select(2, identifyexecutor())) or "?",
	}))
	g.CAP_DONE = label .. ":" .. tostring(#rows) .. ":" .. tostring(ok) .. ":" .. tostring(err)
end
g.CAP_STOP = finish
g.CAP_DONE = nil

raknet.add_send_hook(hook)
task.delay(seconds, finish)
return "capturing " .. label .. " for " .. seconds .. " s"
