-- Tiny test library for the offline suites (Lune).
local T = { passed = 0, failed = 0, failures = {}, notes = {}, suite = "" }

function T.test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		T.passed += 1
	else
		T.failed += 1
		table.insert(T.failures, T.suite .. " / " .. name .. ": " .. tostring(err))
	end
end

function T.note(text) table.insert(T.notes, text) end

local function fmt(v)
	if type(v) == "number" then return string.format("%.6g", v) end
	return tostring(v)
end

function T.eq(a, b, msg)
	if a ~= b then error((msg or "eq") .. ": expected " .. fmt(b) .. ", got " .. fmt(a), 2) end
end

function T.near(a, b, tol, msg)
	if type(a) ~= "number" or type(b) ~= "number" or a ~= a or b ~= b or math.abs(a - b) > tol then
		error((msg or "near") .. ": expected " .. fmt(b) .. " +/- " .. fmt(tol) .. ", got " .. fmt(a), 2)
	end
end

function T.truthy(v, msg)
	if not v then error((msg or "truthy") .. ": got " .. fmt(v), 2) end
end

function T.falsy(v, msg)
	if v then error((msg or "falsy") .. ": got " .. fmt(v), 2) end
end

function T.lt(a, b, msg)
	if not (a < b) then error((msg or "lt") .. ": expected " .. fmt(a) .. " < " .. fmt(b), 2) end
end

function T.vnear(a, b, tol, msg)
	if (a - b).Magnitude > tol then error((msg or "vnear") .. ": expected " .. tostring(b) .. " +/- " .. fmt(tol) .. ", got " .. tostring(a), 2) end
end

-- deterministic random stand-in for Roblox's Random
function T.rng(seed)
	local state = seed or 12345
	local r = {}
	function r:NextNumber(lo, hi)
		state = (state * 1103515245 + 12345) % 2147483648
		local u = state / 2147483648
		if lo then return lo + (hi - lo) * u end
		return u
	end
	return r
end

function T.suite_(name) T.suite = name end

return T
