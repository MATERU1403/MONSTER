-- who and where this client is: a one-line JSON (read only)
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
local c = lp.Character
local r = c and c:FindFirstChild("HumanoidRootPart")
local h = c and c:FindFirstChildOfClass("Humanoid")
local fx = c and c:FindFirstChild("BodyEffects")
local ko = fx and fx:FindFirstChild("K.O")
local armor = fx and fx:FindFirstChild("Armor")
local tools = {}
for _, t in ipairs(lp.Backpack:GetChildren()) do tools[#tools + 1] = t.Name end
local held = c and c:FindFirstChildOfClass("Tool")
local data = lp:FindFirstChild("DataFolder")
local cash = data and data:FindFirstChild("Currency")
local others = {}
for _, p in ipairs(Players:GetPlayers()) do if p ~= lp then others[#others + 1] = p.Name end end
local g = getgenv()
return game:GetService("HttpService"):JSONEncode({
	name = lp.Name,
	alive = h ~= nil and h.Health > 0,
	health = h and h.Health, armor = armor and armor.Value, ko = ko and ko.Value or false,
	pos = r and { math.floor(r.Position.X * 10) / 10, math.floor(r.Position.Y * 10) / 10, math.floor(r.Position.Z * 10) / 10 } or nil,
	held = held and held.Name, tools = tools, cash = cash and cash.Value,
	others = others,
	hub = typeof(g.BASED) == "table", monsterRak = typeof(g.MONSTER_RAK) == "table", dh = typeof(g.MONSTER_DH) == "table",
	rage = typeof(g.BASED) == "table" and typeof(g.BASED.DaHood) == "table" and g.BASED.DaHood.on or nil,
	ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue(),
	t = workspace:GetServerTimeNow(),
})
