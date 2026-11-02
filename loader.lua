-- ============================================================================
--  MONSTER  -  BasedHub, reskinned
--
--  Loads BasedHub and dresses it as MONSTER: the crimson scheme, the name, the
--  MONSTER intro film (cut to its own track) and the Salvatore film on Home.
--  Visuals only: BasedHub's features, tabs and layout are left as they are.
--
--  The films sit where BasedHub keeps its own, as frame sequences under
--  workspace/BasedHub/monster (the intro) and workspace/BasedHub/monsterboard.
-- ============================================================================
local genv = getgenv()
local RunService = game:GetService("RunService")
local host = gethui()

local function film(folder, tag, fps, count)
	local function half(side, x, rectX)
		return { path = folder .. "/ultra/" .. tag .. "_" .. side .. "_", x = x, w = 0.5, rectX = rectX, rectW = 910, texW = 912 }
	end
	return {
		version = 1, fps = fps, count = count, duration = count / fps, audio = folder .. "/" .. tag .. "_audio.ogg",
		sets = {
			hd = { width = 1024, height = 576, digits = 4, tiles = { { path = folder .. "/hd/" .. tag .. "_h_", x = 0, w = 1, rectX = 0, rectW = 1024, texW = 1024 } } },
			ultra = { width = 1820, height = 1024, digits = 4, tiles = { half("l", 0, 0), half("r", 0.5, 2) } },
		},
	}
end
local INTRO = film("monster", "mon1", 60, 1596)
local BOARD = film("monsterboard", "mob1", 30, 496)

local function onDisk(path)
	local ok, yes = pcall(isfile, "BasedHub/" .. path)
	return ok and yes == true
end
local introOnDisk = onDisk("monster/hd/mon1_h_0000.jpg")

-- ---- The name: every BasedHub label that carries it reads MONSTER, from the loading screen on.
-- BasedHub redraws some of them (the dropdowns), so each one keeps a watch on its own text.
local NAMES = { ["BASED"] = "MONSTER", ["BASED HUB"] = "MONSTER" }
if introOnDisk then NAMES["BASED brand film"] = "MONSTER" end
local watched = setmetatable({}, { __mode = "k" })

local function dropHub(nameLabel)
	local parent = nameLabel.Parent
	if not parent then return end
	for _, sibling in ipairs(parent:GetChildren()) do
		if sibling:IsA("TextLabel") and sibling.Text == "hub" then sibling.Visible = false end
	end
end
local function fix(label)
	local to = NAMES[label.Text]
	if to then label.Text = to end
	if label.Text == "MONSTER" then dropHub(label) end
end
local function watch(item)
	if watched[item] or not (item:IsA("TextLabel") or item:IsA("TextButton")) then return end
	local parent = item.Parent
	if not (NAMES[item.Text] or (parent and parent.Name == "Select")) then return end
	watched[item] = true
	fix(item)
	item:GetPropertyChangedSignal("Text"):Connect(function() fix(item) end)
end
local renamer = host.DescendantAdded:Connect(function(item)
	if item:IsA("TextLabel") or item:IsA("TextButton") then task.defer(watch, item) end
end)

-- ---- BasedHub. Its own launch intro is held off for this one launch: the MONSTER one takes its place.
local introWas = genv.BASED_INTRO
genv.BASED_INTRO = "off"
loadstring(game:HttpGet("https://raw.githubusercontent.com/Mrzaytoon/based-hub/main/loader.lua"))()

local deadline = os.clock() + 30
while not genv.BASED and os.clock() < deadline do RunService.Heartbeat:Wait() end
local B = genv.BASED
if not B then
	genv.BASED_INTRO = introWas
	renamer:Disconnect()
	warn("[MONSTER] BasedHub did not load")
	return
end
local Film, Loader, Board = B.Film, B.Loader, B.Board

-- ---- The films: MONSTER plays where the brand film did; the Home board plays the Salvatore film.
local introReady = Film and (Film.has("ultra", INTRO) or Film.has("hd", INTRO))
local boardReady = Film and (Film.has("ultra", BOARD) or Film.has("hd", BOARD))
if introReady and B.FILMS then B.FILMS.brand = INTRO end
if boardReady and Board then
	Board.spec = BOARD
	-- players already made from the old film are let go; the board makes new ones from this one
	for _, key in ipairs({ "film", "big" }) do
		local player = Board[key]
		if player and not player.dead then player:destroy() end
	end
end

-- Catch BasedHub's own call for its launch intro, when it has not been made yet, and play the
-- chosen one (MONSTER, unless another was picked in Settings) before the hub comes up.
local played, caught = false, false
local run = Loader and Loader.run
if run then
	Loader.run = function(done, override, ...)
		if not played and override == nil then
			played, caught = true, true
			genv.BASED_INTRO = introWas
			return run(done, introWas or B.Config.get("app.intro"), ...)
		end
		return run(done, override, ...)
	end
end

deadline = os.clock() + 60
while rawget(B, "bootMs") == nil and os.clock() < deadline do RunService.Heartbeat:Wait() end
genv.BASED_INTRO = introWas

local Theme, T, UI, Window, Config = B.Theme, B.T, B.UI, B.Window, B.Config
local hex = B.util.hex
local GUI = Window.gui

