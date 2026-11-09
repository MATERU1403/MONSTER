return function(T, env)
	T.suite_("codec")
	local Codec = require("../pure/codec")()

	local header29 = string.rep("\x11", 29)
	local header34 = "\xA1" .. string.pack("<I4", 0) .. header29

	T.test("exponent boundaries", function()
		T.eq(Codec.exponent(0), 1)
		T.eq(Codec.exponent(1.9), 1)
		T.eq(Codec.exponent(2), 2)
		T.eq(Codec.exponent(1023.9), 10)
		T.eq(Codec.exponent(1024), nil)
	end)

	T.test("axes round trip within one step", function()
		local cases = {
			{ 0, 0, 0 }, { 1, 2, 3 }, { -1, -2, -3 }, { 500.5, -700.25, 1023.9 }, { 0.001, -0.001, 0 },
			{ 1023.99, 0, 0 }, { -1023.5, 1023.5, -3 }, { 0.5, 0.25, -0.125 }, { 99.99, -99.99, 0.01 },
		}
		for _, c in ipairs(cases) do
			local s = Codec.axes(c[1], c[2], c[3])
			T.truthy(s, "encodes " .. table.concat(c, ","))
			T.eq(#s, 7)
			local x, y, z, e = Codec.unaxes(s, 1)
			local step = 2 ^ (e - 16)
			T.near(x, c[1], step, "x"); T.near(y, c[2], step, "y"); T.near(z, c[3], step, "z")
		end
	end)

	T.test("axes refuses what does not fit", function()
		T.eq(Codec.axes(1024, 0, 0), nil)
		T.eq(Codec.axes(0, -2000, 0), nil)
		T.eq(Codec.axes(0, 0, math.huge), nil)
		T.eq(Codec.axes(0 / 0, 0, 0), nil)
	end)

	T.test("axes random round trip", function()
		local rng = T.rng(7)
		for _ = 1, 2000 do
			local scale = 2 ^ rng:NextNumber(0, 10)
			local x, y, z = rng:NextNumber(-scale, scale), rng:NextNumber(-scale, scale), rng:NextNumber(-scale, scale)
			if math.max(math.abs(x), math.abs(y), math.abs(z)) < 1023.9 then
				local s = Codec.axes(x, y, z)
				local ox, oy, oz, e = Codec.unaxes(s, 1)
				local step = 2 ^ (e - 16)
				T.near(ox, x, step, "x"); T.near(oy, y, step, "y"); T.near(oz, z, step, "z")
			end
		end
	end)

	T.test("rotation round trip over a full turn", function()
		local yaw = -math.pi
		while yaw <= math.pi do
			local bytes = Codec.rotation(yaw)
			T.eq(#bytes, 6)
			local index, p1, p2, p3 = Codec.unrotation(bytes, 1)
			local back = Codec.yawOf(index, p1, p2, p3)
			T.truthy(back, "decodes yaw " .. yaw)
			T.near(Codec.angleDelta(back, yaw), 0, 2e-3, "yaw " .. yaw)
			yaw += 0.05
		end
	end)

	T.test("rotation uses the measured index and part", function()
		-- measured: yaw 30/45/60/-45 = index 3 with the sine in the first part; 135 = index 1 with the cosine in the second
		for _, deg in ipairs({ 30, 45, 60, -45 }) do
			local index, p1 = Codec.unrotation(Codec.rotation(math.rad(deg)), 1)
			T.eq(index, 3, "index at " .. deg)
			T.near(math.abs(p1), math.abs(math.sin(math.rad(deg) / 2)), 1e-3, "sine part at " .. deg)
		end
		local index, p1, p2 = Codec.unrotation(Codec.rotation(math.rad(135)), 1)
		T.eq(index, 1)
		T.near(p2, math.cos(math.rad(135) / 2), 1e-3)
		T.near(p1, 0, 1e-3)
	end)

	T.test("whole packet builds and parses", function()
		local payload = Codec.payload(12.5, -80.25, 300.75, 0.7)
		T.eq(#payload, 14)
		local packet = Codec.build(header34, 123456, Codec.frame(payload))
		T.eq(#packet, 50)
		local p = Codec.parse(packet)
		T.truthy(p and p.standard, "standard layout")
		T.eq(p.stamp, 123456)
		T.eq(p.header, header29)
		T.eq(p.len, 14)
		T.near(p.x, 12.5, 0.02); T.near(p.y, -80.25, 0.02); T.near(p.z, 300.75, 0.02)
		T.near(Codec.angleDelta(p.yaw, 0.7), 0, 2e-3)
	end)

	T.test("setPosition changes only the position bytes", function()
		local packet = Codec.build(header34, 99, Codec.frame(Codec.payload(1, 2, 3, 1.1)))
		local moved = Codec.setPosition(packet, -400, 20, 900)
		T.truthy(moved)
		T.eq(#moved, #packet)
		T.eq(string.sub(moved, 1, 37), string.sub(packet, 1, 37), "before the field")
		T.eq(string.sub(moved, 45), string.sub(packet, 45), "after the field")
		local p = Codec.parse(moved)
		T.near(p.x, -400, 0.02); T.near(p.y, 20, 0.02); T.near(p.z, 900, 0.02)
		T.near(Codec.angleDelta(p.yaw, 1.1), 0, 2e-3, "rotation kept")
		T.eq(Codec.setPosition(packet, 5000, 0, 0), nil, "out of range is refused")
	end)

	T.test("stamps wrap in 32 bits", function()
		local packet = Codec.build(header34, 7, Codec.frame(Codec.payload(0, 0, 0, 0)))
		T.eq(Codec.parse(Codec.setStamp(packet, 2 ^ 32 + 5)).stamp, 5)
		T.eq(Codec.parse(Codec.build(header34, 2 ^ 32 - 1, Codec.frame(Codec.payload(0, 0, 0, 0)))).stamp, 2 ^ 32 - 1)
	end)

	T.test("parse refuses malformed packets and never throws", function()
		T.eq((Codec.parse(nil)), nil)
		T.eq((Codec.parse("short")), nil)
		T.eq((Codec.parse("\x83" .. string.rep("\0", 60))), nil)
		local good = Codec.build(header34, 1, Codec.frame(Codec.payload(0, 0, 0, 0)))
		local cut = string.sub(good, 1, 40)
		T.eq((Codec.parse(cut)), nil, "cut inside the payload")
		local rng = T.rng(99)
		for _ = 1, 600 do
			local n = math.floor(rng:NextNumber(0, 70))
			local bytes = {}
			for i = 1, n do bytes[i] = string.char(math.floor(rng:NextNumber(0, 256))) end
			if n > 0 and rng:NextNumber() < 0.7 then bytes[1] = "\xA1" end
			local ok = pcall(Codec.parse, table.concat(bytes))
			T.truthy(ok, "parse threw on random bytes")
		end
	end)

	T.test("a payload longer than its tag explains is parsed but not standard", function()
		local payload = string.char(0x61) .. Codec.axes(1, 2, 3) .. "\0" -- rid 1 (a stock orientation: no rotation bytes), plus a stray byte
		local packet = Codec.build(header34, 5, Codec.frame(payload))
		local p = Codec.parse(packet)
		T.truthy(p, "parses")
		T.falsy(p.standard, "not standard")
		T.eq(p.rid, 1)
		local plain = Codec.parse(Codec.build(header34, 5, Codec.frame(string.char(0x61) .. Codec.axes(1, 2, 3))))
		T.truthy(plain.standard, "rid 1 with no extra bytes is a whole layout")
	end)

	-- Packets captured live from morrowindf on Volt 1.3.21.2 (2026-11-09), with where the body was at the time.
	local function unhex(h)
		h = string.gsub(h, "%s", "")
		local out = {}
		for i = 1, #h, 2 do out[#out + 1] = string.char(tonumber(string.sub(h, i, i + 1), 16)) end
		return table.concat(out)
	end
	local H9B = "01000000" .. "9B90DDFF" .. "01000000" .. "0166B211" .. "0068" .. "010300" .. "04000000000000" .. "00"
	local HA7 = "01000000" .. "A790DDFF" .. "01000000" .. "0166B211" .. "0068" .. "010300" .. "04000000000000" .. "00"
	local function real(stamp, header, payloadHex)
		local payload = unhex(payloadHex)
		return "\xA1" .. unhex(stamp) .. unhex(header) .. string.pack("<I2", #payload) .. payload
	end

	T.test("real packet, 13 bytes (tag 2A: walking straight, a stock orientation and a linear velocity)", function()
		local p = Codec.parse(real("FCAA1C00", H9B, "2A49 74E9 E017 E135 6000000040"))
		T.truthy(p and p.standard, "layout explained by the tag")
		T.eq(p.len, 13); T.eq(p.rid, 10); T.falsy(p.noLin); T.truthy(p.noAng)
		T.eq(p.e, 9)
		T.near(p.x, 466.92, 0.02); T.near(p.y, 47.75, 0.02); T.near(p.z, -404.25, 0.02)
		T.eq(p.stamp, 0x001CAAFC)
		T.eq(#p.header, 29)
		T.truthy(p.linVel and #p.linVel == 5 and p.angVel == nil)
		T.eq(p.yaw, nil, "a stock orientation has no rotation bytes to decode")
	end)

	T.test("real packet, 24 bytes (tag 00: explicit rotation, linear and angular velocity)", function()
		local p = Codec.parse(real("31AA1C00", HA7, "0049 B2E2 0018 E135 000000801EFE 5EFF007078 5000EA0A00"))
		T.truthy(p and p.standard)
		T.eq(p.len, 24); T.eq(p.rid, 0); T.falsy(p.noLin); T.falsy(p.noAng)
		T.near(p.x, 453.40, 0.02); T.near(p.y, 48.0, 0.02); T.near(p.z, -404.25, 0.02)
		T.truthy(p.linVel and p.angVel, "both velocity blocks")
		T.eq(p.rotIndex, 3, "rotation index")
		-- the body was turning (look 0.083, -0.997 when sampled): yaw about -0.083
		T.truthy(p.yaw ~= nil and math.abs(Codec.angleDelta(p.yaw, -0.083)) < 0.15, "yaw " .. tostring(p.yaw))
		local q = Codec.parse(real("43AA1C00", HA7, "0049 4BE3 0018 E135 00000080AEEE 6000000040 4000010900"))
		T.truthy(q and q.standard)
		T.truthy(q.yaw ~= nil and math.abs(Codec.angleDelta(q.yaw, -math.pi / 4)) < 0.15, "yaw " .. tostring(q.yaw))
	end)

	T.test("real packet, 8 bytes (tag 6A: standing, only the position)", function()
		local p = Codec.parse(real("90AC1C00", H9B, "6A49 ADF6 E017 E135"))
		T.truthy(p and p.standard)
		T.eq(p.len, 8); T.eq(p.rid, 10); T.truthy(p.noLin and p.noAng)
		T.near(p.x, 493.36, 0.02); T.near(p.y, 47.75, 0.02); T.near(p.z, -404.25, 0.02)
	end)

	T.test("real packets: rewriting only the position keeps everything else byte for byte", function()
		for _, packet in ipairs({
			real("FCAA1C00", H9B, "2A4974E9E017E1356000000040"),
			real("31AA1C00", HA7, "0049B2E200 18E135000000801EFE5EFF0070785000EA0A00"),
			real("90AC1C00", H9B, "6A49ADF6E017E135"),
		}) do
			local moved = Codec.setPosition(packet, -250.5, 90, 700.25)
			T.truthy(moved)
			T.eq(#moved, #packet)
			T.eq(string.sub(moved, 1, 37), string.sub(packet, 1, 37))
			T.eq(string.sub(moved, 45), string.sub(packet, 45), "velocity / rotation bytes untouched")
			local p = Codec.parse(moved)
			T.truthy(p and p.standard)
			T.near(p.x, -250.5, 0.02); T.near(p.y, 90, 0.02); T.near(p.z, 700.25, 0.02)
		end
	end)
end
