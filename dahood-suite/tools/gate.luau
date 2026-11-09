-- Compile gate: does the built file compile as Luau? (the executor's own loadstring is the second gate, run live)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local path = process.args[1]
if not path then
	print("usage: lune run tools/gate <file>")
	process.exit(64)
end
local source = fs.readFile(path)
local ok, err = pcall(luau.compile, source)
if not ok then
	print("COMPILE FAILED: " .. tostring(err))
	process.exit(1)
end
-- crude local-variable pressure report: `local` declarations at the top level of the main chunk (depth 0 = no leading tab)
local topLocals = 0
for line in string.gmatch(source, "[^\n]+") do
	if string.match(line, "^local%s") then topLocals += 1 end
end
print(string.format("compile ok: %d bytes, %d top-level `local` lines (the main function holds at most 200 active locals)", #source, topLocals))
