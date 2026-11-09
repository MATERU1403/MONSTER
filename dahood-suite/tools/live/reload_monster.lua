-- unload the MONSTER / BasedHub running here, then run the new build (RIG_FILE, default _monster_dh.lua) in its own thread
local g = getgenv()
local file = g.RIG_FILE or "_monster_dh.lua"
local B = g.BASED
if type(B) == "table" and B.unload then pcall(B.unload) end
local t0 = os.clock()
while g.BASED and os.clock() - t0 < 12 do task.wait(0.1) end
local source = readfile(file)
local fn, err = loadstring(source, "=monster_dh")
if not fn then return false, "compile: " .. tostring(err) end
g.MONSTER_LOAD_RESULT = nil
task.spawn(function()
	local ok, e = pcall(fn)
	g.MONSTER_LOAD_RESULT = tostring(ok) .. " " .. tostring(e)
end)
return true, "started", g.BASED == nil, os.clock() - t0
