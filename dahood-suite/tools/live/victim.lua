-- The victim's own view of an attack test (read only): every change of its health / armor / knock-out state with server time, for VIC_SECONDS.
-- Run on the alt that is being shot. Globals: VIC_SECONDS (default 45), VIC_LABEL. Writes monster-build/results/victim_<label>.json.
local g = getgenv()
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local lp = game:GetService("Players").LocalPlayer
local seconds, label = g.VIC_SECONDS or 45, g.VIC_LABEL or "v"
if g.VIC_STOP then pcall(g.VIC_STOP) end
local rows, started, last = {}, os.clock(), {}
local function r1(v) return math.floor(v * 10 + 0.5) / 10 end
local conn
local function finish()
	if conn then conn:Disconnect(); conn = nil end
	pcall(writefile, "monster-build/results/victim_" .. label .. ".json", Http:JSONEncode({ label = label, me = lp.Name, seconds = os.clock() - started, rows = rows }))
	g.VIC_DONE = label .. ":" .. #rows
end
g.VIC_STOP, g.VIC_DONE = finish, nil
conn = RunService.Heartbeat:Connect(function()
	local c = lp.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local be = c and c:FindFirstChild("BodyEffects")
	local armor = be and be:FindFirstChild("Armor")
	local ko = be and be:FindFirstChild("K.O")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local hp, ar, k = hum and r1(hum.Health) or -1, armor and r1(armor.Value) or -1, ko and ko.Value or false
	if hp ~= last.hp or ar ~= last.ar or k ~= last.k or (root and last.p == nil) then
		last = { hp = hp, ar = ar, k = k, p = true }
		rows[#rows + 1] = { st = workspace:GetServerTimeNow(), hp = hp, armor = ar, ko = k, pos = root and { r1(root.Position.X), r1(root.Position.Y), r1(root.Position.Z) } or nil }
	end
	if os.clock() - started >= seconds then finish() end
end)
return "victim watch " .. label .. " for " .. seconds .. " s"
