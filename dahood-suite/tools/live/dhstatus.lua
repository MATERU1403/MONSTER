-- the suite's own status, as JSON (read only)
local g = getgenv()
local out = { loadResult = g.MONSTER_LOAD_RESULT, hub = type(g.BASED) == "table" }
local DH = g.MONSTER_DH
if type(DH) ~= "table" then out.dh = "not loaded"; return game:GetService("HttpService"):JSONEncode(out) end
local ok, status = pcall(DH.status)
out.dh = ok and status or tostring(status)
out.skipped = DH.skipped
out.logs = {}
for i = math.max(1, #DH.logs - 5), #DH.logs do out.logs[#out.logs + 1] = DH.logs[i].key .. ": " .. DH.logs[i].msg end
local okJson, json = pcall(function() return game:GetService("HttpService"):JSONEncode(out) end)
return okJson and json or ("encode failed: " .. tostring(json))
