-- jump RIG_COUNT (default 3) times, 0.9 s apart, with real key events
local vim = game:GetService("VirtualInputManager")
local count = getgenv().RIG_COUNT or 3
for _ = 1, count do
	vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
	task.wait(0.1)
	vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	task.wait(0.8)
end
return "jumped", count
