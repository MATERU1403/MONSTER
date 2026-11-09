-- what hub is loaded here (read only)
local g = getgenv()
local B = g.BASED
if type(B) ~= "table" then return "no BASED" end
local out = {
	unload = typeof(B.unload), config = typeof(B.Config), window = typeof(B.Window),
	monsterScheme = B.Theme and B.Theme.schemes and B.Theme.schemes.monster ~= nil,
	daHood = typeof(B.DaHood), daHoodOn = type(B.DaHood) == "table" and B.DaHood.on or nil,
	build = rawget(B, "BUILD") or rawget(B, "build") or rawget(B, "version"),
	pages = {},
}
if B.Window and B.Window.pages then
	for id in pairs(B.Window.pages) do if string.find(id, "dahood", 1, true) then out.pages[#out.pages + 1] = id end end
	table.sort(out.pages)
end
out.raknetAvail = type(raknet) == "table" and typeof(raknet.send) == "function"
out.rakEnabled = type(raknet) == "table" and type(raknet.is_enabled) == "function" and select(2, pcall(raknet.is_enabled)) or nil
out.fakeDefined = B.Config and B.Config.get("monster.fake") ~= nil
out.rakHook = typeof(g.MONSTER_RAK_HOOK)
return game:GetService("HttpService"):JSONEncode(out)
