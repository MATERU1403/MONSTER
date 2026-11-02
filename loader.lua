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
-- (Roblox keeps a registered file by its name for good: a re-cut film gets a new tag)
local INTRO = film("monster", "mon2", 60, 1686)
local BOARD = film("monsterboard", "mob1", 30, 496)

local function onDisk(path)
	local ok, yes = pcall(isfile, "BasedHub/" .. path)
	return ok and yes == true
end
local introOnDisk = onDisk("monster/hd/mon2_h_0000.jpg")

-- ---- The name: BASED reads MONSTER in every word BasedHub shows, from the loading screen on.
-- Its text changes as it is used (dropdowns, tips, toasts), so every label keeps a watch on its own.
local WHOLE = { ["BASED HUB"] = "MONSTER" }
if introOnDisk then WHOLE["BASED brand film"] = "MONSTER" end
local function renamed(text)
	local whole = WHOLE[text]
	if whole then return whole end
	if not string.find(text, "BASED", 1, true) then return nil end
	return (string.gsub(string.gsub(text, "BASED HUB", "MONSTER"), "BASED", "MONSTER"))
end

-- the wordmark (the name with "hub" beside it): dripping letters in blood
local styled = setmetatable({}, { __mode = "k" })
local function bloodName(label)
	if styled[label] then return end
	styled[label] = true
	local ok, creepster = pcall(Font.fromEnum, Enum.Font.Creepster)
	if ok then
		label.FontFace = creepster
		local B = genv.BASED
		if B and B.UI and B.UI.fontKey then B.UI.fontKey[label] = nil end   -- (the hub's font sweeps leave it be)
	end
	if label.TextSize >= 15 and label.TextSize < 22 then label.TextSize = 22 end   -- (the sidebar's: its letters are thin)
	local blood = Instance.new("UIGradient")
	blood.Name = "MonsterBlood"
	blood.Color = ColorSequence.new(Color3.fromRGB(255, 96, 96), Color3.fromRGB(205, 0, 26))
	blood.Rotation = 90
	blood.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Name = "MonsterEdge"
	edge.Color = Color3.fromRGB(45, 0, 4)
	edge.Thickness = 1
	edge.Transparency = 0.3
	edge.Parent = label
end
local function dropHub(nameLabel)
	local parent = nameLabel.Parent
	if not parent then return end
	for _, sibling in ipairs(parent:GetChildren()) do
		if sibling:IsA("TextLabel") and sibling.Text == "hub" then
			sibling.Visible = false
			bloodName(nameLabel)
		end
	end
end
local function fix(label)
	local to = renamed(label.Text)
	if to and to ~= label.Text then label.Text = to end
	if label.Text == "MONSTER" then dropHub(label) end
end
local watched = setmetatable({}, { __mode = "k" })
local function watch(item)
	if watched[item] or not (item:IsA("TextLabel") or item:IsA("TextButton")) then return end
	watched[item] = true
	fix(item)
	item:GetPropertyChangedSignal("Text"):Connect(function() fix(item) end)
end
-- BasedHub's screens (and its loading screen) are the ones made under the hidden UI from now on
local adopted = {}
local renamer = host.ChildAdded:Connect(function(child)
	task.defer(function()
		if not child:IsA("LayerCollector") then return end
		for _, item in ipairs(child:GetDescendants()) do watch(item) end
		adopted[#adopted + 1] = child.DescendantAdded:Connect(function(item)
			if item:IsA("TextLabel") or item:IsA("TextButton") then task.defer(watch, item) end
		end)
	end)
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

-- ---- Colour: black with blood under it, bone ink, fresh blood for every accent
Theme.schemes.monster = {
	label = "Monster",
	base  = hex("070103"),
	ink   = hex("EDE3DA"),
	sub   = hex("A98D87"),
	faint = hex("74494C"),
	shadow = 0.32,
	fill   = { 0.06, 0.10, 0.15 },
	stroke = { 0.12, 0.22 },
	dark   = true,
}
table.insert(Theme.schemeOrder, "monster")
table.insert(Theme.accents, 1, { id = "blood", label = "Blood", color = hex("B0001E") })
Theme.set({ scheme = "monster", accent = hex("B0001E"), glass = 0.9, radius = 0.8 })
T.ok   = hex("4E8A3E")
T.warn = hex("C9842A")
T.bad  = hex("E0142E")

-- ---- Home: the card's still is a frame of the Salvatore film (shown until the film runs).
-- The Home tab is built a little after BasedHub is up, so it is waited for.
task.spawn(function()
	local still
	local giveUp = os.clock() + 30
	while not still and os.clock() < giveUp and GUI.Parent do
		for _, item in ipairs(GUI:GetDescendants()) do
			if item.Name == "Still" and item:IsA("ImageLabel") and item.Parent and item.Parent.Name == "Hero" then still = item; break end
		end
		if not still then task.wait(0.5) end
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
		still:GetPropertyChangedSignal("Image"):Connect(function()
			if still.Image ~= id then still.Image = id end
		end)
	end
end)

-- ---- Letters: page titles in a blackletter, headings heavier, the wordmark in blood (above)
task.spawn(function()
	local F, F0 = B.F, rawget(B, "F0")
	if not F then return end
	local ok, gothic = pcall(Font.fromEnum, Enum.Font.GrenzeGotisch)
	if ok then
		local faces = { serifItalic = Font.new(gothic.Family, Enum.FontWeight.Bold), serif = Font.new(gothic.Family, Enum.FontWeight.SemiBold) }
		for key, face in pairs(faces) do
			F[key] = face
			if F0 then F0[key] = face end            -- (kept when the hub's own font setting is changed)
		end
		for label, key in pairs(UI.fontKey or {}) do
			if faces[key] and label.Parent then label.FontFace = faces[key] end
		end
	end
	local okBold, bold = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Bold)
	local okHeavy, heavy = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Heavy)
	if okBold then F.text600 = bold end
	if okHeavy then F.text700 = heavy end
	if UI.sweepFonts then
		task.wait(0.3)
		UI.sweepFonts()
	end
end)

-- ---- The window: a rim that beats like a heart and blood running from the top edge and
-- dripping off. Nothing lies over the window's contents, and nothing here takes a click.
task.spawn(function()
	local stage = GUI:FindFirstChild("Stage", true)
	local windowFrame = stage and stage:FindFirstChild("Window")
	if not windowFrame then return end
	local root = windowFrame:FindFirstChild("Root")
	local rootCorner = root and root:FindFirstChildOfClass("UICorner")

	local key = NumberSequenceKeypoint.new
	local function frame(name, props, gradient, rotation)
		local item = Instance.new("Frame")
		item.Name = name
		item.BorderSizePixel = 0
		item.Active = false
		for prop, value in pairs(props) do item[prop] = value end
		if gradient then
			local grad = Instance.new("UIGradient")
			grad.Transparency = NumberSequence.new(gradient)
			grad.Rotation = rotation or 90
			grad.Parent = item
		end
		item.Parent = windowFrame
		return item
	end
	local function round(item, radius)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = radius or UDim.new(1, 0)
		corner.Parent = item
	end
	local BLOOD = Color3.fromRGB(150, 0, 18)

	local rim = frame("MonsterRim", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 952 })
	round(rim, rootCorner and rootCorner.CornerRadius or UDim.new(0, 18))
	local rimStroke = Instance.new("UIStroke")
	rimStroke.Color = Color3.fromRGB(175, 0, 24)
	rimStroke.Thickness = 1.5
	rimStroke.Transparency = 0.7
	rimStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rimStroke.Parent = rim
	local line = frame("MonsterBloodLine", { Size = UDim2.new(0.94, 0, 0, 2), Position = UDim2.fromScale(0.03, 0), BackgroundColor3 = BLOOD, BackgroundTransparency = 0.3, ZIndex = 951 })

	-- the drips: each runs down from the top edge, swells, lets a drop go, and runs again
	local rng = Random.new()
	local drips = {}
	local COUNT = 13
	for i = 1, COUNT do
		local x = 0.05 + 0.9 * (i - 0.5 + rng:NextNumber(-0.3, 0.3)) / COUNT
		local width = rng:NextInteger(2, 5)
		local body = frame("MonsterDrip", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(x, 0, 0, 1), Size = UDim2.fromOffset(width, 0),
			BackgroundColor3 = BLOOD, BackgroundTransparency = 0.12, ZIndex = 953 }, { key(0, 0), key(1, 0.25) })
		round(body)
		local tip = frame("MonsterDripTip", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(width + 2, width + 3),
			BackgroundColor3 = Color3.fromRGB(125, 0, 14), BackgroundTransparency = 0.1, ZIndex = 953 })
		round(tip)
		local drop = frame("MonsterDrop", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(width + 1, width + 3),
			BackgroundColor3 = Color3.fromRGB(125, 0, 14), Visible = false, ZIndex = 953 })
		round(drop)
		drips[i] = { body = body, tip = tip, drop = drop, x = x, width = width, len = rng:NextNumber(0, 10), reach = rng:NextNumber(10, 44),
			speed = rng:NextNumber(1.2, 4.5), rest = rng:NextNumber(0, 5), fall = nil, from = 0 }
	end

	local clock = 0
	local loop
	loop = RunService.Heartbeat:Connect(function(dt)
		if not windowFrame.Parent then loop:Disconnect(); return end
		if not Window.open then return end
		clock = clock + dt
		-- lub-dub, about 52 a minute
		local p = clock % 1.15
		local heart = math.exp(-(p / 0.075) ^ 2) + 0.65 * math.exp(-((p - 0.24) / 0.075) ^ 2)
		rimStroke.Transparency = 0.72 - 0.5 * heart
		line.BackgroundTransparency = 0.38 - 0.3 * heart
		for _, d in ipairs(drips) do
			if d.rest > 0 then
				d.rest = d.rest - dt
			elseif d.fall then
				d.fall = d.fall + dt
				local y = d.from + 0.5 * 1100 * d.fall * d.fall
				d.drop.Position = UDim2.new(d.x, 0, 0, y)
				d.drop.BackgroundTransparency = math.min(1, 0.1 + d.fall / 0.55)
				if d.fall > 0.55 then
					d.drop.Visible, d.fall = false, nil
					d.reach, d.speed, d.rest = rng:NextNumber(10, 44), rng:NextNumber(1.2, 4.5), rng:NextNumber(1.5, 7)
				end
			else
				d.len = math.min(d.reach, d.len + d.speed * dt * (0.35 + d.len / d.reach))
				if d.len >= d.reach then
					d.fall, d.from = 0, d.len + 1
					d.drop.Position = UDim2.new(d.x, 0, 0, d.from)
					d.drop.Visible = true
					d.len = d.len * 0.6
				end
			end
			d.body.Size = UDim2.fromOffset(d.width, d.len)
			d.tip.Position = UDim2.new(d.x, 0, 0, d.len)
			d.tip.Visible = d.len > 2
		end
	end)
end)

-- ---- Unload: nothing of MONSTER's is left behind
local unload = B.unload
if unload then
	B.unload = function(...)
		renamer:Disconnect()
		for _, connection in ipairs(adopted) do connection:Disconnect() end
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
		B.Toast.note({ icon = "skull", text = "MONSTER loaded", sub = "Blood \194\183 Gothic \194\183 Dark" })
	end
end)

warn("[MONSTER] v4 loaded: intro=" .. tostring(introReady) .. " board=" .. tostring(boardReady) .. " caught=" .. tostring(caught))
