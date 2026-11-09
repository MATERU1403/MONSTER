-- compile only, never run: does this executor's loadstring accept the built file? (it also enforces the 200-locals limit)
local file = getgenv().RIG_FILE or "_monster_dh.lua"
local source = readfile(file)
local fn, err = loadstring(source, "=monster_dh")
return fn ~= nil, tostring(err), #source
