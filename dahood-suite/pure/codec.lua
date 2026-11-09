-- Da Hood body packet (0xA1) codec. Pure: strings and numbers only, so it runs under Lune as well as in the client.
--
-- Layout, measured 2026-11-09 on Volt 1.3.21.2 (two accounts; 122 real packets decoded against the body, see results/capture_report.md):
--   byte 1        0xA1
--   bytes 2-5     <I4 stamp in 1/240 s (an older stamp is dropped by the server); ~14 packets a second while moving
--   bytes 6-34    29 header bytes (the same for a body, but byte 10 changed once during a walk: it is taken fresh from the newest real packet)
--   bytes 35-36   <I2 payload length
--   payload       tag: bit 0x40 = no linear velocity block, bit 0x20 = no angular velocity block, low 5 bits = rotation id
--                      (0: six explicit rotation bytes follow; 10 was seen for an upright body facing along X: a stock orientation)
--                 e*8 + signs (signs: X = 4, Y = 2, Z = 1)
--                 three <I2 axes: raw / 2^(16-e), minus 2^e when that axis is negative (e <= 10, so |coord| < 1024)
--                 [rotation, 6 bytes, when the rotation id is 0: a quaternion cut to 47 bits: 2-bit index, three signed 15-bit parts]
--                 [linear velocity, 5 bytes, when 0x40 is clear]   [angular velocity, 5 bytes, when 0x20 is clear]  (both seen, neither decoded)
--                 Seen on the wire: 8 bytes (tag 6A, standing), 13 (tag 2A, walking straight), 24 (tag 00, turning while walking).
--                 What is built here is the 14-byte form, tag 60: no velocities, explicit rotation. The server accepts it.
-- Nothing past |coord| 1024 is ever built here: that is a different packing, and replaying far packets the engine
-- had made got an account disconnected (error 260).
return function()
	local Codec = {}
	local floor, abs, max, sqrt, sin, cos, atan2, clamp = math.floor, math.abs, math.max, math.sqrt, math.sin, math.cos, math.atan2, math.clamp
	local pack, unpack, char, byte, sub = string.pack, string.unpack, string.char, string.byte, string.sub

	Codec.ID = 0xA1
	Codec.HEADER = 34       -- id + stamp + 29 header bytes
	Codec.STANDARD_LEN = 14 -- tag + axes byte + three axes + six rotation bytes
	Codec.LIMIT = 1023.9    -- the largest |coord| the packing can carry
	local QUARTER = 32767 / sqrt(2)
	local TWO_PI = math.pi * 2

	---Shortest e (1..10) whose range [0, 2^e) holds `big`.
	---@param big number
	---@return number?
	function Codec.exponent(big)
		if big ~= big or big >= 1024 then return nil end -- (NaN, inf and anything past the format: no loop to run)
		local e = 1
		while e <= 10 and 2 ^ e <= big do e += 1 end
		if e > 10 then return nil end
		return e
	end

	---The axes byte and three 16-bit axes of a position (nil when a coordinate does not fit).
	---@return string?
	function Codec.axes(x, y, z)
		if x ~= x or y ~= y or z ~= z then return nil end
		local e = Codec.exponent(max(abs(x), abs(y), abs(z)))
		if not e then return nil end
		local scale, signs, out = 2 ^ (16 - e), 0, {}
		local values = { x, y, z }
		for i = 1, 3 do
			local value = values[i]
			local negative = value < 0
			if negative then signs += 2 ^ (3 - i) end
			out[i] = pack("<I2", clamp(floor((value + (negative and 2 ^ e or 0)) * scale + 0.5), 0, 65535))
		end
		return char(e * 8 + signs) .. out[1] .. out[2] .. out[3]
	end

	---Inverse of axes: `at` is the 1-based offset of the e*8+signs byte.
	---@return number?, number?, number?, number?
	function Codec.unaxes(s, at)
		if #s < at + 6 then return nil end
		local b = byte(s, at)
		local e, signs = floor(b / 8), b % 8
		if e < 1 or e > 10 then return nil end
		local scale, ring, out = 2 ^ (16 - e), 2 ^ e, {}
		for i = 1, 3 do
			local raw = unpack("<I2", s, at + 1 + (i - 1) * 2)
			local value = raw / scale
			local bit = 2 ^ (3 - i)
			if floor(signs / bit) % 2 == 1 then value -= ring end
			out[i] = value
		end
		return out[1], out[2], out[3], e
	end

	---Six rotation bytes for an upright body turned by `yaw` (radians, atan2(-look.X, -look.Z)).
	---Measured: yaw 30/45/60/-45 = index 3 with the sine in the first part; 135 = index 1 with the cosine in the second.
	---@param yaw number
	---@return string
	function Codec.rotation(yaw)
		local s, c = sin(yaw / 2), cos(yaw / 2)
		local index, parts
		if abs(c) >= abs(s) then
			if c < 0 then s = -s end
			index, parts = 3, { s, 0, 0 }
		else
			if s < 0 then c = -c end
			index, parts = 1, { 0, c, 0 }
		end
		local value = index * 2 ^ 46
		for i = 1, 3 do
			local raw = clamp(floor(parts[i] * QUARTER + 0.5), -16384, 16383) % 32768
			value += raw * 2 ^ (46 - 15 * i)
		end
		return pack("<I4", value % 2 ^ 32) .. pack("<I2", floor(value / 2 ^ 32))
	end

	---Split six rotation bytes: index and the three signed parts (as fractions of the unit quaternion).
	---@param s string
	---@param at number 1-based offset
	---@return number?, number?, number?, number?
	function Codec.unrotation(s, at)
		if #s < at + 5 then return nil end
		local lo, hi = unpack("<I4", s, at), unpack("<I2", s, at + 4)
		local value = lo + hi * 2 ^ 32
		local index = floor(value / 2 ^ 46)
		local rest = value % 2 ^ 46
		local parts = {}
		for i = 1, 3 do
			local raw = floor(rest / 2 ^ (46 - 15 * i)) % 32768
			if raw >= 16384 then raw -= 32768 end
			parts[i] = raw / QUARTER
		end
		return index, parts[1], parts[2], parts[3]
	end

	---Yaw back out of an upright rotation (nil when the rotation is not a plain turn about Y).
	---@return number?
	function Codec.yawOf(index, p1, p2, p3)
		local tolerance = 0.002
		local half
		if index == 3 and abs(p2) < tolerance and abs(p3) < tolerance then
			half = atan2(p1, sqrt(max(0, 1 - p1 * p1)))
		elseif index == 1 and abs(p1) < tolerance and abs(p3) < tolerance then
			half = atan2(sqrt(max(0, 1 - p2 * p2)), p2)
		else
			return nil
		end
		return half * 2
	end

	---Difference of two angles, wrapped to [-pi, pi].
	function Codec.angleDelta(a, b)
		local d = (a - b + math.pi) % TWO_PI - math.pi
		return d
	end

	---Payload (tag, axes, rotation) for a body at (x, y, z) turned by yaw; nil when the position does not fit.
	---@return string?
	function Codec.payload(x, y, z, yaw)
		local body = Codec.axes(x, y, z)
		if not body then return nil end
		return char(0x60) .. body .. Codec.rotation(yaw or 0)
	end

	---Length-prefixed payload, what the packet carries after the header.
	function Codec.frame(payload)
		return pack("<I2", #payload) .. payload
	end

	---A whole packet: the first byte and the 29 header bytes of a real packet of this body, a new stamp, a framed payload.
	---@param header string at least 34 bytes of a real packet
	---@param stamp number
	---@param framed string
	---@return string
	function Codec.build(header, stamp, framed)
		return sub(header, 1, 1) .. pack("<I4", stamp % 2 ^ 32) .. sub(header, 6, 34) .. framed
	end

	---Read a packet. `standard` is true when the payload length is exactly what its tag byte says it holds (every layout seen live does).
	---@param packet string
	---@return table?, string?
	function Codec.parse(packet)
		if type(packet) ~= "string" then return nil, "not a string" end
		if #packet < 36 then return nil, "short" end
		if byte(packet, 1) ~= Codec.ID then return nil, "id" end
		local len = unpack("<I2", packet, 35)
		if len < 1 or 36 + len > #packet then return nil, "length" end
		local tag = byte(packet, 37)
		local out = {
			id = Codec.ID,
			stamp = unpack("<I4", packet, 2),
			header = sub(packet, 6, 34),
			len = len,
			bytes = #packet,
			tag = tag,
			noLin = floor(tag / 0x40) % 2 == 1,
			noAng = floor(tag / 0x20) % 2 == 1,
			rid = tag % 0x20,
		}
		local expected = 8 + (out.rid == 0 and 6 or 0) + (out.noLin and 0 or 5) + (out.noAng and 0 or 5)
		out.standard = len == expected
		if len >= 8 then
			local x, y, z, e = Codec.unaxes(packet, 38)
			if x then out.x, out.y, out.z, out.e = x, y, z, e end
		end
		local at = 45 -- the first byte after the axes
		if out.standard and out.rid == 0 then
			local index, p1, p2, p3 = Codec.unrotation(packet, at)
			if index then
				out.rotIndex, out.rot = index, { p1, p2, p3 }
				out.yaw = Codec.yawOf(index, p1, p2, p3)
			end
			at += 6
		end
		if out.standard then
			if not out.noLin then out.linVel = sub(packet, at, at + 4); at += 5 end
			if not out.noAng then out.angVel = sub(packet, at, at + 4) end
		end
		if not out.x then return nil, "axes" end
		return out
	end

	---A copy of a real packet with only the position changed (the field at bytes 38-44), the rest as it was.
	---@return string?
	function Codec.setPosition(packet, x, y, z)
		local parsed = Codec.parse(packet)
		if not parsed then return nil end
		local body = Codec.axes(x, y, z)
		if not body then return nil end
		return sub(packet, 1, 37) .. body .. sub(packet, 45)
	end

	---Copy of a packet with a new stamp.
	function Codec.setStamp(packet, stamp)
		return sub(packet, 1, 1) .. pack("<I4", stamp % 2 ^ 32) .. sub(packet, 6)
	end

	---Hex dump of a byte range, for the capture logs.
	function Codec.hex(s, from, count)
		local out = {}
		for i = from or 1, math.min(#s, (from or 1) + (count or #s) - 1) do out[#out + 1] = string.format("%02X", byte(s, i)) end
		return table.concat(out, " ")
	end

	return Codec
end
