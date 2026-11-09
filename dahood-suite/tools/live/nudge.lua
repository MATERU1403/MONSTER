-- a standing body sends no 0xA1: a 0.02-stud CFrame shift each frame for RIG_SECONDS (default 3) makes it send (measured 2026-11-07)
local RunService = game:GetService("RunService")
local seconds = getgenv().RIG_SECONDS or 3
local lp = game.Players.LocalPlayer
local sign, untilT = 1, os.clock() + seconds
local conn
conn = RunService.PreSimulation:Connect(function()
	local c = lp.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if os.clock() > untilT or not r then conn:Disconnect(); return end
	sign = -sign
	r.CFrame = r.CFrame + Vector3.new(0.02 * sign, 0, 0)
end)
return "nudging", seconds
