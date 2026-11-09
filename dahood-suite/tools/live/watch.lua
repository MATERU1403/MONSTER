-- The watching client: log how the engine shows another player's body, every Heartbeat, for RIG_SECONDS. Read only.
-- Globals: RIG_WHO (player name), RIG_SECONDS (default 8), RIG_LABEL. Writes monster-build/results/watch_<label>.json when done.
local g = getgenv()
local Http = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local who, seconds, label = g.RIG_WHO or "morrowindf", g.RIG_SECONDS or 8, g.RIG_LABEL or "w"
if g.WATCH_STOP then pcall(g.WATCH_STOP) end
local rows, started = {}, os.clock()
local function r2(v) return math.floor(v * 100 + 0.5) / 100 end
local conn
local function finish()
	if conn then conn:Disconnect(); conn = nil end
	pcall(writefile, "monster-build/results/watch_" .. label .. ".json", Http:JSONEncode({
		label = label, who = who, me = Players.LocalPlayer.Name, seconds = os.clock() - started, rows = rows,
		ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue(),
	}))
	g.WATCH_DONE = label .. ":" .. #rows
end
g.WATCH_STOP = finish
g.WATCH_DONE = nil
conn = RunService.Heartbeat:Connect(function()
	local p = Players:FindFirstChild(who)
	local c = p and p.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root then
		local pos, vel = root.Position, root.AssemblyLinearVelocity
		local row = { t = workspace:GetServerTimeNow(), x = r2(pos.X), y = r2(pos.Y), z = r2(pos.Z), vx = r2(vel.X), vy = r2(vel.Y), vz = r2(vel.Z) }
		local parts = {}
		for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso" }) do
			local part = c:FindFirstChild(name)
			if part then parts[name] = { r2(part.Position.X), r2(part.Position.Y), r2(part.Position.Z) } end
		end
		row.parts = parts
		local hum = c:FindFirstChildOfClass("Humanoid")
		if hum then row.hp = r2(hum.Health) end
		rows[#rows + 1] = row
	end
	if os.clock() - started >= seconds then finish() end
end)
return "watching " .. who .. " for " .. seconds .. " s as " .. label
