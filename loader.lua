-- ============================================================================
--  MONSTER  -  BasedHub, reskinned
--
--  Loads BasedHub and dresses it as MONSTER: the crimson scheme, the name, the
--  MONSTER intro film (cut to its own track), the Johan film on Home (60 fps), and that
--  same Home film as a second intro (MONSTER II in Settings, under Intro).
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
local INTRO = film("monster", "mon3", 60, 1620)
local BOARD = film("monsterboard", "mob3", 60, 1140)

local function onDisk(path)
	local ok, yes = pcall(isfile, "BasedHub/" .. path)
	return ok and yes == true
end
local introOnDisk = onDisk("monster/hd/mon3_h_0000.jpg")

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
-- Anti Report (BasedHub 20261103.1917) names who reported you as "@username reported you", on its pop-up and
-- on the card it shows when it takes you out. Here it reads the person's display name instead: from the
-- player when they are in the server, else looked up by name (that waits, so the label is changed when it
-- comes). The Roblox kick box has its own text, which this does not touch.
local Players = game:GetService("Players")
local displayNames = {}
local function displayOf(name)
	if displayNames[name] then return displayNames[name] end
	local player = Players:FindFirstChild(name)
	if player and player:IsA("Player") then displayNames[name] = player.DisplayName; return player.DisplayName end
	return nil
end
local function lookUp(name, label)
	task.spawn(function()
		local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
		if not (ok and id) then return end
		local okInfo, infos = pcall(function() return game:GetService("UserService"):GetUserInfosByUserIdsAsync({ id }) end)
		local shown = okInfo and infos and infos[1] and infos[1].DisplayName
		if not shown or shown == "" then return end
		displayNames[name] = shown
		if label.Parent and label.Text == "@" .. name .. " reported you" then label.Text = shown .. " reported you" end
	end)
end
local function fix(label)
	local reporter = string.match(label.Text, "^@([%w_]+) reported you$")
	if reporter then
		local shown = displayOf(reporter)
		if shown then label.Text = shown .. " reported you" else lookUp(reporter, label) end
		return
	end
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

-- ---- The films: MONSTER plays where the brand film did; the Home board plays the Johan film.
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

-- ---- A second MONSTER intro: the Home film, played whole with its own track before the hub.
-- It is "MONSTER II" in Settings, under Intro, and in Shuffle. It plays through the brand
-- slot's player, with the Home film lent to that slot for the one run.
local HOME_INTRO, HOME_LABEL = "monsterhome", "MONSTER II"
local baseRun = Loader and Loader.run
local Controls = B.Controls
local baseDropdown = Controls and Controls.dropdown
if boardReady and baseRun and Loader.others and B.FILMS then
	Loader.others[HOME_INTRO] = function(done)
		local brandWas = B.FILMS.brand
		B.FILMS.brand = BOARD
		Loader.active = false           -- (set for this intro by the hub; the brand run sets it again)
		local ok = pcall(baseRun, function()
			B.FILMS.brand = brandWas
			done()
		end, "brand")
		if not ok then
			B.FILMS.brand = brandWas
			done()
		end
	end
	if Loader.SHUFFLE and not table.find(Loader.SHUFFLE, HOME_INTRO) then table.insert(Loader.SHUFFLE, HOME_INTRO) end
	if baseDropdown then
		Controls.dropdown = function(section, spec)
			if type(spec) == "table" and spec.id == "app.intro" and type(spec.options) == "table" then
				local options, added = {}, false
				for _, option in ipairs(spec.options) do
					options[#options + 1] = option
					if option[1] == HOME_INTRO then added = true end
				end
				if not added then table.insert(options, 2, { HOME_INTRO, HOME_LABEL }) end   -- (right after MONSTER)
				spec = table.clone(spec)
				spec.options = options
			end
			return baseDropdown(section, spec)
		end
	end
end

-- The brand slot is MONSTER's: without its film on this PC it plays nothing, never BasedHub's own.
local function launchIntro(chosen)
	if chosen == "brand" and not introReady then return "off" end
	return chosen
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
			return run(done, launchIntro(introWas or B.Config.get("app.intro")), ...)
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
	local chosen = launchIntro(Config.get("app.intro"))
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

-- ---- Home: the card's still is a frame of the Johan film (shown until the film runs).
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
	local id = boardReady and B.Assets.id("monsterboard/mob3_still.jpg")
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

-- ---- The window: a rim and a blood line along the top edge that beat like a heart.
-- Nothing lies over the window's contents, and nothing here takes a click.
task.spawn(function()
	local stage = GUI:FindFirstChild("Stage", true)
	local windowFrame = stage and stage:FindFirstChild("Window")
	if not windowFrame then return end
	local root = windowFrame:FindFirstChild("Root")
	local rootCorner = root and root:FindFirstChildOfClass("UICorner")

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
	end)
end)

