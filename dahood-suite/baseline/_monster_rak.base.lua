-- ============================================================================
--  MONSTER  -  BasedHub, reskinned
--
--  Loads BasedHub and dresses it as MONSTER: the crimson scheme, the name, the
--  MONSTER intro film (cut to its own track), the Johan film on Home (60 fps), and that
--  same Home film as a second intro (MONSTER II in Settings, under Intro).
--  Visuals only: BasedHub's features, tabs and layout are left as they are.
--
--  The films sit where BasedHub keeps its own, as frame sequences under
--  workspace/BasedHub/monster (the intro) and workspace/BasedHub/monsterboard. MONSTER II
--  (the Home film) is downloaded from this repo's films/ the first time a PC does not have it,
--  and is the launch intro until another is picked in Settings.
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

-- ---- A second MONSTER intro: the Home film, played whole with its own track before the hub.
-- It is "MONSTER II" in Settings, under Intro, and in Shuffle. It plays through the brand
-- slot's player, with the Home film lent to that slot for the one run.
local HOME_INTRO, HOME_LABEL = "monsterhome", "MONSTER II"
local baseRun = Loader and Loader.run
local Controls = B.Controls
local baseDropdown = Controls and Controls.dropdown
-- the Home film is on this PC: the board plays it, and MONSTER II can be played
local function boardUp()
	if Board then
		Board.spec = BOARD
		-- players already made from the old film are let go; the board makes new ones from this one
		for _, key in ipairs({ "film", "big" }) do
			local player = Board[key]
			if player and not player.dead then player:destroy() end
		end
	end
	if baseRun and Loader.others and B.FILMS then
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
	end
end
if boardReady then boardUp() end
-- (in the list whether or not its film is here yet: it is downloaded below, and the list is made once)
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

-- MONSTER II is the launch intro: made so once, on an install still on BasedHub's own (the brand
-- slot, MONSTER). Whatever is picked in Settings after that is kept.
local INTRO_PICKED = "MONSTER/intro_ii.picked"
local function startingIntro(chosen)
	if introWas ~= nil or chosen ~= "brand" then return chosen end
	local okSeen, seen = pcall(isfile, INTRO_PICKED)
	if okSeen and seen then return chosen end
	pcall(function()
		if not isfolder("MONSTER") then makefolder("MONSTER") end
		writefile(INTRO_PICKED, "MONSTER II was made the launch intro once. Pick any other in Settings, under Intro.")
	end)
	pcall(B.Config.set, "app.intro", HOME_INTRO)
	return HOME_INTRO
end

