-- Group the captured 0xA1 packets by payload length and tag byte and print examples next to what the body was doing.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Codec = require("../pure/codec")()

local function unhex(h)
	local out = {}
	for i = 1, #h, 2 do out[#out + 1] = string.char(tonumber(string.sub(h, i, i + 1), 16)) end
	return table.concat(out)
end

local groups = {}
for _, label in ipairs({ "walk", "jump", "nudge" }) do
	local data = serde.decode("json", fs.readFile("results/cap_" .. label .. ".json"))
	for _, row in ipairs(data.a1 or {}) do
		local packet = unhex(row.hex)
		local len = string.unpack("<I2", packet, 35)
		local key = string.format("len=%d tag=%02X", len, string.byte(packet, 37))
		local g = groups[key]
		if not g then g = { n = 0, examples = {}, labels = {} }; groups[key] = g end
		g.n += 1
		g.labels[label] = (g.labels[label] or 0) + 1
		if #g.examples < 4 then
			table.insert(g.examples, { packet = packet, row = row, label = label })
		end
	end
end

local keys = {}
for k in pairs(groups) do table.insert(keys, k) end
table.sort(keys)
for _, key in ipairs(keys) do
	local g = groups[key]
	local seen = {}
	for l, n in pairs(g.labels) do table.insert(seen, l .. "=" .. n) end
	print(string.format("%s  (%d packets: %s)", key, g.n, table.concat(seen, " ")))
	for _, ex in ipairs(g.examples) do
		local p = ex.packet
		local payload = string.sub(p, 37)
		local hrp = ex.row.hrp
		print("  header+stamp: " .. Codec.hex(p, 1, 5) .. " | hdr29: " .. Codec.hex(p, 6, 29))
		print("  payload    : " .. Codec.hex(payload, 1, #payload))
		if hrp then
			print(string.format("  body       : pos %.2f %.2f %.2f  vel %.2f %.2f %.2f  look %.3f %.3f", hrp.x, hrp.y, hrp.z, hrp.vx, hrp.vy, hrp.vz, hrp.lx, hrp.lz))
		end
		local parsed = Codec.parse(p)
		if parsed then print(string.format("  decoded    : pos %.2f %.2f %.2f e=%d yaw=%s", parsed.x, parsed.y, parsed.z, parsed.e, tostring(parsed.yaw))) end
	end
end
