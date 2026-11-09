-- Offline suites for the pure modules. Run:  lune run tests/run  (from the monster-build folder)
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local T = require("./lib")

local env = { Vector3 = roblox.Vector3, CFrame = roblox.CFrame }

local suites = {
	{ "t_codec", require("./t_codec") },
	{ "t_orbit", require("./t_orbit") },
	{ "t_resolver", require("./t_resolver") },
	{ "t_logic", require("./t_logic") },
	{ "t_phys_cfg", require("./t_phys_cfg") },
}

for _, entry in ipairs(suites) do
	local ok, err = pcall(entry[2], T, env)
	if not ok then
		T.failed += 1
		table.insert(T.failures, entry[1] .. " (suite crashed): " .. tostring(err))
	end
end

for _, note in ipairs(T.notes) do print(note) end
print(string.format("\n%d passed, %d failed", T.passed, T.failed))
for _, failure in ipairs(T.failures) do print("FAIL " .. failure) end
if T.failed > 0 then process.exit(1) end