-- The brand slot is MONSTER's: without its film on this PC it plays nothing, never BasedHub's own.
-- MONSTER II before its film is here (it is being downloaded): MONSTER this time.
local function launchIntro(chosen)
	if chosen == HOME_INTRO and not (Loader and Loader.others and Loader.others[HOME_INTRO]) then chosen = "brand" end
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
			return run(done, launchIntro(startingIntro(introWas or B.Config.get("app.intro"))), ...)
		end
		-- (Replay in Settings, or Shuffle's own pick: MONSTER II only once its film is here)
		if override == HOME_INTRO then override = launchIntro(override) end
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
	local chosen = launchIntro(startingIntro(Config.get("app.intro")))
	if chosen ~= "off" then
		Window.showActive(false)
		run(function() Window.showActive(true) end, chosen)
	end
end

-- ---- MONSTER II's film (the Home film), from this repo, the first time this PC does not have it.
-- films/monsterboard holds its frames joined into packs, and an index of each frame's length
-- (tools/pack_film.py): each pack is fetched whole and cut back into the frames BasedHub's film
-- player reads. HD always (the Home card plays it); Ultra too on a screen 800 tall or more.
local FILMS = "https://raw.githubusercontent.com/MATERU1403/MONSTER/main/films/"
local function fetchFilm(folder, tag, wantUltra)
	local Http = game:GetService("HttpService")
	local okIndex, body = pcall(game.HttpGet, game, FILMS .. folder .. "/" .. tag .. ".json")
	if not (okIndex and type(body) == "string") then return false, "no index" end
	local okJson, index = pcall(Http.JSONDecode, Http, body)
	if not (okJson and type(index) == "table" and type(index.packs) == "table") then return false, "a bad index" end
	local root = "BasedHub/" .. folder
	for _, dir in ipairs({ "BasedHub", root, root .. "/hd", root .. "/ultra" }) do
		if not isfolder(dir) then makefolder(dir) end
	end
	for _, name in ipairs(index.files or {}) do
		if not isfile(root .. "/" .. name) then
			local ok, data = pcall(game.HttpGet, game, FILMS .. folder .. "/" .. name)
			if not (ok and type(data) == "string" and #data > 0) then return false, name end
			writefile(root .. "/" .. name, data)
		end
	end
	for _, pack in ipairs(index.packs) do
		local frames = pack.frames
		-- (a pack is fetched again only when its first or last frame is missing: a download cut short)
		if (pack.set == "hd" or wantUltra) and not (isfile(root .. "/" .. frames[1][1]) and isfile(root .. "/" .. frames[#frames][1])) then
			local ok, data = pcall(game.HttpGet, game, FILMS .. folder .. "/" .. pack.name)
			if not (ok and type(data) == "string" and #data == pack.bytes) then return false, pack.name end
			local at = 1
			for n, frame in ipairs(frames) do
				writefile(root .. "/" .. frame[1], string.sub(data, at, at + frame[2] - 1))
				at = at + frame[2]
				if n % 24 == 0 then task.wait() end
			end
		end
	end
	return true
end
if Film and not boardReady then
	task.spawn(function()
		local camera = workspace.CurrentCamera
		local wantUltra = camera ~= nil and camera.ViewportSize.Y >= 800
		Window.toast({ title = "Downloading MONSTER II", text = wantUltra and "The Home film and intro, about 110 MB, once." or "The Home film and intro, about 35 MB, once.",
			icon = "download", time = 5 })
		local ok, done, why = pcall(fetchFilm, "monsterboard", "mob3", wantUltra)
		if ok and done then
			boardReady = true
			boardUp()
			Window.toast({ title = "MONSTER II is ready", text = "It plays on Home now, and as the launch intro from the next start.", icon = "film", time = 5 })
		else
			warn("[MONSTER] MONSTER II's film could not be downloaded: " .. tostring(ok and why or done))
		end
	end)
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

-- ---- The symbol: the fangs (logo/fangs.png, white on clear, tinted blood) left of the sidebar wordmark.
-- The sidebar is built with the window, so it is waited for; the picture is fetched once and kept on disk.
task.spawn(function()
	local brand
	local giveUp = os.clock() + 30
	while not brand and os.clock() < giveUp and GUI.Parent do
		for _, item in ipairs(GUI:GetDescendants()) do
			if item.Name == "Brand" and item:IsA("Frame") and item.Parent and item.Parent.Name == "Sidebar" then brand = item; break end
		end
		if not brand then task.wait(0.5) end
	end
	if not brand or brand:FindFirstChild("MonsterFangs") then return end
	local file = "monster_fangs_v1.png"
	if not (isfile and isfile(file)) then
		local ok, data = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/MATERU1403/MONSTER/main/logo/fangs.png")
		if not (ok and type(data) == "string" and #data > 100) then return end
		pcall(writefile, file, data)
	end
	local okId, id = pcall(getcustomasset, file)
	if not okId then return end
	local mark
	for _, item in ipairs(brand:GetChildren()) do
		if item:IsA("Frame") and item.AutomaticSize == Enum.AutomaticSize.X then mark = item; break end
	end
	local fangs = Instance.new("ImageLabel")
	fangs.Name = "MonsterFangs"
	fangs.BackgroundTransparency = 1
	fangs.Image = id
	fangs.ImageColor3 = Color3.fromRGB(205, 0, 26)
	fangs.ScaleType = Enum.ScaleType.Fit
	fangs.Size = UDim2.fromOffset(34, 16)
	fangs.Position = UDim2.fromOffset(16, 23)
	fangs.Parent = brand
	if mark then mark.Position = UDim2.fromOffset(56, mark.Position.Y.Offset) end
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

-- ---- Desync and Fake position (Da Hood), measured 2026-11-07 with two accounts 40 studs apart.
-- Raknet would be the clean way, but Potassium's send and receive hooks never fire yet (0 packets, on a
-- fresh connection too), so it is done with the body: after each physics step it is put where it should
-- be seen, and put back before the next step and before the frame is drawn. You walk, aim and see as
-- always; the server, and everyone with it, get the other place.
--  * The other screen saw the fake place 95-100% of the time (20 to the side, 40 under the map, a ring 40 out).
--  * A body standing still sends nothing (the server keeps what it last had), so each step gets a 0.02-stud
--    nudge while either is on, and for half a second after, so the real body goes out again too.
--  * Desync 40: 3 of 3 shots at what the other screen saw were refused. Held 40 under the map: 2 of 2 refused.
--  * Your own shots are checked from where the server has you, so they are refused while faked: both let
--    go while you hold anything, and the real body is back on the server before you fire.
--  * Humanoid:MoveTo stops while it runs (walking with the keys is fine), and the ragebot moves the body
--    itself: both step aside while it hunts.
-- On target (asked 2026-11-07 after a clip of exterminate's Fake position): the server is given the body
-- beside a target, and the gun is fired from there, since that is where the server checks shots from;
-- you stay where you are and see yourself there. A hop is waited out before the first shot (the server
-- refused shots for 0.1-0.2 s after one), and the side it sits on has a clear line to the target.
local Desync = {}
do
	local LP = B.LP
	local Players = game:GetService("Players")
	local DEFAULTS = {
		["monster.desync"] = false, ["monster.desyncRange"] = 40,
		["monster.fake"] = false, ["monster.fakeWhere"] = "decoy", ["monster.fakeDistance"] = 40, ["monster.fakeNear"] = 4, ["monster.ghostHeight"] = 120, ["monster.ghostJitter"] = 10, ["monster.decoyUp"] = 0,
		["monster.desyncTools"] = true, ["monster.desyncBox"] = true,
		["monster.fakeOffX"] = 0, ["monster.fakeOffY"] = 0, ["monster.fakeOffZ"] = 30,
		["monster.orbitRadius"] = 10, ["monster.orbitHeight"] = 0, ["monster.orbitSpeed"] = 6,
		["monster.rak"] = true, ["monster.rakRate"] = 30, ["monster.rakShoot"] = true, ["monster.rakFace"] = "you", ["monster.rakRage"] = true,
		["monster.voidStrike"] = true, ["monster.voidSpam"] = true, ["monster.voidArrive"] = 0.25, ["monster.strikeSpread"] = 12, ["monster.showLures"] = true,
	}
	for id, default in pairs(DEFAULTS) do Config.define(id, default) end

	-- ---- Raknet (Volt): the server is told where you are, the body stays where it is.
	-- Measured 2026-11-09 on Volt 1.3.21.2 with two accounts (morrowindf faking, gotham77r watching):
	--  * Da Hood sends your body as packet 0xA1: bytes 2-5 a 1/240 s stamp (older ones are dropped), 6-34 a
	--    header that stays the same for one body, 35-36 the payload length, then the payload.
	--  * Payload: one byte 0x60 + rotation id (0 = 6 rotation bytes follow), one byte e*8 + signs of X,Y,Z,
	--    three 16-bit axes (value = raw / 2^(16-e), minus 2^e when negative; e <= 10 so |coords| < 1024),
	--    then the rotation: a quaternion, 2-bit index of the largest part + three signed 15-bit parts.
	--  * Blocking 0xA1: the other screen saw the body frozen while it walked 25 studs. Crafted packets at
	--    real + 30: seen exactly 30 off, following it. Off: back to the real place at once.
	-- Void (2026-11-09): nothing past |coords| 1024 is ever crafted. That format packs the axes differently, and
	-- replaying far packets the engine had made got the account DISCONNECTED by the server (error 260, "problem
	-- receiving data", ~8 s in). The void stays inside the decoded format instead (see the Void step below).
	local Rak = { on = false, sent = 0, failed = 0, blocked = 0 }
	genv.MONSTER_RAK = Rak      -- (what a test reads)
	do
		Rak.available = type(raknet) == "table" and type(raknet.add_send_hook) == "function" and type(raknet.send) == "function"
		local header, lastStamp, lastClock, needHeader = nil, 0, 0, false
		local acc, want = 0, nil
		local function onSend(packet)
			if packet.PacketId ~= 0xA1 then return end
			local s = packet.AsString
			if #s < 36 then return end
			local stamp = string.unpack("<I4", s, 2)
			if stamp > lastStamp then lastStamp, lastClock = stamp, os.clock() end
			header, needHeader = string.sub(s, 1, 34), false
			if Rak.on then
				packet:Block()
				Rak.blocked += 1
			end
		end
		local function hook(packet) pcall(onSend, packet) end
		if Rak.available then
			if genv.MONSTER_RAK_HOOK then pcall(raknet.remove_send_hook, genv.MONSTER_RAK_HOOK) end
			Rak.available = pcall(raknet.add_send_hook, hook)
			if Rak.available then genv.MONSTER_RAK_HOOK = hook end
		end

		-- the body's packets carry its own header: a new body needs a new one before anything is sent
		local respawned = LP.CharacterAdded:Connect(function() header = nil end)

		local function axes(position)
			local big = math.max(math.abs(position.X), math.abs(position.Y), math.abs(position.Z))
			local e = 1
			while 2 ^ e <= big do e += 1 end
			if e > 10 then return nil end
			local scale, signs, out = 2 ^ (16 - e), 0, {}
			for i, value in ipairs({ position.X, position.Y, position.Z }) do
				local negative = value < 0
				if negative then signs += 2 ^ (3 - i) end
				out[i] = string.pack("<I2", math.clamp(math.floor((value + (negative and 2 ^ e or 0)) * scale + 0.5), 0, 65535))
			end
			return string.char(e * 8 + signs) .. table.concat(out)
		end
		-- upright, turned by yaw (measured: yaw 30/45/60/-45 = index 3, sin in the first part; 135 = index 1, cos in the second)
		local QUARTER = 32767 / math.sqrt(2)
		local function rotation(yaw)
			local s, c = math.sin(yaw / 2), math.cos(yaw / 2)
			local index, parts
			if math.abs(c) >= math.abs(s) then
				if c < 0 then s = -s end
				index, parts = 3, { s, 0, 0 }
			else
				if s < 0 then c = -c end
				index, parts = 1, { 0, c, 0 }
			end
			local value = index * 2 ^ 46
			for i, part in ipairs(parts) do
				local raw = math.clamp(math.floor(part * QUARTER + 0.5), -16384, 16383) % 32768
				value += raw * 2 ^ (46 - 15 * i)
			end
			return string.pack("<I4", value % 2 ^ 32) .. string.pack("<I2", math.floor(value / 2 ^ 32))
		end

		---Send one body packet: the live header, a new stamp, and `framed` (length + payload).
		---@param framed string
		---@return boolean
		local function sendFramed(framed)
			if not header then
				Rak.failed += 1
				return false
			end
			local stamp = math.max(lastStamp + 1, lastStamp + math.floor((os.clock() - lastClock) * 240))
			local packet = string.sub(header, 1, 1) .. string.pack("<I4", stamp) .. string.sub(header, 6, 34) .. framed
			if not pcall(raknet.send, buffer.fromstring(packet)) then
				Rak.failed += 1
				return false
			end
			lastStamp, lastClock = stamp, os.clock()
			Rak.sent += 1
			return true
		end

		---Tell the server the body is at cframe now (needs one real packet of this body seen first).
		---@param cframe CFrame
		---@return boolean
		function Rak.send(cframe)
			local body = axes(cframe.Position)
			if not body then
				Rak.failed += 1
				return false
			end
			local look = cframe.LookVector
			local payload = string.char(0x60) .. body .. rotation(math.atan2(-look.X, -look.Z))
			return sendFramed(string.pack("<I2", #payload) .. payload)
		end

		---Hold the server body at cframe, re-sent at the chosen rate (the first right away).
		---@param cframe CFrame
		---@param root BasePart
		---@param dt number
		---@param everyStep boolean? send on every call, not at the chosen rate
		function Rak.hold(cframe, root, dt, everyStep)
			local first = not Rak.on
			Rak.on, want = true, cframe
			if not header and root then
				-- (a body standing still sends nothing: a 0.02-stud shift makes one, which is blocked and read)
				needHeader = true
				root.CFrame = root.CFrame + Vector3.new(0.02, 0, 0)
				return
			end
			acc += dt
			if first or everyStep or acc >= 1 / math.max(Config.get("monster.rakRate"), 5) then
				acc = 0
				Rak.send(want)
			end
		end

		---Let go: the server is given the real place once, then the body's own packets flow again.
		---@param cframe CFrame?
		function Rak.release(cframe)
			if not Rak.on then return end
			if cframe then Rak.send(cframe) end
			Rak.on, want, acc = false, nil, 0
		end

		function Rak.stop()
			Rak.on = false
			respawned:Disconnect()
			if genv.MONSTER_RAK_HOOK then pcall(raknet.remove_send_hook, genv.MONSTER_RAK_HOOK) end
			genv.MONSTER_RAK_HOOK = nil
		end
		Rak.needsHeader = function() return needHeader end
	end
	local function rakOn() return Rak.available and Config.get("monster.rak") == true end
	local function voiding() return Config.get("monster.fake") == true and Config.get("monster.fakeWhere") == "void" end

	-- the strike: while the body is in the void, a shot (yours or the ragebot's) is held until the server has the body
	-- at the strike place, and the body stays there `hold` seconds after the last one, then goes back.
	-- Measured 2026-11-09 vs BasedHub: strikes always at the real place lost 1-2 (its ambush learns where you show up),
	-- so each strike now shows you at a NEW place near you, free of walls and with a clear line to where the shot goes,
	-- and the shot leaves from there.
	local strike = genv.MONSTER_STRIKE
	-- (a hook cannot be taken off: an older build's hook keeps its own table, which stays off, so it only passes through)
	if strike and strike.version ~= 2 then
		strike.on = false
		strike = nil
	end
	if not strike then
		strike = { version = 2, on = false, since = 0, untilT = 0, arrive = 0.12, hold = 0.4, delayed = 0, direct = 0 }
		genv.MONSTER_STRIKE = strike
	end
	strike.on, strike.untilT, strike.spot, strike.shift = false, 0, nil, nil
	local strikeSight = RaycastParams.new()
	strikeSight.FilterType = Enum.RaycastFilterType.Exclude
	local strikeRoom = OverlapParams.new()
	strikeRoom.FilterType = Enum.RaycastFilterType.Exclude
	---A place within `strike.spread` of `base` with room to stand and a clear line to `aim` (base if none is found).
	---@param base Vector3
	---@param aim Vector3?
	---@param hitPart Instance?
	---@return Vector3
	function strike.pick(base, aim, hitPart)
		local spread = strike.spread or 0
		if spread <= 0 then return base end
		local skip = { LP.Character, workspace.CurrentCamera }
		local model = typeof(hitPart) == "Instance" and hitPart:FindFirstAncestorOfClass("Model")
		if model then skip[#skip + 1] = model end
		strikeSight.FilterDescendantsInstances, strikeRoom.FilterDescendantsInstances = skip, skip
		for _ = 1, 14 do
			local turn, far = math.random() * math.pi * 2, spread * (0.4 + 0.6 * math.random())
			local spot = base + Vector3.new(math.cos(turn) * far, math.random() * 3, math.sin(turn) * far)
			local free = #workspace:GetPartBoundsInRadius(spot, 2, strikeRoom) == 0
			if free and (typeof(aim) ~= "Vector3" or not workspace:Raycast(spot, aim - spot, strikeSight)) then return spot end
		end
		return base
	end
	if not strike.hooked and hookmetamethod and getnamecallmethod then
		strike.hooked = pcall(function()
			local old
			old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
				if strike.on and getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and self.Name == "MainEvent" and (...) == "ShootGun" then
					local now = os.clock()
					local args, count = { ... }, select("#", ...)
					if now > strike.untilT then
						-- a new strike: a new place (only where the server can be told it, over raknet)
						strike.since = now
						local base = strike.real
						local spot = base and strike.movable and strike.pick(base, args[4], args[5]) or base
						strike.spot, strike.shift = spot, spot and base and spot - base or nil
					end
					strike.untilT = now + strike.hold
					if strike.shift and typeof(args[3]) == "Vector3" then args[3] = args[3] + strike.shift end
					local wait = strike.since + strike.arrive - now
					if wait > 0 then
						strike.delayed += 1
						task.spawn(function()
							task.wait(wait)
							-- (a dot call: no hook sees it again)
							pcall(self.FireServer, self, table.unpack(args, 1, count))
						end)
						return
					end
					strike.direct += 1
					return old(self, table.unpack(args, 1, count))
				end
				return old(self, ...)
			end))
		end)
	end
	local pingItem = game:GetService("Stats").Network.ServerStatsItem:FindFirstChild("Data Ping")

	local root, real, put, frozenAt
	local putVoid, voidSpot, voidRandom = false, nil, Random.new()
	local nudge, sendUntil = 1, 0
	local connections = {}
	-- On target: who, since when the body has been beside them, and the gun's clock
	local hunt = { player = nil, since = 0, last = nil, nextShot = 0, reloadUntil = 0, spread = 0, fired = 0, reloads = 0 }
	genv.MONSTER_HUNT = hunt      -- (what a test reads: who, shots fired, reloads)

	-- the red body where they see you, in a folder of its own in the world, as the hub keeps its own:
	-- under the camera Da Hood took it away at once (measured: every frame after failed on "locked")
	local holder, box
	local function newBox()
		if not (holder and holder.Parent) then
			holder = Instance.new("Folder")
			holder.Name = (B.util and B.util.randomName) and B.util.randomName() or "MonsterFake"
			holder.Parent = workspace
		end
		box = Instance.new("Part")
		box.Name = "MonsterFakeBody"
		box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow = true, false, false, false, false
		box.Size = Vector3.new(4, 5, 1.4)
		box.Material = Enum.Material.ForceField
		box.Color = Color3.fromRGB(176, 0, 30)
	end
	local function hideBox()
		if box then pcall(function() box.Parent = nil end) end
	end
	local function showBox(cframe)
		if not Config.get("monster.desyncBox") then return hideBox() end
		if box and pcall(function() box.CFrame = cframe; box.Parent = holder end) then return end
		pcall(newBox)
		if box then pcall(function() box.CFrame = cframe; box.Parent = holder end) end
	end

	local function wanted() return Config.get("monster.desync") == true or Config.get("monster.fake") == true end
	-- (the ragebot moves the body itself; over raknet that is fine, the server only ever gets the fake)
	local function hunting() return B.DaHood ~= nil and B.DaHood.on == true and not ((rakOn() or voiding()) and Config.get("monster.rakRage")) end
	local function shootingFromFake() return rakOn() and Config.get("monster.rakShoot") == true end
	local function onTarget() return Config.get("monster.fake") == true and Config.get("monster.fakeWhere") == "target" end
	local function ghosting() return Config.get("monster.fake") == true and Config.get("monster.fakeWhere") == "ghost" end
	-- Decoy (asked 2026-11-07 after the clip: the other screen sees your character standing still where you
	-- switched it on, while you roam and your hits land). The body stays at that spot; for each shot it is
	-- taken to the ghost's firing place for a moment (the server wants it within 17 studs of the origin and
	-- refused shots for 0.1-0.2 s after a hop) and sent back.
	local function decoying() return Config.get("monster.fake") == true and Config.get("monster.fakeWhere") == "decoy" end
	local STRIKE_WAIT, STRIKE_HOLD = 0.3, 0.9

	-- Ghost (asked 2026-11-07): the server holds the body high above you, you walk, aim and shoot where you
	-- stand. Measured with two accounts: shots sent with the origin at a body 40 UNDER the map were refused
	-- (0 of 3: the ground is in the line), the same 40 ABOVE were taken (3 of 3, ~21 each with a Rifle). So
	-- the ghost goes up, and your own shots are re-sent from the ghost's place: the server checks the origin
	-- against where it has the body, and the hit point stays where you aimed.
	local ghost = genv.MONSTER_GHOST
	if not ghost then ghost = { shift = nil, real = nil, hooked = false, redirected = 0, home = nil, strikeSince = 0, strikeUntil = 0, delayed = 0, bypass = false }; genv.MONSTER_GHOST = ghost end
	ghost.shift, ghost.real, ghost.home = nil, nil, nil
	ghost.strikeSince, ghost.strikeUntil, ghost.delayed, ghost.bypass, ghost.redirected = ghost.strikeSince or 0, ghost.strikeUntil or 0, ghost.delayed or 0, false, ghost.redirected or 0
	-- (a hook cannot be taken off: a newer build stacks its own on top of an older one, which only passes through)
	if ghost.hookVersion ~= 2 and hookmetamethod and getnamecallmethod then
		local okHook = pcall(function()
			local old
			old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
				local shift = ghost.shift
				if shift and not ghost.bypass and getnamecallmethod() == "FireServer" and typeof(self) == "Instance" and self.Name == "MainEvent" then
					local args = { ... }
					if args[1] == "ShootGun" and typeof(args[3]) == "Vector3" and ghost.real and (args[3] - ghost.real).Magnitude < 25 then
						args[3] = args[3] + shift
						ghost.redirected += 1
						local count = select("#", ...)
						if ghost.decoy then
							-- the body goes to the firing place now; the shot leaves once it has been there a moment
							local now = os.clock()
							if now > ghost.strikeUntil then ghost.strikeSince = now end
							ghost.strikeUntil = now + STRIKE_HOLD
							local wait = ghost.strikeSince + STRIKE_WAIT - now
							if wait > 0 then
								ghost.delayed += 1
								task.spawn(function()
									task.wait(wait)
									ghost.bypass = true
									pcall(self.FireServer, self, table.unpack(args, 1, count))
									ghost.bypass = false
								end)
								return
							end
						end
						return old(self, table.unpack(args, 1, count))
					end
				end
				return old(self, ...)
			end))
		end)
		ghost.hooked = okHook
		if okHook then ghost.hookVersion = 2 end
	end
	-- alive, not knocked, not behind a spawn shield
	local function standing(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local effects = character and character:FindFirstChild("BodyEffects")
		local knocked = effects and effects:FindFirstChild("K.O")
		return humanoid ~= nil and humanoid.Health > 0 and not (knocked and knocked.Value) and not character:FindFirstChildOfClass("ForceField")
	end
	-- the hub's own moments that need the server to see the real body. MEASURED 2026-11-09: with the fake on, every
	-- shop click failed (the server checks the body is at the pad), the account lost its guns to stomps and was left
	-- with none ("buying: armour" for the whole duel, 0 shots fired). So the fake steps aside while the hub buys,
	-- stomps or brings, and, with Show lures on, while the ragebot lures or baits (that is how a void-camper is
	-- drawn out to be shot).
	local function hubNeedsReal()
		local DH = B.DaHood
		if not DH then return false end
		if DH.errand == true then return true end
		if not DH.on then return false end
		local status = type(DH.status) == "string" and DH.status or ""
		if string.find(status, "^stomping") or string.find(status, "^bringing") or string.find(status, "^buying") or string.find(status, "^waiting at the pad") then return true end
		return Config.get("monster.showLures") == true and (string.find(status, "^luring") ~= nil or string.find(status, "^baiting") ~= nil)
	end
	local function active(character)
		if not wanted() or hunting() or hubNeedsReal() then return false end
		-- (On target shoots for you, so a gun in hand is what it wants)
		if Config.get("monster.desyncTools") and not onTarget() and not ghosting() and not decoying() and not shootingFromFake() and not voiding() and character:FindFirstChildOfClass("Tool") then return false end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local effects = character:FindFirstChild("BodyEffects")
		local knocked = effects and effects:FindFirstChild("K.O")
		return humanoid ~= nil and humanoid.Health > 0 and not (knocked and knocked.Value)
	end

	-- who On target sits by: the hub's marked players if there are any, else the nearest who is not a
	-- friend; kept until knocked, dead or gone
	local function marked(player)
		local DH, Roster = B.DaHood, B.Roster
		return (DH and DH.isMarked and DH.isMarked(player)) or (Roster and Roster.targets[player.UserId] == true)
	end
	local function anyMarked()
		local DH, Roster = B.DaHood, B.Roster
		return (DH and DH.marked and next(DH.marked) ~= nil) or (Roster and Roster.anyTargets and Roster.anyTargets())
	end
	local function pick(from)
		if hunt.player and hunt.player.Parent and standing(hunt.player.Character) then return hunt.player end
		local only, best, bestGap = anyMarked(), nil, nil
		for _, player in ipairs(Players:GetPlayers()) do
			local friend = B.Roster and B.Roster.friends[player.UserId]
			local theirRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if player ~= LP and not friend and (not only or marked(player)) and theirRoot and standing(player.Character) then
				local gap = (theirRoot.Position - from).Magnitude
				if not bestGap or gap < bestGap then best, bestGap = player, gap end
			end
		end
		return best
	end
	-- beside them: behind, then their right, left, front, with a clear line to them; above if none is
	local SIDES = { Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1) }
	local sight = RaycastParams.new()
	sight.FilterType = Enum.RaycastFilterType.Exclude
	local function besideOf(player)
		local theirRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not theirRoot then return nil end
		sight.FilterDescendantsInstances = { LP.Character, player.Character, workspace.CurrentCamera }
		local centre, near = theirRoot.Position, Config.get("monster.fakeNear")
		for _, side in ipairs(SIDES) do
			local spot = (theirRoot.CFrame * CFrame.new(side * near)).Position
			if not workspace:Raycast(centre, spot - centre, sight) then
				return CFrame.lookAt(spot, Vector3.new(centre.X, spot.Y, centre.Z))
			end
		end
		return CFrame.new(centre + Vector3.new(0, near + 2, 0))
	end

	-- the gun On target fires: the one in hand, else the first in the backpack with rounds to fire
	local function spare(gun)
		local inventory = LP:FindFirstChild("DataFolder") and LP.DataFolder:FindFirstChild("Inventory")
		local held = inventory and inventory:FindFirstChild(gun.Name)
		return held and tonumber(held.Value) or 0
	end
	local function gunIn(character)
		local held = character:FindFirstChildOfClass("Tool")
		if held and held:FindFirstChild("Ammo") then return held end
		local pack = LP:FindFirstChildOfClass("Backpack")
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		for _, item in ipairs(pack and pack:GetChildren() or {}) do
			if item:IsA("Tool") and item:FindFirstChild("Ammo") and (item.Ammo.Value > 0 or spare(item) > 0) and humanoid then
				humanoid:EquipTool(item)
				return nil      -- (fires from the next step on, once it is in hand)
			end
		end
		return nil
	end
	-- one shot (a shell of five pellets for a shotgun) from the body where it is now: beside the target
	local function fire(gun, part)
		local handle, ammo = gun:FindFirstChild("Handle"), gun:FindFirstChild("Ammo")
		local remote = game:GetService("ReplicatedStorage"):FindFirstChild("MainEvent")
		local now = os.clock()
		if not (handle and ammo and remote) or now < hunt.nextShot then return end
		if ammo.Value <= 0 then
			if now >= hunt.reloadUntil and spare(gun) > 0 then
				remote:FireServer("Reload", gun)
				hunt.reloadUntil = now + 3
				hunt.reloads += 1
			end
			hunt.nextShot = now + 0.25
			return
		end
		local cooldown = gun:FindFirstChild("ShootingCooldown")
		hunt.nextShot = now + (cooldown and cooldown.Value or 0.3) + 0.03
		hunt.fired += 1
		local up = Vector3.new(0, 1, 0)
		if string.find(gun.Name, "Shotgun", 1, true) or string.find(gun.Name, "Double-Barrel", 1, true) or string.find(gun.Name, "SG", 1, true) then
			hunt.spread += 1
			local stamp = workspace:GetServerTimeNow()
			for pellet = 1, 5 do remote:FireServer("ShootGun", handle, handle.Position, part.Position, part, up, stamp, hunt.spread, pellet) end
		else
			remote:FireServer("ShootGun", handle, handle.Position, part.Position, part, up)
		end
	end

	-- where the server is given the body this step (nil: where it really is)
	local function fakeOf(cframe)
		if onTarget() then
			local target = pick(cframe.Position)
			if target ~= hunt.player then hunt.player, hunt.since, hunt.last = target, os.clock(), nil end
			return target and besideOf(target) or nil
		end
		local centre = cframe
		if ghosting() or decoying() then
			-- straight up, as high as asked; under a roof or awning, up through the nearest open sky instead
			-- (measured: an awning 4 studs over the body left the ghost at 0 rise, and no shot was taken)
			local now, want = os.clock(), Config.get("monster.ghostHeight")
			if not ghost.until_ or now > ghost.until_ or ghost.want ~= want then
				sight.FilterDescendantsInstances = { LP.Character, workspace.CurrentCamera }
				local here = cframe.Position
				local function room(offset)
					local hit = workspace:Raycast(here + offset, Vector3.new(0, want + 4, 0), sight)
					return hit and math.max(hit.Distance - 4, 0) or want
				end
				local best, bestRoom = Vector3.new(0, 0, 0), room(Vector3.new(0, 0, 0))
				-- measured 2026-11-07: a shot is refused when anything is in the line from the ghost to the
				-- target (a target under a roof 12 studs thick: 0 of 8 from 20 to 120 up). So with someone
				-- to shoot at, the ghost goes to the highest free spot that SEES them.
				local target = pick(here)
				local torso = target and target.Character and (target.Character:FindFirstChild("UpperTorso") or target.Character:FindFirstChild("HumanoidRootPart"))
				local seen = false
				if torso and bestRoom >= 0 then
					local aim = torso.Position
					local params = OverlapParams.new()
					params.FilterType = Enum.RaycastFilterType.Exclude
					params.FilterDescendantsInstances = { LP.Character, target.Character, workspace.CurrentCamera }
					sight.FilterDescendantsInstances = { LP.Character, target.Character, workspace.CurrentCamera }
					local offsets = { Vector3.new(0, 0, 0) }
					for _, radius in ipairs({ 8, 16, 28, 45 }) do
						for step = 0, 7 do
							local turn = step * math.pi / 4
							offsets[#offsets + 1] = Vector3.new(math.cos(turn) * radius, 0, math.sin(turn) * radius)
						end
					end
					for _, height in ipairs({ want, want * 0.6, 25, 8, 0 }) do
						for _, offset in ipairs(offsets) do
							local spot = here + offset + Vector3.new(0, height, 0)
							if not workspace:Raycast(spot, aim - spot, sight) and #workspace:GetPartBoundsInRadius(spot, 2.5, params) == 0 then
								best, bestRoom, seen = offset, height, true
								break
							end
						end
						if seen then break end
					end
				end
				if seen then
					-- (kept)
				elseif bestRoom < want then
					for _, radius in ipairs({ 8, 16, 28, 45 }) do
						for step = 0, 7 do
							local turn = step * math.pi / 4
							local offset = Vector3.new(math.cos(turn) * radius, 0, math.sin(turn) * radius)
							local space = room(offset)
							if space > bestRoom then best, bestRoom = offset, space end
							if bestRoom >= want then break end
						end
						if bestRoom >= want then break end
					end
				end
				ghost.offset, ghost.rise, ghost.until_, ghost.want = best, bestRoom, now + 0.3, want
			end
			centre = cframe + ghost.offset + Vector3.new(0, ghost.rise, 0)
			ghost.centre = centre.Position
			-- the dodge: the body is thrown about inside a ball round that spot every step, so a shot aimed at
			-- where they see it mostly misses; the ball stays under the 17-stud origin rule, so yours still land
			local wobble = Config.get("monster.ghostJitter")
			if decoying() then
				-- (the decoy keeps still where it was left, and takes the firing place only while a shot is on)
				ghost.decoy = true
				if not ghost.home then ghost.home = cframe + Vector3.new(0, Config.get("monster.decoyUp"), 0) end
				if os.clock() > ghost.strikeUntil then centre = ghost.home end
			else
				ghost.decoy = false
			end
			if ghosting() and wobble > 0 then
				local spin, tilt = math.random() * math.pi * 2, math.random() * 2 - 1
				local flat = math.sqrt(1 - tilt * tilt)
				centre = centre + Vector3.new(math.cos(spin) * flat, tilt, math.sin(spin) * flat) * (wobble * math.random() ^ (1 / 3))
			end
		elseif Config.get("monster.fake") then
			local far = Config.get("monster.fakeDistance")
			local where = Config.get("monster.fakeWhere")
			local flat = Vector3.new(cframe.LookVector.X, 0, cframe.LookVector.Z)
			flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
			if where ~= "freeze" then frozenAt = nil end
			if where == "offset" then
				-- right, up, back from where you face
				local turned = CFrame.lookAt(cframe.Position, cframe.Position + flat)
				centre = turned * CFrame.new(Config.get("monster.fakeOffX"), Config.get("monster.fakeOffY"), Config.get("monster.fakeOffZ"))
			elseif where == "orbit" then
				-- round the target (round you with nobody to pick), a full turn every 2pi/speed seconds
				local target = pick(cframe.Position)
				local theirRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				-- (a target in the void is past what a packet can carry, |coords| < 1024: then round you)
				local there = theirRoot and theirRoot.Position
				local reachable = there and math.max(math.abs(there.X), math.abs(there.Y), math.abs(there.Z)) < 1000
				local middle = reachable and there or cframe.Position
				local turn, radius = os.clock() * Config.get("monster.orbitSpeed"), Config.get("monster.orbitRadius")
				local spot = middle + Vector3.new(math.cos(turn) * radius, Config.get("monster.orbitHeight"), math.sin(turn) * radius)
				centre = CFrame.lookAt(spot, Vector3.new(middle.X, spot.Y, middle.Z))
			elseif where == "freeze" then
				-- left where it was switched on, as a body standing still
				frozenAt = frozenAt or cframe
				centre = frozenAt
			elseif where == "above" then centre = cframe + Vector3.new(0, far, 0)
			elseif where == "behind" then centre = cframe - flat * far
			elseif where == "side" then centre = cframe + Vector3.new(-flat.Z, 0, flat.X) * far
			else centre = cframe - Vector3.new(0, far, 0) end
		end
		if Config.get("monster.desync") then
			local turn = math.random() * math.pi * 2
			local range = Config.get("monster.desyncRange")
			centre = centre + Vector3.new(math.cos(turn) * range, 0, math.sin(turn) * range)
		end
		return centre
	end
	-- put back, keeping whatever small change was made while it was away (a tool taken out shifts it a
	-- little, the camera turns it); a body moved further than that was moved on purpose, and stays
	local function putBack()
		-- (from the void always straight back: ~1e9 out a position is only good to ~100 studs)
		if put and putVoid then
			if root and root.Parent then root.CFrame = real end
			put, putVoid = nil, false
			return
		end
		if put and root and root.Parent and (root.Position - put.Position).Magnitude < 2 then
			root.CFrame = real * put:ToObjectSpace(root.CFrame)
		end
		put = nil
	end

	connections[#connections + 1] = RunService.PreSimulation:Connect(function()
		putBack()
		if os.clock() < sendUntil and root and root.Parent then
			nudge = -nudge
			root.CFrame = root.CFrame + Vector3.new(0.02 * nudge, 0, 0)
		end
	end)
	connections[#connections + 1] = RunService.PreRender:Connect(putBack)
	-- which way the body they see faces: as you do (or as the mode set it), at the target, or spinning
	local function faced(fake, cframe)
		local face = Config.get("monster.rakFace")
		if face == "target" then
			local target = hunt.player or pick(cframe.Position)
			local theirRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
			if theirRoot then
				local at = fake.Position
				local there = Vector3.new(theirRoot.Position.X, at.Y, theirRoot.Position.Z)
				if (there - at).Magnitude > 0.1 then return CFrame.lookAt(at, there) end
			end
		elseif face == "spin" then
			return CFrame.new(fake.Position) * CFrame.Angles(0, (os.clock() * 25) % (math.pi * 2), 0)
		end
		return fake
	end

	connections[#connections + 1] = RunService.PostSimulation:Connect(function(dt)
		putBack()
		local character = LP.Character
		root = character and character:FindFirstChild("HumanoidRootPart")
		local packets = rakOn()
		if wanted() and not hunting() and not packets then sendUntil = os.clock() + 0.5 end
		if not (root and active(character)) then
			strike.on = false
			Rak.release(root and root.CFrame)
			hideBox()
			hunt.player, frozenAt = nil, nil
			ghost.shift, ghost.real, ghost.home, ghost.decoy = nil, nil, nil, false
			return
		end
		real = root.CFrame
		-- Void: after each physics step the body is put far out (a new spot every step unless Spam is off) and put
		-- back before the next step and before the frame is drawn, so the engine itself sends the void and every
		-- packet is one it made (crafted void packets got the account disconnected). Any executor can run it.
		-- A shot brings the body back here for a moment (the strike) and is held until the server has it here.
		strike.on = false
		if voiding() then
			ghost.shift = nil
			hideBox()
			strike.on = Config.get("monster.voidStrike") == true
			strike.real, strike.movable, strike.spread = real.Position, packets, Config.get("monster.strikeSpread")
			local ping = pingItem and pingItem:GetValue() / 1000 or 0.1
			if packets then
				-- Sky void (raknet): every packet a new random spot in a 2000 x 2000 box 600-1000 up, all inside the
				-- packet format that is fully decoded (thousands sent, no disconnect). Nobody can be where the next
				-- one lands. A strike sends its place every step from its first (a shot 0.1 s after was taken), and
				-- stays only a short moment after the last shot.
				strike.arrive = math.clamp(ping + 0.06, 0.08, 0.4)
				strike.hold = strike.arrive + 0.15
				if os.clock() < strike.untilT then
					local at = strike.spot or real.Position
					Rak.hold(real.Rotation + at, root, dt, true)
				else
					local spot = Vector3.new(voidRandom:NextNumber(-1000, 1000), voidRandom:NextNumber(600, 1000), voidRandom:NextNumber(-1000, 1000))
					if not Config.get("monster.voidSpam") then voidSpot = voidSpot or spot; spot = voidSpot end
					Rak.hold(CFrame.new(spot), root, dt)
				end
				return
			end
			-- Far void (no raknet): a body swap far out. MEASURED: the engine sends those jumps as teleports (no
			-- 0xA1 at all), and the server then refused every shot for at least 0.8 s after coming back (0 of 12), so
			-- without raknet the void only hides you; a shot still brings you back.
			Rak.release(nil)
			strike.arrive = math.clamp(ping + Config.get("monster.voidArrive"), 0.15, 0.8)
			strike.hold = strike.arrive + 0.3
			if os.clock() < strike.untilT then
				-- (a body left still sends nothing: a 0.01-stud shift each step makes the engine send the real place)
				nudge = -nudge
				root.CFrame = root.CFrame + Vector3.new(0.01 * nudge, 0, 0)
				return
			end
			-- (and the same shift keeps the swapped body sending at all: a still one sent nothing for 90 s)
			nudge = -nudge
			real = real + Vector3.new(0.01 * nudge, 0, 0)
			if Config.get("monster.voidSpam") or not voidSpot then
				voidSpot = Vector3.new(voidRandom:NextNumber(-1.5e9, 1.5e9), voidRandom:NextNumber(4e8, 2e9), voidRandom:NextNumber(-1.5e9, 1.5e9))
			end
			put, putVoid = CFrame.new(voidSpot), true
			root.CFrame = put
			return
		end
		voidSpot = nil
		local fake = fakeOf(real)
		if not fake then
			ghost.shift = nil
			Rak.release(real)
			return hideBox()
		end
		fake = faced(fake, real)
		if ghosting() or decoying() then
			ghost.shift, ghost.real = (ghost.centre or fake.Position) - real.Position, real.Position
		elseif packets and (Config.get("monster.rakShoot") or onTarget()) then
			-- your shots leave from where the server has you (it refuses them from anywhere else)
			ghost.shift, ghost.real = fake.Position - real.Position, real.Position
		else
			ghost.shift = nil
		end
		if packets then
			-- the body stays here; only the server is told the fake
			Rak.hold(fake, root, dt)
		else
			Rak.release(nil)
			put = fake
			root.CFrame = put
		end
		-- On target: a jump to a new place is waited out before firing, then every shot goes from here
		if onTarget() and hunt.player then
			local now = os.clock()
			if hunt.last and (fake.Position - hunt.last).Magnitude > 12 then hunt.since = now end
			hunt.last = fake.Position
			local gun = gunIn(character)
			local part = hunt.player.Character and (hunt.player.Character:FindFirstChild("UpperTorso") or hunt.player.Character:FindFirstChild("HumanoidRootPart"))
			if gun and part and now - hunt.since >= 0.25 then fire(gun, part) end
		end
		showBox(fake)
	end)

	-- its own tab, beside Da Hood's (another game has no Ragebot tab, and gets none of this)
	task.spawn(function()
		local giveUp = os.clock() + 60
		while not (Window.pages and Window.pages["dahood.ragebot"]) and os.clock() < giveUp and GUI.Parent do task.wait(0.25) end
		local rage = Window.pages and Window.pages["dahood.ragebot"]
		if not rage then return end
		local last = rage.order
		for _, page in ipairs(Window.order) do
			if page.group == rage.group and page.order > last then last = page.order end
		end
		Window.page({ id = "dahood.monster", title = "Desync", icon = "ghost", group = rage.group, order = last + 1, eyebrow = rage.eyebrow, build = function(page)
			local jump = page:section({ title = "Desync", icon = "shuffle", desc = "Others see you somewhere new every step." })
			jump:toggle({ id = "monster.desync", label = "Desync", desc = "You jump around for them. Their shots miss.", default = false })
			jump:slider({ id = "monster.desyncRange", label = "How far", desc = "How far from you they see you. 150+ stopped BasedHub firing.", min = 10, max = 400, step = 5, default = 40, suffix = " st" })
			local fake = page:section({ title = "Fake position", icon = "map-pin", desc = "Others see you in one other place." })
			fake:toggle({ id = "monster.fake", label = "Fake position", desc = "They see you there, you play here.", default = false })
			fake:dropdown({ id = "monster.fakeWhere", label = "Where", desc = "Decoy: they see you stand still, you roam.",
				options = { { "decoy", "Decoy" }, { "ghost", "Ghost" }, { "target", "On target" }, { "void", "Void" }, { "orbit", "Orbit target" }, { "offset", "Offset" }, { "freeze", "Freeze" }, { "below", "Below" }, { "behind", "Behind" }, { "side", "Side" }, { "above", "Above" } }, default = "decoy" })
			fake:slider({ id = "monster.fakeOffX", label = "Offset X", desc = "Offset: right (+) or left (-).", min = -150, max = 150, step = 1, default = 0, suffix = " st" })
			fake:slider({ id = "monster.fakeOffY", label = "Offset Y", desc = "Offset: up (+) or down (-).", min = -100, max = 300, step = 1, default = 0, suffix = " st" })
			fake:slider({ id = "monster.fakeOffZ", label = "Offset Z", desc = "Offset: behind (+) or in front (-).", min = -150, max = 150, step = 1, default = 30, suffix = " st" })
			fake:slider({ id = "monster.orbitRadius", label = "Orbit radius", desc = "Orbit: how far round the target.", min = 2, max = 60, step = 1, default = 10, suffix = " st" })
			fake:slider({ id = "monster.orbitHeight", label = "Orbit height", desc = "Orbit: above (+) or below (-) them.", min = -10, max = 60, step = 1, default = 0, suffix = " st" })
			fake:slider({ id = "monster.orbitSpeed", label = "Orbit speed", desc = "Orbit: how fast it goes round.", min = 1, max = 20, step = 1, default = 6 })
			fake:slider({ id = "monster.decoyUp", label = "Decoy up", desc = "Decoy: raise it, out of reach (0 = where you stand).", min = 0, max = 250, step = 5, default = 0, suffix = " st" })
			fake:slider({ id = "monster.ghostJitter", label = "Ghost dodge", desc = "Ghost: how far it jumps about. 0 is off.", min = 0, max = 14, step = 1, default = 10, suffix = " st" })
			fake:slider({ id = "monster.ghostHeight", label = "Ghost height", desc = "Ghost: how high up they see you.", min = 30, max = 250, step = 5, default = 120, suffix = " st" })
			fake:slider({ id = "monster.fakeNear", label = "From target", desc = "How close to them, on target.", min = 2, max = 12, step = 1, default = 4, suffix = " st" })
			fake:slider({ id = "monster.fakeDistance", label = "How far", desc = "How far from you, the others.", min = 5, max = 200, step = 1, default = 40, suffix = " st" })
			local both = page:section({ title = "Both", icon = "settings-2", desc = "Both stop while the ragebot hunts (not over raknet)." })
			both:toggle({ id = "monster.desyncTools", label = "Off while holding", desc = "A gun out brings you back (not on target).", default = true })
			both:toggle({ id = "monster.desyncBox", label = "Show where they see you", desc = "A red body at your fake place.", default = true })
			if Rak.available then
				local rak = page:section({ title = "Raknet", icon = "radio", desc = "Volt: only the server is told the fake. You never move." })
				rak:toggle({ id = "monster.rak", label = "Use raknet", desc = "Off: the old body swap.", default = true })
				rak:toggle({ id = "monster.rakShoot", label = "Shoot from fake", desc = "Your shots leave from where they see you.", default = true })
				rak:toggle({ id = "monster.rakRage", label = "Keep on with Ragebot", desc = "The ragebot fights, they see the fake.", default = true })
				rak:dropdown({ id = "monster.rakFace", label = "Face", desc = "Which way the fake looks.",
					options = { { "you", "As you" }, { "target", "The target" }, { "spin", "Spin" } }, default = "you" })
				rak:slider({ id = "monster.rakRate", label = "Send rate", desc = "Fake updates a second.", min = 10, max = 60, step = 1, default = 30, suffix = "/s" })
			end
			local void = page:section({ title = "Void", icon = "orbit", desc = "Where = Void: they see you jump around the sky." })
			void:toggle({ id = "monster.voidStrike", label = "Strike to shoot", desc = "A shot brings you back for a moment.", default = true })
			void:toggle({ id = "monster.voidSpam", label = "New spot every step", desc = "Nobody can follow you in.", default = true })
			void:toggle({ id = "monster.showLures", label = "Show lures", desc = "The ragebot's lures are seen, so hiders come out.", default = true })
			void:slider({ id = "monster.strikeSpread", label = "Strike spread", desc = "Each shot shows you somewhere new near you. 0 = where you stand.", min = 0, max = 25, step = 1, default = 12, suffix = " st" })
		end })
	end)

	function Desync.stop()
		for _, connection in ipairs(connections) do connection:Disconnect() end
		local character = LP.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		strike.on = false
		Rak.release(body and body.CFrame)
		Rak.stop()
		ghost.shift = nil
		putBack()
		if holder then pcall(function() holder:Destroy() end) end
		if Window.pages and Window.pages["dahood.monster"] then Window.removePage("dahood.monster") end
	end
end

-- ---- Unload: nothing of MONSTER's is left behind
local unload = B.unload
if unload then
	B.unload = function(...)
		renamer:Disconnect()
		for _, connection in ipairs(adopted) do connection:Disconnect() end
		Desync.stop()
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
