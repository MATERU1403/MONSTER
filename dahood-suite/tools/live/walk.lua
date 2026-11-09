-- walk forward (W) for RIG_SECONDS (default 2.5) with real key events, then stop
local vim = game:GetService("VirtualInputManager")
local seconds = getgenv().RIG_SECONDS or 2.5
vim:SendKeyEvent(true, Enum.KeyCode.W, false, game)
task.wait(seconds)
vim:SendKeyEvent(false, Enum.KeyCode.W, false, game)
local r = game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
return "walked", seconds, r and tostring(r.Position)