-- ---- Too late to catch it (BasedHub was already up): hide the hub, play the intro, bring it back.
if run and not played then
	played = true
	local chosen = Config.get("app.intro")
	if chosen ~= "off" then
		Window.showActive(false)
		run(function() Window.showActive(true) end, chosen)
	end
end

-- ---- Colour: pitch-black base, bone ink, blood-red accent
Theme.schemes.monster = {
	label = "Monster",
	base  = hex("050208"),
	ink   = hex("E8E0D4"),
	sub   = hex("8B7E72"),
	faint = hex("4A3F3A"),
	shadow = 0.25,
	fill   = { 0.06, 0.10, 0.15 },
	stroke = { 0.12, 0.22 },
	dark   = true,
}
table.insert(Theme.schemeOrder, "monster")
table.insert(Theme.accents, 1, { id = "crimson", label = "Crimson", color = hex("8B0000") })
Theme.set({ scheme = "monster", accent = hex("8B0000"), glass = 0.85, radius = 0.8 })
T.ok   = hex("3D8B37")
T.warn = hex("C9842A")
T.bad  = hex("DC143C")

-- ---- Home: the card's still is the Salvatore film's own opening frame (shown until the film runs)
task.spawn(function()
	local still
	for _, item in ipairs(GUI:GetDescendants()) do
		if item.Name == "Still" and item:IsA("ImageLabel") and item.Parent and item.Parent.Name == "Hero" then still = item; break end
	end
	if not still then return end
	local id = boardReady and B.Assets.id("monsterboard/mob1_still.jpg")
	if not id then
		local ok, data = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/MATERU1403/MONSTER/main/cinematic/damon_dark.jpg")
		if ok and type(data) == "string" and #data > 100 then
			writefile("monster_hero.jpg", data)
			id = getcustomasset("monster_hero.jpg")
		end
	end
	if id then
		still.Image = id
		still.ScaleType = Enum.ScaleType.Crop
	end
end)

-- ---- Fonts: heavier headings
task.spawn(function()
	local F = B.F
	if not F then return end
	local ok, bold = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Bold)
	local ok2, heavy = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Heavy)
	if ok then
		F.text600 = bold
		if ok2 then F.text700 = heavy end
	end
	if UI and UI.sweepFonts then
		task.wait(0.3)
		UI.sweepFonts()
	end
end)

-- ---- The window: edge vignette, a breathing blood line on top, a heavier shadow below
task.spawn(function()
	local stage = GUI:FindFirstChild("Stage", true)
	local windowFrame = stage and stage:FindFirstChild("Window")
	if not windowFrame then return end

	local function frame(name, props, gradient)
		local item = Instance.new("Frame")
		item.Name = name
		item.BorderSizePixel = 0
		for key, value in pairs(props) do item[key] = value end
		if gradient then
			local grad = Instance.new("UIGradient")
			grad.Transparency = NumberSequence.new(gradient)
			grad.Rotation = 90
			grad.Parent = item
		end
		item.Parent = windowFrame
		return item
	end
	local key = NumberSequenceKeypoint.new
	frame("MonsterVignette", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 0, 0), BackgroundTransparency = 0.88, ZIndex = 900 },
		{ key(0, 0), key(0.3, 0.85), key(0.7, 0.85), key(1, 0) })
	local line = frame("MonsterBloodLine", { Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Color3.fromRGB(139, 0, 0), BackgroundTransparency = 0.3, ZIndex = 950 })
	local glow = frame("MonsterBloodGlow", { Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(139, 0, 0), BackgroundTransparency = 0.92, ZIndex = 899 },
		{ key(0, 0), key(1, 1) })
	frame("MonsterShadow", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), BackgroundColor3 = Color3.fromRGB(5, 2, 8), BackgroundTransparency = 0.7, ZIndex = 899 },
		{ key(0, 1), key(1, 0) })

	local phase, direction = 0, 1
	local pulse
	pulse = RunService.Heartbeat:Connect(function(dt)
		if not windowFrame.Parent then pulse:Disconnect(); return end
		phase = phase + dt * 0.4 * direction
		if phase >= 1 then phase, direction = 1, -1 elseif phase <= 0 then phase, direction = 0, 1 end
		local t = 0.15 * (0.5 - 0.5 * math.cos(phase * math.pi))
		line.BackgroundTransparency = 0.3 - t
		glow.BackgroundTransparency = 0.92 - t * 0.5
	end)
end)

-- ---- Unload: nothing of MONSTER's is left behind
local unload = B.unload
if unload then
	B.unload = function(...)
		renamer:Disconnect()
		pcall(function()
			for _, item in ipairs(GUI:GetDescendants()) do
				if string.sub(item.Name, 1, 7) == "Monster" then item:Destroy() end
			end
		end)
		Theme.schemes.monster = nil
		return unload(...)
	end
end

task.spawn(function()
	while Loader and Loader.active do task.wait(0.2) end
	task.wait(0.6)
	if B.Toast and B.Toast.note then
		B.Toast.note({ icon = "skull", text = "MONSTER loaded", sub = "Dark crimson \194\183 Gothic \194\183 Atmospheric" })
	end
end)

warn("[MONSTER] v3 loaded: intro=" .. tostring(introReady) .. " board=" .. tostring(boardReady) .. " caught=" .. tostring(caught))
