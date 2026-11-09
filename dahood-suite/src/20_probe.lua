-- ---- probe: what this executor can do. Run first; its report names what the net layer is built on.
local Probe = { report = nil, census_ = nil }
DH.Probe = Probe

local CAPS = {
	"hookfunction", "hookmetamethod", "newcclosure", "checkcaller", "getgc", "getconnections", "setfflag", "getfflag", "getrawmetatable",
	"setreadonly", "isrbxactive", "request", "http_request", "Drawing", "sethiddenproperty", "gethiddenproperty", "cloneref", "getnamecallmethod",
	"setnamecallmethod", "firesignal", "fireclickdetector", "getcustomasset", "isfile", "readfile", "writefile", "appendfile", "delfile",
	"makefolder", "isfolder", "gethui", "setthreadidentity", "getthreadidentity", "loadstring", "buffer", "restorefunction", "clonefunction",
	"isexecutorclosure", "replicatesignal", "setscriptable", "isscriptable", "queue_on_teleport", "raknet",
}
local PATTERNS = { "raknet", "packet", "net", "send", "recv", "receive", "bitstream", "hook", "replic" }

---Every global (and table of globals) whose name looks network-like, and what raknet holds.
function Probe.scan()
	local out = { caps = {}, matches = {}, raknet = { present = false, functions = {} }, receive = {} }
	for _, name in ipairs(CAPS) do out.caps[name] = typeof(genv[name]) end
	local seen = {}
	for _, tbl in ipairs({ genv, type(getrenv) == "function" and getrenv() or {}, _G, shared }) do
		if type(tbl) == "table" and not seen[tbl] then
			seen[tbl] = true
			for key, value in pairs(tbl) do
				if type(key) == "string" then
					local lower = string.lower(key)
					for _, pattern in ipairs(PATTERNS) do
						if string.find(lower, pattern, 1, true) then out.matches[key] = typeof(value); break end
					end
				end
			end
		end
	end
	local rk = genv.raknet
	if type(rk) == "table" then
		out.raknet.present = true
		for key, value in pairs(rk) do
			out.raknet.functions[#out.raknet.functions + 1] = tostring(key) .. ":" .. typeof(value)
			local lower = string.lower(tostring(key))
			if typeof(value) == "function" and (string.find(lower, "recv", 1, true) or string.find(lower, "receive", 1, true)) then
				out.receive[#out.receive + 1] = tostring(key)
			end
		end
		table.sort(out.raknet.functions)
		if type(rk.is_enabled) == "function" then
			local ok, enabled = pcall(rk.is_enabled)
			out.raknet.enabled = ok and enabled or ("error: " .. tostring(enabled))
		end
	end
	return out
end

---PhysicsRepRootPart: can it be read, written back unchanged, set to something else and set back to nil? Exact errors are kept.
function Probe.physrep()
	local out = {}
	local root = DH.root()
	if not root then out.error = "no local root"; return out end
	if type(gethiddenproperty) ~= "function" then out.error = "no gethiddenproperty"; return out end
	local okRead, original = pcall(gethiddenproperty, root, "PhysicsRepRootPart")
	out.read = okRead
	out.default = okRead and tostring(original) or nil
	if not okRead then out.readError = tostring(original); return out end
	if type(sethiddenproperty) ~= "function" then out.error = "no sethiddenproperty"; return out end
	local okSame, errSame = pcall(sethiddenproperty, root, "PhysicsRepRootPart", original)
	out.writeSame, out.writeSameError = okSame, (not okSame) and tostring(errSame) or nil
	-- its own root, then nil: is a nil reset accepted?
	local okOwn, errOwn = pcall(sethiddenproperty, root, "PhysicsRepRootPart", root)
	out.writeOwn, out.writeOwnError = okOwn, (not okOwn) and tostring(errOwn) or nil
	local okNil, errNil = pcall(sethiddenproperty, root, "PhysicsRepRootPart", nil)
	out.nilAccepted, out.nilError = okNil, (not okNil) and tostring(errNil) or nil
	local okBack = pcall(sethiddenproperty, root, "PhysicsRepRootPart", original)
	out.restored = okBack
	local okAfter, after = pcall(gethiddenproperty, root, "PhysicsRepRootPart")
	out.after = okAfter and tostring(after) or nil
	return out
end

---Count what this client sends for `seconds` (one first byte per row: count, sizes, a sample). Reads only.
---@param seconds number
---@param done fun(result: table)
function Probe.census(seconds, done)
	local rk = genv.raknet
	if not (type(rk) == "table" and type(rk.add_send_hook) == "function") then done({ error = "no raknet.add_send_hook" }); return end
	local byId, total, shape = {}, 0, nil
	local function hook(packet)
		local ok = pcall(function()
			total += 1
			local id = packet.PacketId
			if not shape then
				shape = { luaType = typeof(packet), id = id }
				local okMeta, meta = pcall(getrawmetatable, packet)
				if okMeta and type(meta) == "table" then
					local names = {}
					for key in pairs(meta) do names[#names + 1] = tostring(key) end
					table.sort(names)
					shape.meta = table.concat(names, ",")
				end
				for _, member in ipairs({ "PacketId", "AsString", "AsBuffer", "AsArray", "Size", "Block", "Priority", "Reliability" }) do
					local okMember, value = pcall(function() return packet[member] end)
					shape[member] = okMember and typeof(value) or "error"
				end
			end
			local key = string.format("%02X", id)
			local row = byId[key]
			local size = #packet.AsString
			if not row then row = { n = 0, min = math.huge, max = 0 }; byId[key] = row end
			row.n += 1
			row.min = math.min(row.min, size)
			row.max = math.max(row.max, size)
		end)
		if not ok then Probe.faults = (Probe.faults or 0) + 1 end
	end
	local okAdd, errAdd = pcall(rk.add_send_hook, hook)
	if not okAdd then done({ error = "add_send_hook: " .. tostring(errAdd) }); return end
	Probe.census_ = hook
	task.delay(seconds, function()
		pcall(rk.remove_send_hook, hook)
		Probe.census_ = nil
		for _, row in pairs(byId) do
			if row.min == math.huge then row.min = nil end
			row.perSecond = math.floor(row.n / seconds * 10 + 0.5) / 10
		end
		done({ seconds = seconds, total = total, byId = byId, shape = shape, faults = Probe.faults or 0 })
	end)
end

---The whole report: executor, capabilities, network-like globals, raknet, PhysicsRepRootPart, a 3 s census. Written to
---monster_probe.json and printed as one line. `opts.census` = seconds (default 3, 0 skips).
function Probe.run(opts)
	opts = opts or {}
	local report = {
		time = os.time(), place = game.PlaceId, gameId = game.GameId,
		executor = (type(identifyexecutor) == "function" and table.concat({ tostring((select(1, identifyexecutor()))), tostring((select(2, identifyexecutor()))) }, " ")) or "unknown",
	}
	report.scan = Probe.scan()
	report.physrep = opts.physrep == false and { skipped = true } or Probe.physrep()
	report.net = DH.Net and DH.Net.status and DH.Net.status() or nil
	Probe.report = report
	local function finish()
		pcall(writefile, "monster_probe.json", S.Http:JSONEncode(report))
		print("MONSTER_PROBE " .. S.Http:JSONEncode({ executor = report.executor, raknet = report.scan.raknet, receive = report.scan.receive, physrep = report.physrep, census = report.census and report.census.total }))
		if opts.done then opts.done(report) end
	end
	local seconds = opts.census == nil and 3 or opts.census
	if seconds > 0 then
		Probe.census(seconds, function(result) report.census = result; finish() end)
	else
		finish()
	end
	return report
end

function Probe.init() end
function Probe.enable() end
function Probe.disable()
	local rk = genv.raknet
	if Probe.census_ and type(rk) == "table" then pcall(rk.remove_send_hook, Probe.census_); Probe.census_ = nil end
end
function Probe.status()
	return { ran = Probe.report ~= nil, censusRunning = Probe.census_ ~= nil, raknet = Probe.report and Probe.report.scan.raknet or nil }
end
DH.register("probe", Probe)