-- ---- The ragebot: MONSTER's own tactics, measured 2026-11-03 against the Visions hook on two accounts
-- in Da Hood (120 s duels). Visions follows its target, into the void too: with Lure on, MONSTER shows
-- for a blink, Visions comes out after it and is pounced where it lands (8-0 against a friend's Visions
-- config; with Lure off both only waited in the void, 0-0, and waiting in the sky lost 1-6). The lure
-- shows longer, fires longer and comes back sooner, the pounce reaches 150 studs out (where a tuned
-- Visions keeps itself) and claims 24 places a try. Against the hardest Visions found: 9-0 and 3-0,
-- never knocked. (Against BasedHub's Main preset, which waits instead of following, Lure off won.)
-- Put in quietly, and only where the setting is still BasedHub's own: nothing is written to the config
-- files every account on this PC shares, and a setting you change yourself is never touched again
-- (kept in monster_rage.json: one you put back to BasedHub's own would not be saved by the hub).
local RAGE = {
	["dahood.lure"] = true,
	["dahood.ringLure"] = true,
	["dahood.bait"] = true,
	["dahood.flakOpen"] = true,
	["dahood.padTrap"] = true,
	["dahood.seen"] = 0,
	["dahood.arrive"] = 0.05,
	["dahood.swarmHold"] = 0.08,
	["dahood.k.LURE_SHOW"] = 0.25,
	["dahood.k.LURE_FIRE"] = 0.8,
	["dahood.k.LURE_FIRE_COMER"] = 1.6,
	["dahood.k.LURE_REST"] = 0.6,
	["dahood.k.LURE_HUSH"] = 5,
	["dahood.k.LURE_BALL"] = 60,
	["dahood.k.POUNCE_OUT"] = 150,
	["dahood.k.POUNCE_STAY"] = 0.5,
	["dahood.k.POUNCE_MARKS"] = 24,
	["dahood.k.POUNCE_HIGH"] = 200,
	["dahood.k.AMBUSH_LEAST"] = 3,
}
local RAGE_KEPT = "monster_rage.json"
task.spawn(function()
	local Http = game:GetService("HttpService")
	local yours = {}
	pcall(function()
		if isfile(RAGE_KEPT) then yours = Http:JSONDecode(readfile(RAGE_KEPT)) end
	end)
	if type(yours) ~= "table" then yours = {} end
	local DH = B.DaHood
	local giveUp = os.clock() + 60
	while not (DH and DH.options and DH.TUNE and DH.TUNE[1] and DH.TUNE[1].id) and os.clock() < giveUp and GUI.Parent do
		task.wait(0.25)
		DH = B.DaHood
	end
	if not (DH and DH.options) then return end      -- (another game: no ragebot)
	for id, value in pairs(RAGE) do
		if not yours[id] and Config.get(id) ~= nil and Config.isDefault(id) then Config.set(id, value, true) end
	end
	-- (a change made in the menu, or by a preset, is yours from then on)
	Config.changed:connect(function(id)
		if RAGE[id] == nil or yours[id] then return end
		yours[id] = true
		pcall(writefile, RAGE_KEPT, Http:JSONEncode(yours))
	end)
end)

-- ---- Unload: nothing of MONSTER's is left behind
local unload = B.unload
if unload then
	B.unload = function(...)
		renamer:Disconnect()
		for _, connection in ipairs(adopted) do connection:Disconnect() end
		if Loader and Loader.others then Loader.others[HOME_INTRO] = nil end
		if Loader and Loader.SHUFFLE then
			local at = table.find(Loader.SHUFFLE, HOME_INTRO)
			if at then table.remove(Loader.SHUFFLE, at) end
		end
		if baseDropdown and Controls then Controls.dropdown = baseDropdown end
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
