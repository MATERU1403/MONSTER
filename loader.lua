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

-- ============================================================================
--  MONSTER Da Hood suite: net, fake position, void, orbit, physrep, ragebot, resolver, defense
--  (built from monster-build/: pure/*.lua are the offline-tested modules, src/*.lua the runtime)
-- ============================================================================
local DH = { F = {} }
do
-- >>> pure/codec.lua
DH.F.codec = (function()
-- Da Hood body packet (0xA1) codec. Pure: strings and numbers only, so it runs under Lune as well as in the client.
--
-- Layout, measured 2026-11-09 on Volt 1.3.21.2 (two accounts; 122 real packets decoded against the body, see results/capture_report.md):
--   byte 1        0xA1
--   bytes 2-5     <I4 stamp in 1/240 s (an older stamp is dropped by the server); ~14 packets a second while moving
--   bytes 6-34    29 header bytes (the same for a body, but byte 10 changed once during a walk: it is taken fresh from the newest real packet)
--   bytes 35-36   <I2 payload length
--   payload       tag: bit 0x40 = no linear velocity block, bit 0x20 = no angular velocity block, low 5 bits = rotation id
--                      (0: six explicit rotation bytes follow; 10 was seen for an upright body facing along X: a stock orientation)
--                 e*8 + signs (signs: X = 4, Y = 2, Z = 1)
--                 three <I2 axes: raw / 2^(16-e), minus 2^e when that axis is negative (e <= 10, so |coord| < 1024)
--                 [rotation, 6 bytes, when the rotation id is 0: a quaternion cut to 47 bits: 2-bit index, three signed 15-bit parts]
--                 [linear velocity, 5 bytes, when 0x40 is clear]   [angular velocity, 5 bytes, when 0x20 is clear]  (both seen, neither decoded)
--                 Seen on the wire: 8 bytes (tag 6A, standing), 13 (tag 2A, walking straight), 24 (tag 00, turning while walking).
--                 What is built here is the 14-byte form, tag 60: no velocities, explicit rotation. The server accepts it.
-- Nothing past |coord| 1024 is ever built here: that is a different packing, and replaying far packets the engine
-- had made got an account disconnected (error 260).
return function()
	local Codec = {}
	local floor, abs, max, sqrt, sin, cos, atan2, clamp = math.floor, math.abs, math.max, math.sqrt, math.sin, math.cos, math.atan2, math.clamp
	local pack, unpack, char, byte, sub = string.pack, string.unpack, string.char, string.byte, string.sub

	Codec.ID = 0xA1
	Codec.HEADER = 34       -- id + stamp + 29 header bytes
	Codec.STANDARD_LEN = 14 -- tag + axes byte + three axes + six rotation bytes
	Codec.LIMIT = 1023.9    -- the largest |coord| the packing can carry
	local QUARTER = 32767 / sqrt(2)
	local TWO_PI = math.pi * 2

	---Shortest e (1..10) whose range [0, 2^e) holds `big`.
	---@param big number
	---@return number?
	function Codec.exponent(big)
		if big ~= big or big >= 1024 then return nil end -- (NaN, inf and anything past the format: no loop to run)
		local e = 1
		while e <= 10 and 2 ^ e <= big do e += 1 end
		if e > 10 then return nil end
		return e
	end

	---The axes byte and three 16-bit axes of a position (nil when a coordinate does not fit).
	---@return string?
	function Codec.axes(x, y, z)
		if x ~= x or y ~= y or z ~= z then return nil end
		local e = Codec.exponent(max(abs(x), abs(y), abs(z)))
		if not e then return nil end
		local scale, signs, out = 2 ^ (16 - e), 0, {}
		local values = { x, y, z }
		for i = 1, 3 do
			local value = values[i]
			local negative = value < 0
			if negative then signs += 2 ^ (3 - i) end
			out[i] = pack("<I2", clamp(floor((value + (negative and 2 ^ e or 0)) * scale + 0.5), 0, 65535))
		end
		return char(e * 8 + signs) .. out[1] .. out[2] .. out[3]
	end

	---Inverse of axes: `at` is the 1-based offset of the e*8+signs byte.
	---@return number?, number?, number?, number?
	function Codec.unaxes(s, at)
		if #s < at + 6 then return nil end
		local b = byte(s, at)
		local e, signs = floor(b / 8), b % 8
		if e < 1 or e > 10 then return nil end
		local scale, ring, out = 2 ^ (16 - e), 2 ^ e, {}
		for i = 1, 3 do
			local raw = unpack("<I2", s, at + 1 + (i - 1) * 2)
			local value = raw / scale
			local bit = 2 ^ (3 - i)
			if floor(signs / bit) % 2 == 1 then value -= ring end
			out[i] = value
		end
		return out[1], out[2], out[3], e
	end

	---Six rotation bytes for an upright body turned by `yaw` (radians, atan2(-look.X, -look.Z)).
	---Measured: yaw 30/45/60/-45 = index 3 with the sine in the first part; 135 = index 1 with the cosine in the second.
	---@param yaw number
	---@return string
	function Codec.rotation(yaw)
		local s, c = sin(yaw / 2), cos(yaw / 2)
		local index, parts
		if abs(c) >= abs(s) then
			if c < 0 then s = -s end
			index, parts = 3, { s, 0, 0 }
		else
			if s < 0 then c = -c end
			index, parts = 1, { 0, c, 0 }
		end
		local value = index * 2 ^ 46
		for i = 1, 3 do
			local raw = clamp(floor(parts[i] * QUARTER + 0.5), -16384, 16383) % 32768
			value += raw * 2 ^ (46 - 15 * i)
		end
		return pack("<I4", value % 2 ^ 32) .. pack("<I2", floor(value / 2 ^ 32))
	end

	---Split six rotation bytes: index and the three signed parts (as fractions of the unit quaternion).
	---@param s string
	---@param at number 1-based offset
	---@return number?, number?, number?, number?
	function Codec.unrotation(s, at)
		if #s < at + 5 then return nil end
		local lo, hi = unpack("<I4", s, at), unpack("<I2", s, at + 4)
		local value = lo + hi * 2 ^ 32
		local index = floor(value / 2 ^ 46)
		local rest = value % 2 ^ 46
		local parts = {}
		for i = 1, 3 do
			local raw = floor(rest / 2 ^ (46 - 15 * i)) % 32768
			if raw >= 16384 then raw -= 32768 end
			parts[i] = raw / QUARTER
		end
		return index, parts[1], parts[2], parts[3]
	end

	---Yaw back out of an upright rotation (nil when the rotation is not a plain turn about Y).
	---@return number?
	function Codec.yawOf(index, p1, p2, p3)
		local tolerance = 0.002
		local half
		if index == 3 and abs(p2) < tolerance and abs(p3) < tolerance then
			half = atan2(p1, sqrt(max(0, 1 - p1 * p1)))
		elseif index == 1 and abs(p1) < tolerance and abs(p3) < tolerance then
			half = atan2(sqrt(max(0, 1 - p2 * p2)), p2)
		else
			return nil
		end
		return half * 2
	end

	---Difference of two angles, wrapped to [-pi, pi].
	function Codec.angleDelta(a, b)
		local d = (a - b + math.pi) % TWO_PI - math.pi
		return d
	end

	---Payload (tag, axes, rotation) for a body at (x, y, z) turned by yaw; nil when the position does not fit.
	---@return string?
	function Codec.payload(x, y, z, yaw)
		local body = Codec.axes(x, y, z)
		if not body then return nil end
		return char(0x60) .. body .. Codec.rotation(yaw or 0)
	end

	---Length-prefixed payload, what the packet carries after the header.
	function Codec.frame(payload)
		return pack("<I2", #payload) .. payload
	end

	---A whole packet: the first byte and the 29 header bytes of a real packet of this body, a new stamp, a framed payload.
	---@param header string at least 34 bytes of a real packet
	---@param stamp number
	---@param framed string
	---@return string
	function Codec.build(header, stamp, framed)
		return sub(header, 1, 1) .. pack("<I4", stamp % 2 ^ 32) .. sub(header, 6, 34) .. framed
	end

	---Read a packet. `standard` is true when the payload length is exactly what its tag byte says it holds (every layout seen live does).
	---@param packet string
	---@return table?, string?
	function Codec.parse(packet)
		if type(packet) ~= "string" then return nil, "not a string" end
		if #packet < 36 then return nil, "short" end
		if byte(packet, 1) ~= Codec.ID then return nil, "id" end
		local len = unpack("<I2", packet, 35)
		if len < 1 or 36 + len > #packet then return nil, "length" end
		local tag = byte(packet, 37)
		local out = {
			id = Codec.ID,
			stamp = unpack("<I4", packet, 2),
			header = sub(packet, 6, 34),
			len = len,
			bytes = #packet,
			tag = tag,
			noLin = floor(tag / 0x40) % 2 == 1,
			noAng = floor(tag / 0x20) % 2 == 1,
			rid = tag % 0x20,
		}
		local expected = 8 + (out.rid == 0 and 6 or 0) + (out.noLin and 0 or 5) + (out.noAng and 0 or 5)
		out.standard = len == expected
		if len >= 8 then
			local x, y, z, e = Codec.unaxes(packet, 38)
			if x then out.x, out.y, out.z, out.e = x, y, z, e end
		end
		local at = 45 -- the first byte after the axes
		if out.standard and out.rid == 0 then
			local index, p1, p2, p3 = Codec.unrotation(packet, at)
			if index then
				out.rotIndex, out.rot = index, { p1, p2, p3 }
				out.yaw = Codec.yawOf(index, p1, p2, p3)
			end
			at += 6
		end
		if out.standard then
			if not out.noLin then out.linVel = sub(packet, at, at + 4); at += 5 end
			if not out.noAng then out.angVel = sub(packet, at, at + 4) end
		end
		if not out.x then return nil, "axes" end
		return out
	end

	---A copy of a real packet with only the position changed (the field at bytes 38-44), the rest as it was.
	---@return string?
	function Codec.setPosition(packet, x, y, z)
		local parsed = Codec.parse(packet)
		if not parsed then return nil end
		local body = Codec.axes(x, y, z)
		if not body then return nil end
		return sub(packet, 1, 37) .. body .. sub(packet, 45)
	end

	---Copy of a packet with a new stamp.
	function Codec.setStamp(packet, stamp)
		return sub(packet, 1, 1) .. pack("<I4", stamp % 2 ^ 32) .. sub(packet, 6)
	end

	---Hex dump of a byte range, for the capture logs.
	function Codec.hex(s, from, count)
		local out = {}
		for i = from or 1, math.min(#s, (from or 1) + (count or #s) - 1) do out[#out + 1] = string.format("%02X", byte(s, i)) end
		return table.concat(out, " ")
	end

	return Codec
end
end)()
-- >>> pure/orbit.lua
DH.F.orbit = (function()
-- Orbit strafe. Pure: `Orbit.step(t, center, myPos, params)` -> CFrame the server body is given, velocity for the real body.
-- The numbers of the default preset are the ones asked for: a turn at 28 rad/s on a ring of 135 studs, the height flipping
-- between 200000 and 199500 twenty times a second, a jitter of 10 studs about the ring and 5 up or down every 0.025 s,
-- and the real body pushed round the target at 420 studs/s with the part of the move that points at the target removed.
return function(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local Orbit = {}
	local sin, cos, floor, abs = math.sin, math.cos, math.floor, math.abs
	local ZERO = Vector3.new(0, 0, 0)

	Orbit.PRESETS = {
		-- the default: far above the target, a body nobody can follow
		thunder = { speed = 28, radius = 135, heightHigh = 200000, heightLow = 199500, heightRate = 20, jitterH = 10, jitterV = 5, jitterRate = 80, jitterFlip = 0.025, velocity = 420 },
		-- the same turn kept inside the packet format (|coords| < 1024): high over the map, not past it
		sky = { speed = 28, radius = 135, heightHigh = 900, heightLow = 870, heightRate = 20, jitterH = 10, jitterV = 5, jitterRate = 80, jitterFlip = 0.025, velocity = 420 },
		-- close in, at the target's own height, for use without a void
		low = { speed = 6, radius = 10, heightHigh = 0, heightLow = 0, heightRate = 20, jitterH = 0, jitterV = 0, jitterRate = 80, jitterFlip = 0.025, velocity = 60 },
	}
	Orbit.DEFAULT = "thunder"

	---Fill what `params` leaves out from a preset.
	---@param params table|string|nil preset name, or a table of overrides
	---@return table
	function Orbit.resolve(params)
		local base = Orbit.PRESETS[Orbit.DEFAULT]
		if type(params) == "string" then base = Orbit.PRESETS[params] or base; params = nil end
		if not params then return base end
		local out = table.clone(base)
		for key, value in pairs(params) do out[key] = value end
		return out
	end

	---The server body's place and the real body's velocity at time t.
	---@param t number clock in seconds
	---@param center Vector3 what is orbited (the target, or a locked bait position)
	---@param myPos Vector3 where the real body is
	---@param params table|string|nil
	---@return CFrame, Vector3, table
	function Orbit.step(t, center, myPos, params)
		local p = Orbit.resolve(params)
		local angle = t * p.speed
		local around = Vector3.new(sin(angle) * p.radius, 0, cos(angle) * p.radius)
		local high = floor(t * p.heightRate) % 2 == 0
		local height = high and p.heightHigh or p.heightLow
		local flip = (floor(t / p.jitterFlip) % 2 == 0) and p.jitterV or -p.jitterV
		local jitter = Vector3.new(sin(t * p.jitterRate) * p.jitterH, flip, cos(t * p.jitterRate) * p.jitterH)
		local finalPos = center + around + Vector3.new(0, height, 0) + jitter

		-- the real body goes round the target on the ground: toward the ring, never toward the middle
		local move = (center + around) - myPos
		move = Vector3.new(move.X, 0, move.Z)
		local inward = Vector3.new(center.X - myPos.X, 0, center.Z - myPos.Z)
		if inward.Magnitude > 1e-3 then
			local unit = inward.Unit
			local along = move:Dot(unit)
			if along > 0 then move = move - unit * along end
		end
		local velocity = ZERO
		if move.Magnitude > 1e-3 then velocity = move.Unit * p.velocity end

		-- The body looks at the centre along the ground (level): a body 200000 up that looked straight down at it would have a
		-- yaw nobody can define, and the packet format only carries an upright body's yaw anyway.
		local facing = CFrame.new(finalPos)
		if Vector3.new(center.X - finalPos.X, 0, center.Z - finalPos.Z).Magnitude > 1e-3 then
			facing = CFrame.lookAt(finalPos, Vector3.new(center.X, finalPos.Y, center.Z))
		end
		return facing, velocity, { angle = angle, height = height, high = high, jitter = jitter }
	end

	---Keep a position inside what a packet can carry. Returns the CFrame (same look target) and whether it was cut.
	---@param cframe CFrame
	---@param limit number|nil default 1000
	---@return CFrame, boolean
	function Orbit.fit(cframe, limit)
		limit = limit or 1000
		local p = cframe.Position
		if abs(p.X) <= limit and abs(p.Y) <= limit and abs(p.Z) <= limit then return cframe, false end
		local cut = Vector3.new(math.clamp(p.X, -limit, limit), math.clamp(p.Y, -limit, limit), math.clamp(p.Z, -limit, limit))
		return CFrame.new(cut) * cframe.Rotation, true
	end

	return Orbit
end
end)()
-- >>> pure/patterns.lua
DH.F.patterns = (function()
-- Movement patterns for the ragebot, each a pure function (targetPos, t, k, ctx) -> CFrame, the body looking at the target.
-- `k` holds the dahood.k.* numbers (names without the prefix); `ctx` is optional: { vel = Vector3, look = Vector3 }.
-- The names are the ones the user's config carries (RING_, POUNCE_, LURE_, HAUNT_, AMBUSH_, PRESS_, SWARM_); what each pattern
-- does with them is defined here, in the comments, and is not a copy of anything: BasedHub's own versions are not this.
return function(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local Patterns = {}
	local sin, cos, floor, max, min, pi = math.sin, math.cos, math.floor, math.max, math.min, math.pi

	Patterns.DEFAULT_K = {
		RING_CLEAR = 35, RING_HOLD = 0.25, RING_STEP = 34,
		POUNCE_HIGH = 200, POUNCE_LOW = 24, POUNCE_MARKS = 24, POUNCE_OUT = 150, POUNCE_STAY = 0.5, POUNCE_PERIOD = 2,
		LURE_BALL = 60, LURE_HIGH = 90, LURE_REST = 0.6, LURE_RISE = 60, LURE_SHOW = 0.25,
		HAUNT_APART = 20, HAUNT_MOST = 110, HAUNT_MEMORY = 6,
		AMBUSH_GRID = 28, AMBUSH_LEAST = 3, AMBUSH_MARKS = 24, AMBUSH_RANGE = 180, AMBUSH_STAY = 0.33,
		PRESS_HEX = 36, PRESS_NEAR = 14, PRESS_OUTSIDE = 15, PRESS_PERIOD = 1,
		SWARM_CLEAR = 27, SWARM_FAR = 80, SWARM_MIN = 60, SWARM_STEP = 38,
	}

	local function num(k, name)
		local value = k and k[name]
		if value == nil then value = Patterns.DEFAULT_K[name] end
		return value
	end

	local function at(target, angle, radius, height)
		local spot = target + Vector3.new(sin(angle) * radius, height or 0, cos(angle) * radius)
		if radius < 1e-3 then return CFrame.new(spot) end
		return CFrame.lookAt(spot, Vector3.new(target.X, spot.Y, target.Z)) -- (level: upright, facing the target)
	end

	-- ring: a new place on a ring of RING_CLEAR studs round the target every RING_HOLD s, RING_STEP studs of arc along
	function Patterns.ring(target, t, k)
		local radius, hold, step = num(k, "RING_CLEAR"), max(num(k, "RING_HOLD"), 0.02), num(k, "RING_STEP")
		return at(target, floor(t / hold) * step / max(radius, 1), radius, 0)
	end

	-- pounce: out at POUNCE_OUT studs and POUNCE_HIGH up, then down to POUNCE_LOW studs from the target for POUNCE_STAY s
	-- every POUNCE_PERIOD s; the bearing moves one of POUNCE_MARKS places each time
	function Patterns.pounce(target, t, k)
		local period = max(num(k, "POUNCE_PERIOD"), num(k, "POUNCE_STAY") + 0.05)
		local cycle = floor(t / period)
		local marks = max(floor(num(k, "POUNCE_MARKS")), 1)
		local bearing = (cycle % marks) * 2 * pi / marks
		if t - cycle * period < num(k, "POUNCE_STAY") then return at(target, bearing, num(k, "POUNCE_LOW"), 0) end
		return at(target, bearing, num(k, "POUNCE_OUT"), num(k, "POUNCE_HIGH"))
	end

	-- lure: shown at LURE_BALL studs and LURE_RISE up for LURE_SHOW s, then hidden LURE_HIGH up for LURE_REST s
	function Patterns.lure(target, t, k)
		local show, rest = num(k, "LURE_SHOW"), num(k, "LURE_REST")
		local length = max(show + rest, 0.05)
		local cycle = floor(t / length)
		local bearing = cycle * 2.399963 -- the golden angle: no two shows in a row from the same side
		if t - cycle * length < show then return at(target, bearing, num(k, "LURE_BALL"), num(k, "LURE_RISE")) end
		return at(target, bearing, num(k, "LURE_BALL"), num(k, "LURE_HIGH"))
	end

	-- haunt: HAUNT_APART studs behind where the target is heading (its look when it stands), never past HAUNT_MOST
	function Patterns.haunt(target, t, k, ctx)
		local heading
		if ctx and ctx.vel and Vector3.new(ctx.vel.X, 0, ctx.vel.Z).Magnitude > 1 then
			heading = Vector3.new(ctx.vel.X, 0, ctx.vel.Z).Unit
		elseif ctx and ctx.look and Vector3.new(ctx.look.X, 0, ctx.look.Z).Magnitude > 0.01 then
			heading = Vector3.new(ctx.look.X, 0, ctx.look.Z).Unit
		else
			heading = Vector3.new(sin(t * 0.5), 0, cos(t * 0.5))
		end
		local apart = min(num(k, "HAUNT_APART"), num(k, "HAUNT_MOST"))
		if apart < 1e-3 then return CFrame.new(target) end
		local spot = target - heading * apart
		return CFrame.lookAt(spot, Vector3.new(target.X, spot.Y, target.Z))
	end

	-- ambush: AMBUSH_MARKS places on a spiral of spacing AMBUSH_GRID out to AMBUSH_RANGE, one every AMBUSH_STAY s
	-- (never nearer than AMBUSH_LEAST); the caller picks among them by what it can see
	function Patterns.ambush(target, t, k)
		local marks, grid = max(floor(num(k, "AMBUSH_MARKS")), 1), num(k, "AMBUSH_GRID")
		local index = floor(t / max(num(k, "AMBUSH_STAY"), 0.02)) % marks
		local radius = min(max(num(k, "AMBUSH_LEAST"), (index + 1) * grid / 3), num(k, "AMBUSH_RANGE"))
		return at(target, index * 2.399963, radius, 0)
	end

	-- press: the six corners of a hexagon, PRESS_NEAR studs out and PRESS_OUTSIDE further on the odd turns,
	-- one corner every PRESS_PERIOD / 6 s
	function Patterns.press(target, t, k)
		local period = max(num(k, "PRESS_PERIOD"), 0.06)
		local corner = floor(t / (period / 6))
		local radius = num(k, "PRESS_NEAR") + (corner % 2 == 1 and num(k, "PRESS_OUTSIDE") or 0)
		return at(target, (corner % 6) * pi / 3, radius, 0)
	end

	-- swarm: places SWARM_STEP studs of arc apart on a ring that breathes between SWARM_MIN and SWARM_FAR
	function Patterns.swarm(target, t, k)
		local low, high, clear = num(k, "SWARM_MIN"), num(k, "SWARM_FAR"), num(k, "SWARM_CLEAR")
		local radius = max(clear, low + (high - low) * (0.5 + 0.5 * sin(t * 0.8)))
		return at(target, floor(t / 0.2) * num(k, "SWARM_STEP") / max(radius, 1), radius, 0)
	end

	Patterns.list = { "ring", "pounce", "lure", "haunt", "ambush", "press", "swarm" }

	---@param name string
	---@return fun(target: Vector3, t: number, k: table?, ctx: table?): CFrame
	function Patterns.get(name) return Patterns[name] end

	-- how far from the target a pattern can put the body: [low, high] (the heights are on top, for the sky ones)
	Patterns.reach = {
		ring = function(k) return num(k, "RING_CLEAR"), num(k, "RING_CLEAR") end,
		pounce = function(k) return num(k, "POUNCE_LOW"), num(k, "POUNCE_OUT") end,
		lure = function(k) return num(k, "LURE_BALL"), num(k, "LURE_BALL") end,
		haunt = function(k) return 0, num(k, "HAUNT_MOST") end,
		ambush = function(k) return num(k, "AMBUSH_LEAST"), num(k, "AMBUSH_RANGE") end,
		press = function(k) return num(k, "PRESS_NEAR"), num(k, "PRESS_NEAR") + num(k, "PRESS_OUTSIDE") end,
		swarm = function(k) return min(num(k, "SWARM_CLEAR"), num(k, "SWARM_MIN")), max(num(k, "SWARM_FAR"), num(k, "SWARM_CLEAR")) end,
	}

	return Patterns
end
end)()
-- >>> pure/estimators.lua
DH.F.estimators = (function()
-- Resolver estimators. Pure: each one reads a short history of samples of one player and returns a guess of where the
-- body really is, with a confidence in 0..1; `combine` votes them. Nothing here touches Roblox, so each runs under Lune.
--
-- A sample is { t = clock seconds, pos = Vector3 (HumanoidRootPart), vel = Vector3?, look = Vector3?,
--               parts = { Name = Vector3 }?, moveDir = Vector3?, walk = number?, moving = boolean? }.
-- `list` is an array of samples, oldest first.
return function(env)
	local Vector3 = env.Vector3
	local Est = {}
	local sqrt, abs, max, min, floor, exp, huge = math.sqrt, math.abs, math.max, math.min, math.floor, math.exp, math.huge
	local ZERO = Vector3.new(0, 0, 0)

	Est.DEFAULT = {
		windowSeconds = 1.0,
		minSamples = 6,
		-- sanity gate
		maxJump = 30,      -- studs between two samples
		maxSpeed = 140,    -- studs/s a body can really reach (walk 16, sprint ~22, speed lock 40, a car ~100, a fall)
		mapHalf = 4000, mapTop = 1500, mapBottom = -60,
		-- dead reckoning
		extrapMax = 1.0, accelMax = 80,
		-- body parts
		partsDisagree = 6, partsStable = 3,
		-- animation / state cues
		stillDisp = 1.0, stillVel = 0.5, cueMin = 0.4, maxWalk = 40,
		-- pattern recognition
		hopMin = 6, hopRate = 0.35, clusterMinSep = 8, ringRadiusMin = 3, ringResidual = 0.35,
		-- combiner
		agreeSigma = 6, minConfidence = 0.35,
	}

	local function finite(v)
		return v ~= nil and v.X == v.X and v.Y == v.Y and v.Z == v.Z and abs(v.X) < huge and abs(v.Y) < huge and abs(v.Z) < huge
	end
	local function flat(v) return Vector3.new(v.X, 0, v.Z) end
	local META = { __index = Est.DEFAULT }
	local function cfgOf(cfg)
		if not cfg or cfg == Est.DEFAULT then return Est.DEFAULT end
		if getmetatable(cfg) ~= META then setmetatable(cfg, META) end
		return cfg
	end

	-- ---- history: a ring of samples, the last `seconds` of them
	function Est.history(seconds)
		local h = { items = {}, seconds = seconds or Est.DEFAULT.windowSeconds }
		function h:push(sample)
			local items = self.items
			items[#items + 1] = sample
			local cut = sample.t - self.seconds
			local drop = 0
			while drop < #items - 1 and items[drop + 1].t < cut do drop += 1 end
			if drop > 0 then
				local n = #items
				table.move(items, drop + 1, n, 1)
				for i = n - drop + 1, n do items[i] = nil end
			end
		end
		function h:list() return self.items end
		function h:last() return self.items[#self.items] end
		function h:count() return #self.items end
		function h:clear() self.items = {} end
		return h
	end

	-- ---- 1. sanity gate: is this sample a place a body can be?
	---@param sample table
	---@param prev table? the sample before it
	---@return boolean, string?
	function Est.gate(sample, prev, cfg)
		cfg = cfgOf(cfg)
		local p = sample.pos
		if not finite(p) then return false, "nan" end
		if abs(p.X) > cfg.mapHalf or abs(p.Z) > cfg.mapHalf or p.Y > cfg.mapTop or p.Y < cfg.mapBottom then return false, "bounds" end
		if prev and finite(prev.pos) then
			local d = (p - prev.pos).Magnitude
			local dt = max(sample.t - prev.t, 1 / 240)
			if d > cfg.maxJump and dt < 0.5 then return false, "jump" end
			if d > 2 and d / dt > cfg.maxSpeed then return false, "speed" end
		end
		return true
	end

	---Run the gate down a list: flags[i] = true when sample i passes.
	function Est.gated(list, cfg)
		local flags, reasons = {}, {}
		for i, sample in ipairs(list) do
			local ok, why = Est.gate(sample, list[i - 1], cfg)
			flags[i], reasons[i] = ok, why
		end
		return flags, reasons
	end

	---Index of the newest sample that passed the gate.
	function Est.lastGoodIndex(list, cfg)
		local flags = Est.gated(list, cfg)
		for i = #list, 1, -1 do if flags[i] then return i, flags end end
		return nil, flags
	end

	-- ---- 2. last known good, advanced by its velocity and the recent acceleration
	---@param memory table? { sample = the newest good sample ever seen }: used when the window holds none (a body that has been voided for a while)
	function Est.deadReckon(list, now, cfg, memory)
		cfg = cfgOf(cfg)
		local index, flags = Est.lastGoodIndex(list, cfg)
		if not index then
			local kept = memory and memory.sample
			if not (kept and finite(kept.pos)) then return nil end
			local age = max(now - kept.t, 0)
			local vel = finite(kept.vel) and kept.vel or ZERO
			if vel.Magnitude > cfg.maxSpeed then vel = vel.Unit * cfg.maxSpeed end
			local dt = min(age, cfg.extrapMax)
			return { pos = kept.pos + vel * dt, confidence = 0.5 * exp(-age / 0.8), method = "deadreckon", age = age, remembered = true }
		end
		local good = list[index]
		local dt = min(max(now - good.t, 0), cfg.extrapMax)
		local vel = good.vel
		if not finite(vel) then
			local before = list[index - 1]
			vel = before and (good.pos - before.pos) / max(good.t - before.t, 1 / 240) or ZERO
		end
		if vel.Magnitude > cfg.maxSpeed then vel = vel.Unit * cfg.maxSpeed end
		local accel = ZERO
		local a, b = list[index - 2], list[index - 1]
		if a and b and flags[index - 2] and flags[index - 1] and finite(a.vel) and finite(b.vel) then
			local span = max(good.t - a.t, 1 / 120)
			accel = (vel - a.vel) / span
			if accel.Magnitude > cfg.accelMax then accel = accel.Unit * cfg.accelMax end
			if dt > 0.5 then accel = accel * 0.5 end
		end
		local pos = good.pos + vel * dt + accel * (0.5 * dt * dt)
		local goodCount = 0
		for i = 1, #list do if flags[i] then goodCount += 1 end end
		local conf = exp(-dt / 0.8) * sqrt(goodCount / max(#list, 1))
		return { pos = pos, confidence = conf, method = "deadreckon", age = dt }
	end

	-- ---- the sample as the engine shows it: used when nothing says it is fake
	function Est.raw(list, cfg)
		cfg = cfgOf(cfg)
		local last = list[#list]
		if not last then return nil end
		local ok = Est.gate(last, list[#list - 1], cfg)
		return { pos = last.pos, confidence = ok and 0.6 or 0, method = "raw", gated = not ok }
	end

	-- ---- 3. body parts: the centroid of the parts that did not come from the root
	---Where the parts are now (mean over the newest few samples), whether or not the root agrees: what a hopping root is judged by.
	function Est.partsHint(list)
		local sum, count = ZERO, 0
		for i = #list, max(1, #list - 4), -1 do
			local sample = list[i]
			if sample.parts then
				for _, position in pairs(sample.parts) do
					if finite(position) then sum += position; count += 1 end
				end
			end
		end
		if count == 0 then return nil end
		return { pos = sum / count, confidence = 0.5, method = "parts" }
	end

	function Est.partsCentroid(list, cfg)
		cfg = cfgOf(cfg)
		local ds, newest, n = {}, nil, 0
		for _, sample in ipairs(list) do
			if sample.parts and finite(sample.pos) then
				local sum, count = ZERO, 0
				for _, position in pairs(sample.parts) do
					if finite(position) then sum += position; count += 1 end
				end
				if count > 0 then
					local centroid = sum / count
					ds[#ds + 1] = sample.pos - centroid
					newest, n = centroid, n + 1
				end
			end
		end
		if n < 3 then return nil end
		local mean = ZERO
		for _, d in ipairs(ds) do mean += d end
		mean = mean / n
		local spread = 0
		for _, d in ipairs(ds) do spread += (d - mean).Magnitude ^ 2 end
		spread = sqrt(spread / n)
		if mean.Magnitude > cfg.partsDisagree and spread < cfg.partsStable then
			local conf = min(0.95, mean.Magnitude / (cfg.partsDisagree * 3) + 0.3) * (1 - 0.5 * spread / cfg.partsStable)
			return { pos = newest, confidence = conf, method = "parts", disagree = mean.Magnitude }
		end
		return nil
	end

	-- ---- 4. animation / state cues: the body is told to move but the position stands still
	function Est.cues(list, now, cfg)
		cfg = cfgOf(cfg)
		local first, last = list[1], list[#list]
		if not (first and last) or #list < cfg.minSamples then return nil end
		local disp = (flat(last.pos) - flat(first.pos)).Magnitude
		local vel = last.vel and flat(last.vel).Magnitude or 0
		local moving = 0
		for _, sample in ipairs(list) do if sample.moving or (sample.moveDir and sample.moveDir.Magnitude > 0.1) then moving += 1 end end
		local frac = moving / #list
		if disp < cfg.stillDisp and vel < cfg.stillVel and frac > 0.7 and last.t - first.t >= cfg.cueMin then
			local dir = last.moveDir
			if not dir or dir.Magnitude < 0.1 then dir = last.look or ZERO end
			dir = flat(dir)
			local speed = min(last.walk or 16, cfg.maxWalk)
			local elapsed = min(last.t - first.t, 2)
			local pos = last.pos
			if dir.Magnitude > 0.01 then pos = pos + dir.Unit * speed * elapsed end
			return { pos = pos, confidence = 0.4 * exp(-elapsed / 3), method = "cues", frozen = true }
		end
		return nil
	end

	-- ---- 5. patterns: samples that hop about instead of travelling
	-- circle through the points in the ground plane (least squares): centre and radius, and how far the points stray from it
	local function fitCircle(points)
		local n = #points
		if n < 4 then return nil end
		-- (centred first: the sums of cubes of map coordinates are too big to keep the system well conditioned)
		local mx, mz = 0, 0
		for _, p in ipairs(points) do mx += p.X; mz += p.Z end
		mx, mz = mx / n, mz / n
		local sx, sz, sxx, szz, sxz, sxxx, szzz, sxzz, sxxz = 0, 0, 0, 0, 0, 0, 0, 0, 0
		for _, p in ipairs(points) do
			local x, z = p.X - mx, p.Z - mz
			sx += x; sz += z; sxx += x * x; szz += z * z; sxz += x * z
			sxxx += x * x * x; szzz += z * z * z; sxzz += x * z * z; sxxz += x * x * z
		end
		-- normal equations of  x^2 + z^2 + D x + E z + F = 0
		local a11, a12, a13 = sxx, sxz, sx
		local a22, a23 = szz, sz
		local b1, b2, b3 = -(sxxx + sxzz), -(sxxz + szzz), -(sxx + szz)
		-- solve the 3x3 system by Cramer's rule
		local function det(m11, m12, m13, m21, m22, m23, m31, m32, m33)
			return m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)
		end
		local d = det(a11, a12, a13, a12, a22, a23, a13, a23, n)
		if abs(d) < 1e-9 then return nil end
		local D = det(b1, a12, a13, b2, a22, a23, b3, a23, n) / d
		local E = det(a11, b1, a13, a12, b2, a23, a13, b3, n) / d
		local F = det(a11, a12, b1, a12, a22, b2, a13, a23, b3) / d
		local cx, cz = -D / 2, -E / 2
		local r2 = cx * cx + cz * cz - F
		if r2 <= 0 then return nil end
		local r = sqrt(r2)
		local resid = 0
		for _, p in ipairs(points) do resid += (sqrt((p.X - mx - cx) ^ 2 + (p.Z - mz - cz) ^ 2) - r) ^ 2 end
		return cx + mx, cz + mz, r, sqrt(resid / n)
	end

	local function median(values)
		table.sort(values)
		local n = #values
		if n == 0 then return 0 end
		if n % 2 == 1 then return values[(n + 1) / 2] end
		return (values[n / 2] + values[n / 2 + 1]) / 2
	end

	-- two clusters (k-means, k = 2, started at the two farthest points)
	local function twoClusters(points)
		local a, b, far = points[1], points[1], -1
		for i = 1, #points do
			for j = i + 1, #points do
				local d = (points[i] - points[j]).Magnitude
				if d > far then a, b, far = points[i], points[j], d end
			end
		end
		local ca, cb = a, b
		local sa, sb, na, nb, assign = ZERO, ZERO, 0, 0, {}
		for _ = 1, 5 do
			sa, sb, na, nb = ZERO, ZERO, 0, 0
			for i, p in ipairs(points) do
				if (p - ca).Magnitude <= (p - cb).Magnitude then assign[i] = 1; sa += p; na += 1 else assign[i] = 2; sb += p; nb += 1 end
			end
			if na > 0 then ca = sa / na end
			if nb > 0 then cb = sb / nb end
		end
		local va, vb = 0, 0
		for i, p in ipairs(points) do
			if assign[i] == 1 then va += (p - ca).Magnitude ^ 2 else vb += (p - cb).Magnitude ^ 2 end
		end
		local switches = 0
		for i = 2, #points do if assign[i] ~= assign[i - 1] then switches += 1 end end
		return { a = ca, b = cb, na = na, nb = nb, sa = na > 0 and sqrt(va / na) or 0, sb = nb > 0 and sqrt(vb / nb) or 0,
			sep = (ca - cb).Magnitude, switches = switches }
	end

	---A body that hops about (jitter, orbit, blink): where the hops are centred, or which of two clusters is the body.
	---`hint` is another estimate (the parts centroid) used to choose between two clusters.
	function Est.pattern(list, cfg, hint)
		cfg = cfgOf(cfg)
		local n = #list
		if n < cfg.minSamples then return nil end
		local points, hops = {}, 0
		for i, sample in ipairs(list) do
			if finite(sample.pos) then points[#points + 1] = sample.pos end
			if i > 1 and finite(sample.pos) and finite(list[i - 1].pos) and (sample.pos - list[i - 1].pos).Magnitude > cfg.hopMin then hops += 1 end
		end
		if #points < cfg.minSamples then return nil end
		local rate = hops / max(#points - 1, 1)
		if rate < cfg.hopRate then return nil end
		if #points > 40 then
			-- (the newest 40 are enough to see a pattern, and the clustering is quadratic)
			local keep = {}
			for i = #points - 39, #points do keep[#keep + 1] = points[i] end
			points = keep
		end

		local ys = {}
		for _, p in ipairs(points) do ys[#ys + 1] = p.Y end
		local sum = ZERO
		for _, p in ipairs(points) do sum += p end
		local centroid = sum / #points

		-- two clusters that take turns
		local c = twoClusters(points)
		if c.sep > cfg.clusterMinSep and (c.sa + c.sb) / 2 < c.sep * 0.25 and c.switches >= #points * 0.5 then
			local pick, share = c.a, c.na / #points
			if hint and finite(hint.pos) and (c.b - hint.pos).Magnitude < (c.a - hint.pos).Magnitude then pick, share = c.b, c.nb / #points end
			if not (hint and finite(hint.pos)) and c.nb > c.na then pick, share = c.b, c.nb / #points end
			return { pos = pick, confidence = min(0.8, 0.35 + rate * 0.4) * (hint and 1 or 0.7), method = "pattern", kind = "blink", rate = rate, share = share }
		end

		-- a ring or a disk about the body: its middle is the body
		local cx, cz, r, resid = fitCircle(points)
		if cx and r > cfg.ringRadiusMin and resid / r < cfg.ringResidual then
			return { pos = Vector3.new(cx, median(ys), cz), confidence = min(0.85, 0.4 + rate * 0.4) * (1 - 0.5 * resid / r), method = "pattern", kind = "ring", rate = rate, radius = r }
		end
		return { pos = Vector3.new(centroid.X, median(ys), centroid.Z), confidence = min(0.7, 0.3 + rate * 0.35), method = "pattern", kind = "scatter", rate = rate }
	end

	-- ---- learning: per target, per method weights nudged by whether shots at the guess did damage
	function Est.learner()
		local L = { weights = {}, shots = {} }
		function L:weight(method) return self.weights[method] or 1 end
		function L:reward(method, hit)
			local w = self.weights[method] or 1
			w = w * (hit and 1.15 or 0.93)
			self.weights[method] = min(max(w, 0.2), 4)
			local s = self.shots[method] or { hit = 0, miss = 0 }
			if hit then s.hit += 1 else s.miss += 1 end
			self.shots[method] = s
		end
		function L:decay(dt)
			for method, w in pairs(self.weights) do self.weights[method] = w + (1 - w) * min(dt * 0.02, 1) end
		end
		return L
	end

	-- ---- combiner: a weighted vote of the guesses that agree
	---@param estimates table[] each { pos, confidence, method }
	---@param weights table? method -> weight
	---@return table
	function Est.combine(estimates, weights, cfg)
		cfg = cfgOf(cfg)
		local usable = {}
		for _, e in ipairs(estimates) do
			if e and finite(e.pos) and e.confidence and e.confidence > 0 then
				usable[#usable + 1] = { e = e, s = e.confidence * ((weights and weights[e.method]) or 1) }
			end
		end
		if #usable == 0 then return { pos = nil, confidence = 0, method = "none", all = estimates } end
		local best, bestSupport, total = nil, -1, 0
		for _, u in ipairs(usable) do total += u.s end
		for _, u in ipairs(usable) do
			local support = 0
			for _, v in ipairs(usable) do
				local d = (u.e.pos - v.e.pos).Magnitude / cfg.agreeSigma
				support += v.s * exp(-d * d)
			end
			if support > bestSupport then best, bestSupport = u, support end
		end
		local sum, weight, topConf = ZERO, 0, 0
		for _, v in ipairs(usable) do
			if (v.e.pos - best.e.pos).Magnitude <= 2 * cfg.agreeSigma then
				sum += v.e.pos * v.s
				weight += v.s
				if v.e.confidence > topConf then topConf = v.e.confidence end
			end
		end
		local agreeShare = total > 0 and weight / total or 0
		return {
			pos = sum / weight,
			confidence = min(1, agreeShare * topConf * (1 + 0.15 * (#usable - 1))),
			method = best.e.method,
			all = estimates,
		}
	end

	---Every estimator on one history, then the vote.
	---@param list table[] samples, oldest first
	---@param now number
	---@param cfg table?
	---@param weights table? per-method weights from the learner
	function Est.estimate(list, now, cfg, weights, memory)
		cfg = cfgOf(cfg)
		local raw = Est.raw(list, cfg)
		local parts = Est.partsCentroid(list, cfg)
		local pattern = Est.pattern(list, cfg, parts or Est.partsHint(list))
		local cues = Est.cues(list, now, cfg)
		local reckon = Est.deadReckon(list, now, cfg, memory)
		-- a root that hops, or that the parts disagree with, or that stands still while told to walk, is not the place
		-- it shows: what is made from the root alone stops counting
		if pattern or parts then
			if raw then raw.confidence = raw.confidence * 0.2 end
			if reckon then reckon.confidence = reckon.confidence * 0.2 end
		elseif cues then
			if raw then raw.confidence = raw.confidence * 0.4 end
			if reckon then reckon.confidence = reckon.confidence * 0.4 end
		end
		-- (appended one by one: a nil in the middle of a table literal would end the list for ipairs)
		local estimates = {}
		for _, e in ipairs({ raw or false, parts or false, pattern or false, cues or false, reckon or false }) do
			if e then estimates[#estimates + 1] = e end
		end
		local result = Est.combine(estimates, weights, cfg)
		if raw and raw.gated and result.method == "raw" then result.method = reckon and "deadreckon" or "raw" end
		return result
	end

	return Est
end
end)()
-- >>> pure/voidsm.lua
DH.F.voidsm = (function()
-- Void phases. Pure: a state machine that says, each frame, whether the body is voided.
--   idle -> bait (body still shown for `baitDelay`) -> voided -> (calm for a full hold) -> idle
-- While anything asks for the void it stays; once nothing asks, it is released only after no threat has been within the
-- safe distance for a whole hold (a threat near = the hold starts over: "extend if a threat is near").
-- After a respawn it re-voids in steps: a long hold, then shorter ones with a short peek between; at each peek a threat
-- near sends it into the next, shorter hold, none releases it.
return function()
	local SM = {}
	local max, min = math.max, math.min

	SM.DEFAULT = {
		baitDelay = 0.1,
		hold = 0.6,
		peek = 0.12,
		ramp = { 3.2, 0.55, 0.25, 0.15 },
	}

	---@param cfg table? overrides of SM.DEFAULT
	function SM.new(cfg)
		local merged = table.clone(SM.DEFAULT)
		for key, value in pairs(cfg or {}) do merged[key] = value end
		local m = { cfg = merged, phase = "idle", since = 0, requests = {}, rampIdx = nil, lastThreat = -math.huge, entered = 0, releases = 0 }

		---Ask for the void. `ttl` (seconds) makes the request lapse by itself; none keeps it until cancel.
		function m:request(source, now, ttl)
			self.requests[source] = { untilT = ttl and (now + ttl) or nil }
		end

		function m:cancel(source) self.requests[source] = nil end
		function m:wanted() return next(self.requests) ~= nil end

		---The body just came back from a death: void it again in steps.
		function m:respawned(now)
			self.rampIdx, self.phase, self.since = 1, "voided", now
			self.lastThreat = -math.huge
			self.entered = now
		end

		function m:reset()
			self.phase, self.rampIdx, self.requests, self.lastThreat = "idle", nil, {}, -math.huge
		end

		---@param now number
		---@param threatNear boolean a threat is inside the safe distance right now
		---@return table state { voided, phase, holdLeft, ramp }
		function m:update(now, threatNear)
			for source, request in pairs(self.requests) do
				if request.untilT and now >= request.untilT then self.requests[source] = nil end
			end
			if threatNear then self.lastThreat = now end
			local want = next(self.requests) ~= nil
			local cfgm = self.cfg

			if self.phase == "idle" and want then
				self.phase, self.since = "bait", now
			end
			if self.phase == "bait" then
				if not want then
					self.phase = "idle"
				elseif now - self.since >= cfgm.baitDelay then
					self.phase, self.since, self.entered = "voided", now, now
				end
			end
			if self.phase == "voided" then
				if want and self.rampIdx then self.rampIdx = nil end
				if self.rampIdx then
					if now - self.since >= cfgm.ramp[self.rampIdx] then self.phase, self.since = "peek", now end
				elseif not want then
					local calmFrom = max(self.lastThreat, self.since)
					if now - calmFrom >= cfgm.hold then
						self.phase = "idle"
						self.releases += 1
					end
				end
			end
			if self.phase == "peek" and now - self.since >= cfgm.peek then
				if self.lastThreat >= self.since then
					self.rampIdx = min(self.rampIdx + 1, #cfgm.ramp)
					self.phase, self.since = "voided", now
				else
					self.phase, self.rampIdx = "idle", nil
					self.releases += 1
				end
			end

			local left = 0
			if self.phase == "voided" then
				local need = self.rampIdx and cfgm.ramp[self.rampIdx] or cfgm.hold
				left = self.rampIdx and max(0, need - (now - self.since)) or max(0, need - (now - max(self.lastThreat, self.since)))
			end
			return { voided = self.phase == "voided", phase = self.phase, holdLeft = left, ramp = self.rampIdx, wanted = want }
		end

		return m
	end

	return SM
end
end)()
-- >>> pure/threat.lua
DH.F.threat = (function()
-- Defense decisions. Pure: every "is this a threat / should the body go to the void" question is a function of plain tables,
-- so each can be tested without a game.
--
-- me      = { pos = Vector3, ko = bool, health = number, maxHealth = number, armor = number, protected = bool }
-- other   = { id, pos = Vector3, vel = Vector3?, ko = bool, friend = bool, protected = bool, tool = "gun"|"flame"|"melee"|"none",
--             aimingAtMe = bool?, still = number? (seconds standing still), teleported = bool? }
return function()
	local Threat = {}
	local max, min, clamp = math.max, math.min, math.clamp

	Threat.DEFAULT = {
		safeDistance = 90,   -- inside this, an armed player is a threat
		gunRange = 300,      -- a gun reaches this far
		flameRange = 25,
		meleeRange = 10,
		bagRange = 12,       -- a knocked body can be picked up from this close
		bagLead = 1.0,       -- seconds: someone who will be within bagRange this soon counts as there already
		teleportJump = 80,   -- studs in one sample
		teleportRange = 150, -- a teleporter this close to a knocked body is a bagger
		koHealth = 5,        -- a body at or under this health counts as knocked
		baitStill = 1.0,     -- seconds an armed player stands still near the return spot to count as a camper
		baitRange = 160,
		unsafeScore = 0.25,  -- a score at or above this makes the strafe override's `unsafe` true
	}

	local function cfgOf(cfg)
		if not cfg then return Threat.DEFAULT end
		if getmetatable(cfg) == nil then setmetatable(cfg, { __index = Threat.DEFAULT }) end
		return cfg
	end

	function Threat.knocked(me, cfg)
		cfg = cfgOf(cfg)
		return me.ko == true or (me.health ~= nil and me.health <= cfg.koHealth)
	end

	local function counts(other)
		return other and not other.friend and not other.ko and not other.protected
	end

	---Can this player hurt me from where they are? 0 (no) to about 1 (certainly): by what they hold and how far.
	function Threat.score(me, other, cfg)
		cfg = cfgOf(cfg)
		if not counts(other) or me.protected then return 0 end
		local dist = (other.pos - me.pos).Magnitude
		local base
		if other.tool == "gun" then
			if dist > cfg.gunRange then return 0 end
			base = 0.5 + 0.5 * clamp(1 - dist / cfg.gunRange, 0, 1)
		elseif other.tool == "flame" then
			if dist > cfg.flameRange * 2 then return 0 end
			base = clamp(1.2 - dist / (cfg.flameRange * 2), 0, 1.2)
		elseif other.tool == "melee" then
			if dist > cfg.meleeRange * 2 then return 0 end
			base = clamp(1 - dist / (cfg.meleeRange * 2), 0, 1) * 0.8
		else
			return 0
		end
		if other.aimingAtMe then base *= 1.5 end
		return base
	end

	---Seconds until `other` is within `range` of me going at its own speed (math.huge when it is not closing).
	function Threat.timeToReach(me, other, range)
		local offset = me.pos - other.pos
		local dist = offset.Magnitude
		if dist <= range then return 0 end
		local vel = other.vel
		if not vel or offset.Magnitude < 1e-6 then return math.huge end
		local closing = vel:Dot(offset.Unit)
		if closing <= 0.5 then return math.huge end
		return (dist - range) / closing
	end

	---A jump too big for a body walking: someone who appears next to a knocked player to bag it.
	---@param prev Vector3 @param cur Vector3 @param dt number
	function Threat.teleport(prev, cur, dt, cfg)
		cfg = cfgOf(cfg)
		if not prev or not cur then return false end
		local d = (cur - prev).Magnitude
		return d >= cfg.teleportJump and (dt or 0) < 0.5
	end

	---Anti-bag: I am knocked and someone is near, or about to be (or a teleporter is near).
	---@return boolean, string?
	function Threat.antiBag(me, players, cfg)
		cfg = cfgOf(cfg)
		if not Threat.knocked(me, cfg) then return false end
		for _, other in ipairs(players) do
			if counts(other) then
				local dist = (other.pos - me.pos).Magnitude
				if dist <= cfg.bagRange then return true, "near:" .. tostring(other.id) end
				if Threat.timeToReach(me, other, cfg.bagRange) <= cfg.bagLead then return true, "closing:" .. tostring(other.id) end
				if other.teleported and dist <= cfg.teleportRange then return true, "teleporter:" .. tostring(other.id) end
			end
		end
		return false
	end

	---Anti-flame: a flamethrower within reach, or closing on me fast enough to be.
	---@return boolean, string?
	function Threat.antiFlame(me, players, cfg)
		cfg = cfgOf(cfg)
		if me.protected then return false end
		for _, other in ipairs(players) do
			if counts(other) and other.tool == "flame" then
				local dist = (other.pos - me.pos).Magnitude
				if dist <= cfg.flameRange then return true, "flame:" .. tostring(other.id) end
				if Threat.timeToReach(me, other, cfg.flameRange) <= cfg.bagLead then return true, "closing:" .. tostring(other.id) end
			end
		end
		return false
	end

	---Anti-bait: an armed player standing still near where I would come back out is waiting for me; stay hidden.
	---@param returnPos Vector3 where the body goes when released
	---@return boolean, string?
	function Threat.camper(returnPos, players, cfg)
		cfg = cfgOf(cfg)
		for _, other in ipairs(players) do
			if counts(other) and (other.tool == "gun" or other.tool == "flame") and (other.still or 0) >= cfg.baitStill then
				if (other.pos - returnPos).Magnitude <= cfg.baitRange then return true, "camper:" .. tostring(other.id) end
			end
		end
		return false
	end

	---The whole picture for one frame.
	---@return table { threatNear, unsafe, top, antiBag, antiFlame, camper, reasons }
	function Threat.assess(me, players, cfg, returnPos)
		cfg = cfgOf(cfg)
		local top, topScore, near = nil, 0, false
		for _, other in ipairs(players) do
			local score = Threat.score(me, other, cfg)
			if score > topScore then top, topScore = other, score end
			if score > 0 and (other.pos - me.pos).Magnitude <= cfg.safeDistance then near = true end
		end
		local bag, bagWhy = Threat.antiBag(me, players, cfg)
		local flame, flameWhy = Threat.antiFlame(me, players, cfg)
		local camp, campWhy = false, nil
		if returnPos then camp, campWhy = Threat.camper(returnPos, players, cfg) end
		local reasons = {}
		if bag then reasons[#reasons + 1] = bagWhy end
		if flame then reasons[#reasons + 1] = flameWhy end
		if camp then reasons[#reasons + 1] = campWhy end
		return {
			threatNear = near or bag or flame,
			unsafe = topScore >= cfg.unsafeScore,
			top = top, topScore = topScore,
			antiBag = bag, antiFlame = flame, camper = camp,
			reasons = reasons,
		}
	end

	return Threat
end
end)()
-- >>> pure/targeting.lua
DH.F.targeting = (function()
-- Ragebot target choice. Pure: filters, scores and the sticky pick, over plain tables.
--
-- candidate = { id, name, pos = Vector3, health, armor, ko, dead, friend, team, safeZone, forceField, visible = bool?,
--               screenDist = number? (pixels from the mouse), aimAngle = number? (degrees off the camera line),
--               threat = number? (0..1, from Threat.score), crowd = number? (other targets within 60 studs) }
-- ctx       = { mePos = Vector3, meTeam = any, targets = { [id or name] = true }? }
return function()
	local T = {}
	local huge = math.huge

	T.MODES = { "closest-to-mouse", "closest-to-me", "lowest-health", "threat" }

	T.DEFAULT = {
		mode = "threat",
		fov = 160,            -- degrees off the camera line (dahood.aimFov), when the candidate has an aimAngle
		walls = true,         -- the candidate must be visible (dahood.walls)
		teamCheck = false,
		ignoreFriends = true,
		range = 900,
		switchWait = 0.14,    -- dahood.switchWait
		threatWeight = 4,     -- dahood.threatWeight
		spreadWeight = 2.5,   -- dahood.spreadWeight
		hysteresis = 0.15,    -- a new best must beat the held target by this much (relative) to be worth a switch
	}

	local function cfgOf(cfg)
		if not cfg then return T.DEFAULT end
		if getmetatable(cfg) == nil then setmetatable(cfg, { __index = T.DEFAULT }) end
		return cfg
	end

	---Hard filters: nobody who fails one is ever a target.
	---@return boolean, string?
	function T.filter(c, ctx, cfg)
		cfg = cfgOf(cfg)
		if c.self then return false, "self" end
		if c.ko or c.dead then return false, "ko" end
		if c.safeZone then return false, "safezone" end
		if c.forceField then return false, "shield" end
		if cfg.ignoreFriends and c.friend then return false, "friend" end
		if cfg.teamCheck and c.team ~= nil and ctx.meTeam ~= nil and c.team == ctx.meTeam then return false, "team" end
		if ctx.targets and next(ctx.targets) ~= nil and not (ctx.targets[c.id] or ctx.targets[c.name]) then return false, "not listed" end
		if cfg.walls and c.visible == false then return false, "wall" end
		if c.aimAngle and cfg.fov and c.aimAngle > cfg.fov then return false, "fov" end
		if ctx.mePos and (c.pos - ctx.mePos).Magnitude > cfg.range then return false, "range" end
		return true
	end

	---Higher is better.
	function T.score(mode, c, ctx, cfg)
		cfg = cfgOf(cfg)
		local dist = ctx.mePos and (c.pos - ctx.mePos).Magnitude or 0
		if mode == "closest-to-mouse" then
			return -(c.screenDist or c.aimAngle or dist)
		elseif mode == "closest-to-me" then
			return -dist
		elseif mode == "lowest-health" then
			return -((c.health or 100) + (c.armor or 0))
		end
		-- threat: who can hurt me first, then who is alone, then who is near
		local alone = 1 / (1 + (c.crowd or 0))
		return cfg.threatWeight * (c.threat or 0) + cfg.spreadWeight * alone - dist / 400
	end

	---Pick a target and keep it. The held one is kept while it passes the filters; a better one replaces it only after
	---`switchWait` seconds since the last switch and by `hysteresis`. A held one that fails a filter is dropped at once.
	---@param state table { id = any?, since = number } (keep it between calls)
	---@param candidates table[]
	---@param now number
	---@return any, table state, table? entry
	function T.pick(state, candidates, now, ctx, cfg)
		cfg = cfgOf(cfg)
		local best, bestScore, held, heldScore = nil, -huge, nil, -huge
		for _, c in ipairs(candidates) do
			if T.filter(c, ctx, cfg) then
				local s = T.score(cfg.mode, c, ctx, cfg)
				if s > bestScore then best, bestScore = c, s end
				if c.id == state.id then held, heldScore = c, s end
			end
		end
		if held then
			if best and best.id ~= held.id and now - (state.since or 0) >= cfg.switchWait
				and bestScore > heldScore + math.abs(heldScore) * cfg.hysteresis + 1e-9 then
				state.id, state.since = best.id, now
				return best.id, state, best
			end
			return held.id, state, held
		end
		if best and (state.id == nil or now - (state.since or 0) >= 0) then
			state.id, state.since = best.id, now
			return best.id, state, best
		end
		state.id = nil
		return nil, state
	end

	return T
end
end)()
-- >>> pure/modes.lua
DH.F.modes = (function()
-- Fake position modes. Pure: where the server is told the body is, from where it really is.
--   static  the real place plus a fixed offset in world axes
--   follow  the real place plus an offset in the body's own frame (it turns with you)
--   jitter  a random place inside a radius of the real one, re-rolled every `rate` milliseconds
--   anchor  one world place, held while the real body moves (taken from the real body when first asked, or set)
return function(env)
	local Vector3, CFrame = env.Vector3, env.CFrame
	local Modes = {}
	local sqrt, cos, sin, pi = math.sqrt, math.cos, math.sin, math.pi

	Modes.names = { "static", "follow", "jitter", "anchor" }

	---State for one use of the modes (keep it between calls).
	function Modes.new()
		return { anchor = nil, jitterAt = -math.huge, jitterOffset = Vector3.new(0, 0, 0) }
	end

	function Modes.setAnchor(state, cframe) state.anchor = cframe end
	function Modes.clearAnchor(state) state.anchor = nil end

	---@param name string
	---@param state table from Modes.new
	---@param real CFrame where the body really is
	---@param opts table { offset = Vector3, radius = number, rate = ms }
	---@param now number clock in seconds
	---@param rng table with :NextNumber() in [0, 1)
	---@return CFrame?
	function Modes.compute(name, state, real, opts, now, rng)
		if name == "static" then
			return CFrame.new(real.Position + opts.offset) * real.Rotation
		elseif name == "follow" then
			return real * CFrame.new(opts.offset)
		elseif name == "jitter" then
			local every = math.max((opts.rate or 100) / 1000, 0.005)
			if now - state.jitterAt >= every then
				local turn, reach = rng:NextNumber() * 2 * pi, sqrt(rng:NextNumber()) * (opts.radius or 10)
				state.jitterOffset = Vector3.new(cos(turn) * reach, 0, sin(turn) * reach)
				state.jitterAt = now
			end
			return CFrame.new(real.Position + state.jitterOffset) * real.Rotation
		elseif name == "anchor" then
			if not state.anchor then state.anchor = real end
			return state.anchor
		end
		return nil
	end

	return Modes
end
end)()
-- >>> pure/physcore.lua
DH.F.physcore = (function()
-- PhysicsRepRootPart ride: the logic of attaching the local body's replicated movement to a target's root part.
-- Pure over an `io` table, so the rules (what makes it let go, what outranks it) are tested without a game.
--
-- What is MEASURED (2026-11-08, Potassium 2.6.0, Strike v3) and what is not: while the property holds another root, the CFrame the
-- local root is given is read by the server and other clients RELATIVE to that root, so a spot is sent as
-- targetRoot.CFrame:ToObjectSpace(spot). Whether Volt allows the write, whether nil is accepted back and what the server does are
-- the things the live probe answers (status() carries the exact error when one is refused).
--
-- io = {
--   now = function() -> seconds,
--   isPart = function(x) -> bool, inWorld = function(part) -> bool, isLocal = function(part) -> bool,
--   localRoot = function() -> part?, distance = function(partA, partB) -> number,
--   get = function(part, name) -> ok, value|err, set = function(part, name, value) -> ok, err?,
-- }
return function(env)
	local CFrame = env.CFrame
	local Phys = {}

	-- who wins when features collide
	Phys.PRIORITY = { panic = 5, defense = 4, physrep = 3, fakepos = 2, normal = 1 }

	Phys.DEFAULT = { maxRange = 60, offset = nil, property = "PhysicsRepRootPart" }

	function Phys.new(io, cfg)
		local merged = { maxRange = Phys.DEFAULT.maxRange, offset = CFrame.new(0, 3, 0), property = Phys.DEFAULT.property }
		for key, value in pairs(cfg or {}) do merged[key] = value end
		local p = {
			cfg = merged, io = io,
			attached = false, target = nil, offset = merged.offset, saved = nil, savedKnown = false,
			since = 0, lastError = nil, disabled = false, why = nil, attaches = 0, detaches = 0, lastReason = nil,
			panic = false, defense = false,
		}

		local function fail(message)
			p.lastError = message
			return false, message
		end

		---Attach to `targetRoot`; the spot kept is `offset` in its frame.
		---@param targetRoot any
		---@param offsetCF CFrame?
		---@return boolean, string?
		function p:attach(targetRoot, offsetCF)
			if self.disabled then return fail(self.why or "disabled") end
			if self.panic then return fail("panic") end
			if self.defense then return fail("defense void active") end
			if not io.isPart(targetRoot) then return fail("target is not a part") end
			if not io.inWorld(targetRoot) then return fail("target is not in the world") end
			if io.isLocal(targetRoot) then return fail("target is part of the local character") end
			local root = io.localRoot()
			if not root then return fail("no local root") end
			if self.attached then
				if self.target == targetRoot then
					self.offset = offsetCF or self.offset
					return true
				end
				self:detach("target changed")
			end
			local okRead, original = io.get(root, self.cfg.property)
			if not okRead then
				self.disabled, self.why = true, "cannot read " .. self.cfg.property .. ": " .. tostring(original)
				return fail(self.why)
			end
			local okWrite, err = io.set(root, self.cfg.property, targetRoot)
			if not okWrite then
				self.disabled, self.why = true, "cannot write " .. self.cfg.property .. ": " .. tostring(err)
				return fail(self.why)
			end
			self.saved, self.savedKnown = original, true
			self.attached, self.target, self.offset, self.since = true, targetRoot, offsetCF or merged.offset, io.now()
			self.attaches += 1
			self.lastError = nil
			return true
		end

		---Let go: put the saved value back (the local assembly root when nil is refused). Idempotent.
		---@param reason string?
		function p:detach(reason)
			if not self.attached then return true end
			local root = io.localRoot()
			local ok = true
			if root then
				local okSet = io.set(root, self.cfg.property, self.saved)
				if not okSet then
					local okOwn, err = io.set(root, self.cfg.property, root)
					if not okOwn then ok = false; self.lastError = "could not restore: " .. tostring(err) end
				end
			end
			self.attached, self.target, self.lastReason = false, nil, reason or "detach"
			self.detaches += 1
			return ok
		end

		function p:isAttached() return self.attached end
		function p:getTarget() return self.target end

		---Every frame while attached: check each reason to let go. `ctx` carries what the caller knows:
		---{ targetKO, targetDead, targetGone, localKO, localRespawned, requested = part? (a new target), defense, panic }
		---@return boolean stillAttached, string? reason
		function p:tick(ctx)
			if not self.attached then return false end
			ctx = ctx or {}
			local reason
			if ctx.panic then reason = "panic"
			elseif ctx.defense then reason = "defense void"
			elseif ctx.localKO then reason = "local KO"
			elseif ctx.localRespawned then reason = "local respawn"
			elseif ctx.targetKO then reason = "target KO"
			elseif ctx.targetDead then reason = "target dead"
			elseif ctx.targetGone then reason = "target left"
			elseif not io.isPart(self.target) or not io.inWorld(self.target) then reason = "target part gone (respawn)"
			elseif ctx.requested and ctx.requested ~= self.target then reason = "target changed"
			else
				local root = io.localRoot()
				if not root then reason = "no local root"
				elseif io.distance(root, self.target) > self.cfg.maxRange and not ctx.ignoreRange then reason = "out of range" end
			end
			if reason then self:detach(reason); return false, reason end
			return true
		end

		---A panic or defense request outranks the ride: it detaches first. Returns whether the ride may go on.
		function p:setPanic(on) self.panic = on == true; if on then self:detach("panic") end end
		function p:setDefense(on) self.defense = on == true; if on then self:detach("defense void") end end

		---`disable()` of the module: detach and refuse to attach again.
		function p:shutdown()
			self:detach("shutdown")
			self.disabled, self.why = true, "shut down"
		end

		function p:status()
			return {
				attached = self.attached, target = self.target, lastError = self.lastError, disabled = self.disabled, why = self.why,
				age = self.attached and (io.now() - self.since) or 0, attaches = self.attaches, detaches = self.detaches,
				lastReason = self.lastReason,
			}
		end

		return p
	end

	-- ---- geometry, pure
	---Where the server has the local body while attached: the spot in the target's frame.
	---@param targetCF CFrame @param offsetCF CFrame
	function Phys.serverBody(targetCF, offsetCF) return targetCF * offsetCF end

	---The origin a shot must carry while attached: the handle as the server reads it, from the glued body.
	---@param targetCF CFrame the target root's CFrame @param offsetCF CFrame
	---@param rootCF CFrame the local root's real CFrame @param handleCF CFrame the gun handle's real CFrame
	function Phys.shotOrigin(targetCF, offsetCF, rootCF, handleCF)
		return (targetCF * offsetCF * rootCF:ToObjectSpace(handleCF)).Position
	end

	---When the property cannot be used: a world-space spot kept with the target's velocity.
	---@param targetPos Vector3 @param targetVel Vector3 @param prediction number seconds @param offsetVec Vector3
	function Phys.fallbackSpot(targetPos, targetVel, prediction, offsetVec)
		return targetPos + targetVel * prediction + offsetVec
	end

	return Phys
end
end)()
-- >>> pure/cfgstore.lua
DH.F.cfgstore = (function()
-- Config store. Pure: a schema of settings, a coerce-or-default rule for every kind, and a JSON load that tolerates garbage.
-- In the hub the values live in BasedHub's own Config (so the user's saved profiles keep working); this store is what the suite
-- falls back on when the hub is not there, and what the offline tests check the rules on. Both give get / set / define / on.
--
-- def = { kind = "toggle"|"slider"|"dropdown"|"keybind"|"input"|"number", default = any,
--         min = n?, max = n?, step = n?, options = { { value, label }, ... }? }
return function()
	local Store = {}
	local floor, clamp = math.floor, math.clamp

	---Make `value` fit `def`: returns the coerced value and whether it had to change.
	function Store.coerce(def, value)
		local kind = def.kind
		if kind == "toggle" then
			if type(value) == "boolean" then return value, false end
			if value == 1 or value == "true" then return true, true end
			if value == 0 or value == "false" then return false, true end
			return def.default, true
		elseif kind == "slider" or kind == "number" then
			local n = tonumber(value)
			if n == nil or n ~= n or n == math.huge or n == -math.huge then return def.default, true end
			local out = n
			if def.min and def.max then out = clamp(out, def.min, def.max) end
			if def.step and def.step > 0 and def.min then out = def.min + floor((out - def.min) / def.step + 0.5) * def.step end
			if def.min and def.max then out = clamp(out, def.min, def.max) end
			return out, out ~= value
		elseif kind == "dropdown" then
			for _, option in ipairs(def.options or {}) do
				if option[1] == value then return value, false end
			end
			return def.default, true
		elseif kind == "keybind" or kind == "input" then
			if type(value) == "string" then return value, false end
			return def.default, true
		end
		return value, false
	end

	---@param schema table id -> def
	---@param codec table? { encode = fn(table) -> string, decode = fn(string) -> table }
	function Store.new(schema, codec)
		local s = { schema = schema, values = {}, extra = {}, listeners = {}, codec = codec, dirty = false, rejected = {} }

		for id, def in pairs(schema) do s.values[id] = def.default end

		function s:define(id, default, def)
			if not self.schema[id] then self.schema[id] = def or { kind = "input", default = default } end
			if self.values[id] == nil then self.values[id] = default end
			return self.values[id]
		end

		function s:get(id)
			local v = self.values[id]
			if v == nil and self.schema[id] then return self.schema[id].default end
			return v
		end

		function s:set(id, value, quiet)
			local def = self.schema[id]
			if def then
				local fixed = Store.coerce(def, value)
				value = fixed
			end
			local old = self.values[id]
			self.values[id] = value
			if not quiet then self.dirty = true end
			if old ~= value then
				for _, fn in ipairs(self.listeners[id] or {}) do pcall(fn, value, old) end
				for _, fn in ipairs(self.listeners["*"] or {}) do pcall(fn, id, value, old) end
			end
			return value
		end

		function s:on(id, fn)
			local list = self.listeners[id] or {}
			list[#list + 1] = fn
			self.listeners[id] = list
			return { Disconnect = function() for i, f in ipairs(list) do if f == fn then table.remove(list, i); break end end end }
		end

		function s:isDefault(id)
			local def = self.schema[id]
			return def == nil or self.values[id] == def.default
		end

		---Load from a JSON string. Never throws; garbage gives defaults; unknown keys are kept aside (and written back);
		---a value of the wrong kind or out of range is coerced to what fits (counted in `rejected`).
		---@return boolean ok, string? reason
		function s:load(text)
			if not self.codec then return false, "no codec" end
			if type(text) ~= "string" or text == "" then return false, "empty" end
			local ok, data = pcall(self.codec.decode, text)
			if not ok or type(data) ~= "table" then return false, "not json" end
			local values = type(data.values) == "table" and data.values or data
			self.rejected = {}
			for id, value in pairs(values) do
				if type(id) == "string" then
					local def = self.schema[id]
					if def then
						local fixed, changed = Store.coerce(def, value)
						self.values[id] = fixed
						if changed then self.rejected[#self.rejected + 1] = id end
					else
						self.extra[id] = value
					end
				end
			end
			return true
		end

		---Only the values that differ from the default (and every unknown key that was loaded), as JSON.
		function s:dump()
			local out = {}
			for id, value in pairs(self.values) do
				local def = self.schema[id]
				if not def or value ~= def.default then out[id] = value end
			end
			for id, value in pairs(self.extra) do if out[id] == nil then out[id] = value end end
			return self.codec and self.codec.encode({ version = 1, values = out }) or nil
		end

		return s
	end

	return Store
end
end)()
-- >>> src/10_core.lua
-- (shared scope)
-- ---- core: shared helpers, the K table, config, cleanup list, logging
local genv = getgenv()
DH.version, DH.build = "1.0", "20261109.1400"
DH.GAME_ID = 1008451066
DH.isDaHood = game.GameId == DH.GAME_ID
DH.errors, DH.logs = 0, {}

local function service(name)
	local s = game:GetService(name)
	if cloneref then
		local ok, c = pcall(cloneref, s)
		if ok and c then return c end
	end
	return s
end
local S = {
	Players = service("Players"), Run = service("RunService"), Input = service("UserInputService"), Stats = service("Stats"),
	Http = service("HttpService"), Rep = service("ReplicatedStorage"), Gui = service("GuiService"),
}
DH.S = S
local LocalPlayer = S.Players.LocalPlayer
DH.LP = LocalPlayer
DH.ENV = { Vector3 = Vector3, CFrame = CFrame }
local ZERO = Vector3.new(0, 0, 0)
DH.ZERO = ZERO

-- ---- the cleanup list: every connection, hook, drawing and thread the suite makes is added here and released together
do
	local Janitor = {}
	Janitor.__index = Janitor
	function Janitor.new() return setmetatable({ items = {} }, Janitor) end
	function Janitor:add(item, label)
		if item ~= nil then self.items[#self.items + 1] = { item = item, label = label } end
		return item
	end
	local function dispose(item)
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then item:Disconnect()
		elseif kind == "function" then item()
		elseif kind == "Instance" then item:Destroy()
		elseif kind == "thread" then pcall(task.cancel, item)
		elseif kind == "table" then
			if item.Disconnect then item:Disconnect()
			elseif item.Destroy then item:Destroy()
			elseif item.Remove then item:Remove()
			elseif item.disable then item:disable() end
		end
	end
	function Janitor:clean()
		for i = #self.items, 1, -1 do
			local entry = self.items[i]
			local ok, err = pcall(dispose, entry.item)
			if not ok then DH.warn("janitor:" .. tostring(entry.label), tostring(err)) end
		end
		self.items = {}
	end
	function Janitor:size() return #self.items end
	DH.Janitor = Janitor
	DH.janitor = Janitor.new()
end

-- ---- logging: rate limited per key, kept in a small ring for the status panel; nothing here runs per packet
do
	local lastShown = {}
	function DH.warn(key, message, interval)
		local now = os.clock()
		if lastShown[key] and now - lastShown[key] < (interval or 5) then return end
		lastShown[key] = now
		local entry = { t = now, key = key, msg = tostring(message) }
		DH.logs[#DH.logs + 1] = entry
		if #DH.logs > 60 then table.remove(DH.logs, 1) end
		warn("[MONSTER] " .. key .. ": " .. entry.msg)
	end
	function DH.fail(where, err)
		DH.errors += 1
		DH.lastError = where .. ": " .. tostring(err)
		DH.warn("error:" .. where, tostring(err), 3)
	end
	---Wrap fn so an error is recorded and swallowed instead of thrown (hooks and connections never throw).
	function DH.safe(where, fn)
		return function(...)
			local ok, a, b, c = pcall(fn, ...)
			if not ok then DH.fail(where, a); return nil end
			return a, b, c
		end
	end
end

-- ---- events between the modules and from plugins ("unload", "panic", ...)
do
	local listeners = {}
	function DH.on(name, fn)
		local list = listeners[name] or {}
		listeners[name] = list
		list[#list + 1] = fn
		return { Disconnect = function() for i, f in ipairs(list) do if f == fn then table.remove(list, i) break end end end }
	end
	function DH.fire(name, ...)
		for _, fn in ipairs(table.clone(listeners[name] or {})) do
			local ok, err = pcall(fn, ...)
			if not ok then DH.fail("event:" .. name, err) end
		end
	end
end

-- ---- config: BasedHub's own Config holds the values (so the user's saved profiles keep working); a pure store stands in without it
DH.SCHEMA = {}
do
	local store
	local function backend()
		if Config then return Config end
		if not store then
			store = DH.F.cfgstore().new(DH.SCHEMA, {
				encode = function(t) return S.Http:JSONEncode(t) end,
				decode = function(s) return S.Http:JSONDecode(s) end,
			})
			local ok, text = pcall(readfile, "monster_dh.json")
			if ok and type(text) == "string" then store:load(text) end
			store.on_ = store.on
		end
		return store
	end
	---Register a setting. def = { kind, default, min, max, step, options, label, desc, group }
	function DH.define(id, def)
		DH.SCHEMA[id] = def
		local cfg = backend()
		if cfg == store then cfg:define(id, def.default, def) else cfg.define(id, def.default) end
		return id
	end
	function DH.get(id)
		local cfg = backend()
		local v
		if cfg == store then v = cfg:get(id) else v = cfg.get(id) end
		if v == nil and DH.SCHEMA[id] then return DH.SCHEMA[id].default end
		return v
	end
	---@param quiet boolean? true keeps it out of the saved profile (memory only)
	function DH.set(id, value, quiet)
		local cfg = backend()
		local def = DH.SCHEMA[id]
		if def then value = DH.F.cfgstore().coerce(def, value) end
		if cfg == store then return cfg:set(id, value, quiet) end
		return cfg.set(id, value, quiet)
	end
	function DH.watch(id, fn)
		local cfg = backend()
		if cfg == store then return cfg:on(id, fn) end
		local ok, conn = pcall(cfg.on, id, fn)
		return ok and conn or nil
	end
	---Fix saved values that no longer fit (a slider out of range, an option that was removed).
	function DH.sanitize()
		local fixed = 0
		local coerce = DH.F.cfgstore().coerce
		for id, def in pairs(DH.SCHEMA) do
			local v = DH.get(id)
			local ok, nv, changed = pcall(coerce, def, v)
			if ok and changed then DH.set(id, nv, true); fixed += 1 end
		end
		return fixed
	end
	function DH.save()
		if store and store.dirty then pcall(writefile, "monster_dh.json", store:dump() or "{}"); store.dirty = false end
	end
end

-- ---- K: every number that came from tuning, editable from the UI (ids monster.k.<NAME>)
do
	local DEFS = {
		-- name, default, min, max, step, group, description
		{ "INTERP", 0.18, 0, 0.6, 0.005, "net", "Roblox's interpolation buffer in seconds (lead = ping + this). Measured 2026-11-09 on Volt, two alts: 0.180 s (total shift 0.240 s, pings 59 ms)." },
		{ "NET_FAIL_COUNT", 20, 3, 200, 1, "net", "Send failures inside the window that count as raknet being denied." },
		{ "NET_FAIL_WINDOW", 2, 0.5, 10, 0.5, "net", "Seconds of the send-failure window." },
		{ "VOID_BAIT", 0.1, 0, 2, 0.05, "void", "Seconds the body is still shown before it goes (bait delay)." },
		{ "VOID_HOLD", 0.6, 0.1, 5, 0.05, "void", "Seconds with no threat near before the void is let go." },
		{ "VOID_PEEK", 0.12, 0.02, 1, 0.02, "void", "Seconds the body comes back between respawn holds." },
		{ "VOID_RAMP1", 3.2, 0.2, 10, 0.1, "void", "Respawn: first hold (s)." },
		{ "VOID_RAMP2", 0.55, 0.05, 5, 0.05, "void", "Respawn: second hold (s)." },
		{ "VOID_RAMP3", 0.25, 0.05, 5, 0.05, "void", "Respawn: third hold (s)." },
		{ "VOID_RAMP4", 0.15, 0.05, 5, 0.05, "void", "Respawn: last hold (s)." },
		{ "VOID_DEAD_HOLD", 4, 0.5, 20, 0.5, "void", "Seconds to void after the target dies." },
		{ "ORBIT_SPEED", 28, 1, 120, 1, "orbit", "Orbit: radians a second." },
		{ "ORBIT_RADIUS", 135, 5, 600, 1, "orbit", "Orbit: ring radius in studs." },
		{ "ORBIT_H1", 200000, 0, 1000000, 500, "orbit", "Orbit: height, high flip." },
		{ "ORBIT_H2", 199500, 0, 1000000, 500, "orbit", "Orbit: height, low flip." },
		{ "ORBIT_FLIP", 20, 1, 60, 1, "orbit", "Orbit: height flips a second." },
		{ "ORBIT_JIT_H", 10, 0, 60, 1, "orbit", "Orbit: horizontal jitter (studs)." },
		{ "ORBIT_JIT_V", 5, 0, 60, 1, "orbit", "Orbit: vertical jitter (studs)." },
		{ "ORBIT_JIT_RATE", 80, 1, 200, 1, "orbit", "Orbit: jitter rate (rad/s)." },
		{ "ORBIT_VEL", 420, 0, 1000, 10, "orbit", "Orbit: real-body speed when it is pushed round (studs/s)." },
		{ "ORBIT_GROUND_CAP", 38, 5, 100, 1, "orbit", "Real-body speed cap on the ground (the game's speed lock is 40)." },
		{ "PHYS_RANGE", 60, 5, 300, 1, "physrep", "PhysicsRepRootPart ride lets go past this distance (studs)." },
		{ "PHYS_UP", 3, 0, 12, 0.5, "physrep", "Default height above the target root while riding (studs)." },
		{ "RES_WINDOW", 1.0, 0.3, 3, 0.1, "resolver", "Seconds of history each estimator reads." },
		{ "RES_MAX_JUMP", 30, 5, 200, 1, "resolver", "A move this big in one sample is a teleport, not a body (studs)." },
		{ "RES_MAX_SPEED", 140, 20, 600, 5, "resolver", "Fastest a body can really go (studs/s)." },
		{ "RES_MIN_CONF", 0.35, 0, 1, 0.01, "resolver", "Below this the ragebot skips the shot (or spreads, by setting)." },
		{ "RES_SIGMA", 6, 1, 40, 1, "resolver", "Guesses closer than this agree (studs)." },
		{ "RES_WATCH", 0.6, 0.2, 2, 0.05, "resolver", "Seconds a shot is watched for damage (hit-confirm learning)." },
		{ "DEF_SAFE", 90, 10, 400, 5, "defense", "An armed player inside this is a threat (studs)." },
		{ "DEF_BAG", 12, 3, 60, 1, "defense", "Someone this close to a knocked body is a bagger (studs)." },
		{ "DEF_FLAME", 25, 5, 100, 1, "defense", "A flamethrower reaches this far (studs)." },
		{ "DEF_GUN", 300, 50, 1000, 10, "defense", "A gun counts out to this range (studs)." },
		{ "DEF_TELE", 80, 20, 400, 5, "defense", "A jump this big in a sample is a teleport (studs)." },
		{ "RAGE_ARRIVE", 0.25, 0.05, 1, 0.01, "rage", "Longest wait (s) after the server body hops before a shot is sent. The ping plus the pad below is used when it is shorter." },
		{ "RAGE_ARRIVE_PAD", 0.06, 0, 0.3, 0.01, "rage", "Added to the ping for the wait after a hop. Measured: a hop needs 0.10-0.23 s; the 0.25 s ring hold left no window at all (88 of 89 samples 'arriving')." },
		{ "RAGE_RANGE", 250, 30, 900, 10, "rage", "Longest shot (studs) when the weapon does not say." },
		{ "RAGE_STOMP", 3, 1.5, 9, 0.5, "rage", "Stomp height above the target (studs)." },
		{ "RAGE_RELOAD_AT", 0, 0, 10, 1, "rage", "Reload when the magazine is at or below this (0 = only when empty)." },
	}
	local byName = {}
	for _, d in ipairs(DEFS) do byName[d[1]] = d end
	DH.KDEFS = DEFS
	DH.K = {}
	function DH.K.def(name) return byName[name] end
	function DH.K.id(name) return "monster.k." .. name end
	function DH.K.get(name)
		local d = byName[name]
		local v = DH.get("monster.k." .. name)
		if v == nil then return d and d[2] end
		return v
	end
	for _, d in ipairs(DEFS) do
		DH.define("monster.k." .. d[1], { kind = "slider", default = d[2], min = d[3], max = d[4], step = d[5], label = d[1], desc = d[7], group = d[6] })
	end
end
local K = DH.K.get

-- ---- character helpers (the health gate used everywhere)
function DH.character() return LocalPlayer.Character end
function DH.root(character)
	character = character or LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end
function DH.humanoid(character)
	character = character or LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end
function DH.effects(character) return character and character:FindFirstChild("BodyEffects") end
function DH.knocked(character)
	local fx = DH.effects(character)
	local ko = fx and fx:FindFirstChild("K.O")
	return ko ~= nil and ko.Value == true
end
function DH.armor(character)
	local fx = DH.effects(character)
	local a = fx and fx:FindFirstChild("Armor")
	return a and a.Value or 0
end
---A body that is loaded, alive and standing: HumanoidRootPart, Humanoid, Head, LowerTorso, BodyEffects, Armor, FULLY_LOADED_CHAR, and not KO.
---@return boolean, string?
function DH.ready(character)
	if not character then return false, "no character" end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not (character:FindFirstChild("HumanoidRootPart") and humanoid and character:FindFirstChild("Head") and character:FindFirstChild("LowerTorso")) then return false, "parts" end
	local fx = character:FindFirstChild("BodyEffects")
	if not (fx and fx:FindFirstChild("Armor")) then return false, "effects" end
	if not character:FindFirstChild("FULLY_LOADED_CHAR") then return false, "loading" end
	if humanoid.Health <= 0 then return false, "dead" end
	if DH.knocked(character) then return false, "ko" end
	return true
end
function DH.hasShield(character) return character ~= nil and character:FindFirstChildOfClass("ForceField") ~= nil end

---Ping in seconds, and the lead a remote body needs: ping plus Roblox's interpolation buffer (measured, not a fixed 0.22).
do
	local item
	pcall(function() item = S.Stats.Network.ServerStatsItem:FindFirstChild("Data Ping") end)
	function DH.ping()
		local ok, v = pcall(function() return item and item:GetValue() or 100 end)
		return (ok and v or 100) / 1000
	end
	function DH.lag() return DH.ping() + K("INTERP") end
end

---A key setting ("E", "MouseButton2", "None") as something InputBegan can compare.
function DH.keyOf(name)
	if type(name) ~= "string" or name == "None" or name == "" then return nil end
	local ok, code = pcall(function() return Enum.KeyCode[name] end)
	if ok and code then return code end
	ok, code = pcall(function() return Enum.UserInputType[name] end)
	if ok and code then return code end
	return nil
end

-- ---- modules: each has init / enable / disable / status; panic and unload go through here
DH.modules = {}
function DH.register(name, module)
	module.name = name
	DH.modules[name] = module
	return module
end
function DH.status()
	local out = { build = DH.build, errors = DH.errors, lastError = DH.lastError }
	for name, module in pairs(DH.modules) do
		local ok, status = pcall(function() return module.status and module.status() or nil end)
		out[name] = ok and status or { error = tostring(status) }
	end
	return out
end
function DH.disableAll(reason)
	for name, module in pairs(DH.modules) do
		local ok, err = pcall(function() if module.disable then module.disable(reason) end end)
		if not ok then DH.fail("disable:" .. name, err) end
	end
end
-- >>> src/20_probe.lua
do
-- ---- probe: what this executor can do. Run first; its report names what the net layer is built on.
local Probe = { report = nil, census_ = nil }
DH.Probe = Probe

local CAPS = {
	"hookfunction", "hookmetamethod", "newcclosure", "checkcaller", "getgc", "getconnections", "setfflag", "getfflag", "getrawmetatable",
	"setreadonly", "isrbxactive", "request", "http_request", "Drawing", "sethiddenproperty", "gethiddenproperty", "cloneref", "getnamecallmethod",
	"setnamecallmethod", "firesignal", "fireclickdetector", "getcustomasset", "isfile", "readfile", "writefile", "appendfile", "delfile",
	"makefolder", "isfolder", "gethui", "setthreadidentity", "getthreadidentity", "loadstring", "buffer", "restorefunction", "clonefunction",
	"isexecutorclosure", "replicatesignal", "setscriptable", "isscriptable", "queue_on_teleport", "raknet",
}
local PATTERNS = { "raknet", "packet", "net", "send", "recv", "receive", "bitstream", "hook", "replic" }

---Every global (and table of globals) whose name looks network-like, and what raknet holds.
function Probe.scan()
	local out = { caps = {}, matches = {}, raknet = { present = false, functions = {} }, receive = {} }
	for _, name in ipairs(CAPS) do out.caps[name] = typeof(genv[name]) end
	local seen = {}
	for _, tbl in ipairs({ genv, type(getrenv) == "function" and getrenv() or {}, _G, shared }) do
		if type(tbl) == "table" and not seen[tbl] then
			seen[tbl] = true
			for key, value in pairs(tbl) do
				if type(key) == "string" then
					local lower = string.lower(key)
					for _, pattern in ipairs(PATTERNS) do
						if string.find(lower, pattern, 1, true) then out.matches[key] = typeof(value); break end
					end
				end
			end
		end
	end
	local rk = genv.raknet
	if type(rk) == "table" then
		out.raknet.present = true
		for key, value in pairs(rk) do
			out.raknet.functions[#out.raknet.functions + 1] = tostring(key) .. ":" .. typeof(value)
			local lower = string.lower(tostring(key))
			if typeof(value) == "function" and (string.find(lower, "recv", 1, true) or string.find(lower, "receive", 1, true)) then
				out.receive[#out.receive + 1] = tostring(key)
			end
		end
		table.sort(out.raknet.functions)
		if type(rk.is_enabled) == "function" then
			local ok, enabled = pcall(rk.is_enabled)
			out.raknet.enabled = ok and enabled or ("error: " .. tostring(enabled))
		end
	end
	return out
end

---PhysicsRepRootPart: can it be read, written back unchanged, set to something else and set back to nil? Exact errors are kept.
function Probe.physrep()
	local out = {}
	local root = DH.root()
	if not root then out.error = "no local root"; return out end
	if type(gethiddenproperty) ~= "function" then out.error = "no gethiddenproperty"; return out end
	local okRead, original = pcall(gethiddenproperty, root, "PhysicsRepRootPart")
	out.read = okRead
	out.default = okRead and tostring(original) or nil
	if not okRead then out.readError = tostring(original); return out end
	if type(sethiddenproperty) ~= "function" then out.error = "no sethiddenproperty"; return out end
	local okSame, errSame = pcall(sethiddenproperty, root, "PhysicsRepRootPart", original)
	out.writeSame, out.writeSameError = okSame, (not okSame) and tostring(errSame) or nil
	-- its own root, then nil: is a nil reset accepted?
	local okOwn, errOwn = pcall(sethiddenproperty, root, "PhysicsRepRootPart", root)
	out.writeOwn, out.writeOwnError = okOwn, (not okOwn) and tostring(errOwn) or nil
	local okNil, errNil = pcall(sethiddenproperty, root, "PhysicsRepRootPart", nil)
	out.nilAccepted, out.nilError = okNil, (not okNil) and tostring(errNil) or nil
	local okBack = pcall(sethiddenproperty, root, "PhysicsRepRootPart", original)
	out.restored = okBack
	local okAfter, after = pcall(gethiddenproperty, root, "PhysicsRepRootPart")
	out.after = okAfter and tostring(after) or nil
	return out
end

---Count what this client sends for `seconds` (one first byte per row: count, sizes, a sample). Reads only.
---@param seconds number
---@param done fun(result: table)
function Probe.census(seconds, done)
	local rk = genv.raknet
	if not (type(rk) == "table" and type(rk.add_send_hook) == "function") then done({ error = "no raknet.add_send_hook" }); return end
	local byId, total, shape = {}, 0, nil
	local function hook(packet)
		local ok = pcall(function()
			total += 1
			local id = packet.PacketId
			if not shape then
				shape = { luaType = typeof(packet), id = id }
				local okMeta, meta = pcall(getrawmetatable, packet)
				if okMeta and type(meta) == "table" then
					local names = {}
					for key in pairs(meta) do names[#names + 1] = tostring(key) end
					table.sort(names)
					shape.meta = table.concat(names, ",")
				end
				for _, member in ipairs({ "PacketId", "AsString", "AsBuffer", "AsArray", "Size", "Block", "Priority", "Reliability" }) do
					local okMember, value = pcall(function() return packet[member] end)
					shape[member] = okMember and typeof(value) or "error"
				end
			end
			local key = string.format("%02X", id)
			local row = byId[key]
			local size = #packet.AsString
			if not row then row = { n = 0, min = math.huge, max = 0 }; byId[key] = row end
			row.n += 1
			row.min = math.min(row.min, size)
			row.max = math.max(row.max, size)
		end)
		if not ok then Probe.faults = (Probe.faults or 0) + 1 end
	end
	local okAdd, errAdd = pcall(rk.add_send_hook, hook)
	if not okAdd then done({ error = "add_send_hook: " .. tostring(errAdd) }); return end
	Probe.census_ = hook
	task.delay(seconds, function()
		pcall(rk.remove_send_hook, hook)
		Probe.census_ = nil
		for _, row in pairs(byId) do
			if row.min == math.huge then row.min = nil end
			row.perSecond = math.floor(row.n / seconds * 10 + 0.5) / 10
		end
		done({ seconds = seconds, total = total, byId = byId, shape = shape, faults = Probe.faults or 0 })
	end)
end

---The whole report: executor, capabilities, network-like globals, raknet, PhysicsRepRootPart, a 3 s census. Written to
---monster_probe.json and printed as one line. `opts.census` = seconds (default 3, 0 skips).
function Probe.run(opts)
	opts = opts or {}
	local report = {
		time = os.time(), place = game.PlaceId, gameId = game.GameId,
		executor = (type(identifyexecutor) == "function" and table.concat({ tostring((select(1, identifyexecutor()))), tostring((select(2, identifyexecutor()))) }, " ")) or "unknown",
	}
	report.scan = Probe.scan()
	report.physrep = opts.physrep == false and { skipped = true } or Probe.physrep()
	report.net = DH.Net and DH.Net.status and DH.Net.status() or nil
	Probe.report = report
	local function finish()
		pcall(writefile, "monster_probe.json", S.Http:JSONEncode(report))
		print("MONSTER_PROBE " .. S.Http:JSONEncode({ executor = report.executor, raknet = report.scan.raknet, receive = report.scan.receive, physrep = report.physrep, census = report.census and report.census.total }))
		if opts.done then opts.done(report) end
	end
	local seconds = opts.census == nil and 3 or opts.census
	if seconds > 0 then
		Probe.census(seconds, function(result) report.census = result; finish() end)
	else
		finish()
	end
	return report
end

function Probe.init() end
function Probe.enable() end
function Probe.disable()
	local rk = genv.raknet
	if Probe.census_ and type(rk) == "table" then pcall(rk.remove_send_hook, Probe.census_); Probe.census_ = nil end
end
function Probe.status()
	return { ran = Probe.report ~= nil, censusRunning = Probe.census_ ~= nil, raknet = Probe.report and Probe.report.scan.raknet or nil }
end
DH.register("probe", Probe)
end
-- >>> src/30_net.lua
do
-- ---- net: the packet layer. Volt's raknet gives a send hook and send (no receive hook, measured 1.3.21.2); Da Hood's body is packet 0xA1.
-- While held, the engine's own body packets are blocked and ones carrying the server position are sent at a steady rate; released,
-- the real place is sent once and the engine's packets flow again. Anything that does not look like what was captured is passed
-- through untouched and logged once. Nothing here throws inside a hook.
local Codec = DH.F.codec()
DH.Codec = Codec
local Net = {
	on = false, available = false, denied = false, reason = nil,
	sent = 0, failed = 0, blocked = 0, unparsed = 0, noHeader = 0, hookFaults = 0,
	layouts = {}, hooks = { send = false, receive = false }, rxNames = {}, mode = "craft",
	rate = 0, lastHold = 0,
}
DH.Net = Net
genv.MONSTER_RAK = Net -- (what a test reads: on / sent / failed / blocked / available)

local rk = genv.raknet
local header, lastStamp, lastClock, needHeader = nil, 0, 0, false
local acc, want = 0, nil
local failStamps, rateCount, rateSince = {}, 0, os.clock()
local hookFn

-- ---- what raknet offers
local function scanRaknet()
	Net.available = type(rk) == "table" and type(rk.add_send_hook) == "function" and type(rk.send) == "function" and type(rk.remove_send_hook) == "function"
	Net.rxNames = {}
	if type(rk) == "table" then
		for key, value in pairs(rk) do
			local lower = string.lower(tostring(key))
			if typeof(value) == "function" and (string.find(lower, "recv", 1, true) or string.find(lower, "receive", 1, true)) then
				Net.rxNames[#Net.rxNames + 1] = tostring(key)
			end
		end
		if type(rk.is_enabled) == "function" then
			local ok, enabled = pcall(rk.is_enabled)
			if ok and enabled == false then Net.available, Net.reason = false, "raknet library is switched off in the executor" end
		end
	end
	Net.hooks.receive = #Net.rxNames > 0 -- (seen but not used: the incoming layout is not decoded, so the resolver polls)
end

---Stop crafting: the server is given the real place and the engine's packets flow. The caller falls back to the body swap.
function Net.deny(reason)
	if Net.denied then return end
	Net.denied, Net.reason, Net.available, Net.on = true, reason, false, false
	want = nil
	DH.warn("net.denied", reason, 0.1)
	DH.fire("net-denied", reason)
end

local function noteFailure()
	Net.failed += 1
	local now, window = os.clock(), DH.K.get("NET_FAIL_WINDOW")
	failStamps[#failStamps + 1] = now
	while failStamps[1] and now - failStamps[1] > window do table.remove(failStamps, 1) end
	if #failStamps >= DH.K.get("NET_FAIL_COUNT") then Net.deny("raknet.send failed " .. #failStamps .. " times in " .. window .. " s") end
end

-- ---- the send hook
local function onSend(packet)
	if packet.PacketId ~= Codec.ID then return end
	local s = packet.AsString
	if #s < 36 then return end
	local parsed = Codec.parse(s)
	if not parsed then
		-- not a layout that was captured: pass it through, remember the header of the body, say so once
		Net.unparsed += 1
		header = string.sub(s, 1, 34)
		DH.warn("net.unparsed", "a 0xA1 packet of " .. #s .. " bytes did not decode; passed through", 30)
		return
	end
	if parsed.stamp > lastStamp then lastStamp, lastClock = parsed.stamp, os.clock() end
	header, needHeader = string.sub(s, 1, 34), false
	Net.layouts[parsed.len] = (Net.layouts[parsed.len] or 0) + 1
	if Net.on and not Net.denied then
		packet:Block()
		Net.blocked += 1
	end
end

local function installHook()
	if hookFn or not Net.available then return Net.hooks.send end
	if genv.MONSTER_RAK_HOOK then pcall(rk.remove_send_hook, genv.MONSTER_RAK_HOOK); genv.MONSTER_RAK_HOOK = nil end
	hookFn = function(packet)
		local ok, err = pcall(onSend, packet)
		if not ok then Net.hookFaults += 1; Net.lastHookError = tostring(err) end
	end
	local ok, err = pcall(rk.add_send_hook, hookFn)
	if ok then
		Net.hooks.send = true
		genv.MONSTER_RAK_HOOK = hookFn
	else
		hookFn, Net.available, Net.reason = nil, false, "add_send_hook: " .. tostring(err)
	end
	return Net.hooks.send
end

local function removeHook()
	if hookFn and type(rk) == "table" then pcall(rk.remove_send_hook, hookFn) end
	if genv.MONSTER_RAK_HOOK == hookFn then genv.MONSTER_RAK_HOOK = nil end
	hookFn, Net.hooks.send = nil, false
end

-- a new body needs a new header before anything is sent
DH.janitor:add(DH.LP.CharacterAdded:Connect(function() header = nil; needHeader = false end), "net.respawn")

-- a disconnect prompt means the server did not like something: stop crafting
pcall(function()
	DH.janitor:add(S.Gui.ErrorMessageChanged:Connect(function()
		local message = ""
		pcall(function() message = tostring(S.Gui:GetErrorMessage()) end)
		if message ~= "" and Net.on then Net.deny("disconnect prompt: " .. string.sub(message, 1, 80)) end
	end), "net.errorprompt")
end)

-- ---- sending
---Send one body packet: the live header, a new stamp, and `framed` (length + payload).
local function sendFramed(framed)
	if not header then
		Net.noHeader += 1
		return false
	end
	local stamp = math.max(lastStamp + 1, lastStamp + math.floor((os.clock() - lastClock) * 240))
	local packet = Codec.build(header, stamp, framed)
	if not pcall(rk.send, buffer.fromstring(packet)) then
		noteFailure()
		return false
	end
	lastStamp, lastClock = stamp, os.clock()
	Net.sent += 1
	rateCount += 1
	local now = os.clock()
	if now - rateSince >= 1 then Net.rate, rateCount, rateSince = rateCount / (now - rateSince), 0, now end
	return true
end

---Tell the server the body is at `cframe` now (needs one real packet of this body seen first).
---@param cframe CFrame
---@return boolean
function Net.send(cframe)
	if Net.denied then return false end
	local p = cframe.Position
	local look = cframe.LookVector
	local payload = Codec.payload(p.X, p.Y, p.Z, math.atan2(-look.X, -look.Z))
	if not payload then
		Net.failed += 1
		return false
	end
	return sendFramed(Codec.frame(payload))
end

---Hold the server body at `cframe`, re-sent at the chosen rate (the first right away).
---@param cframe CFrame
---@param root BasePart
---@param dt number
---@param everyStep boolean? send on every call, not at the chosen rate
function Net.hold(cframe, root, dt, everyStep)
	if Net.denied or not Net.available then return end
	local first = not Net.on
	Net.on, want = true, cframe
	Net.lastHold = os.clock()
	if not header and root then
		-- (a body standing still sends nothing: a 0.02-stud shift makes one, which is blocked and read)
		needHeader = true
		root.CFrame = root.CFrame + Vector3.new(0.02, 0, 0)
		return
	end
	acc += dt
	local rate = DH.get("monster.rakRate") or 30
	if first or everyStep or acc >= 1 / math.max(rate, 5) then
		acc = 0
		Net.send(want)
	end
end

---Let go: the server is given the real place once, then the body's own packets flow again.
---@param cframe CFrame?
function Net.release(cframe)
	if not Net.on then return end
	if cframe then Net.send(cframe) end
	Net.on, want, acc = false, nil, 0
end

---The server body as the API asks for it: a CFrame holds it (the fake-position driver does the sending), nil lets go.
function Net.setServerCFrame(cframe)
	if DH.Fakepos then DH.Fakepos.setSource("net", cframe) end
end

function Net.needsHeader() return needHeader end
function Net.ready() return Net.available and not Net.denied and header ~= nil end

-- ---- incoming: Volt has no receive hook, so other players' bodies are read as the engine shows them, once a frame
do
	local subs, conn = {}, nil
	local function sampleOf(player, now)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then return nil end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local parts = {}
		for _, name in ipairs({ "Head", "UpperTorso", "LowerTorso" }) do
			local part = character:FindFirstChild(name)
			if part then parts[name] = part.Position end
		end
		local move = humanoid and humanoid.MoveDirection or ZERO
		return {
			t = now, serverT = workspace:GetServerTimeNow(), pos = root.Position, vel = root.AssemblyLinearVelocity, look = root.CFrame.LookVector,
			parts = parts, moveDir = move, walk = humanoid and humanoid.WalkSpeed or 16, moving = move.Magnitude > 0.1,
			tool = (character:FindFirstChildOfClass("Tool") or {}).Name,
		}
	end
	local function poll()
		local now = os.clock()
		for _, player in ipairs(S.Players:GetPlayers()) do
			if player ~= DH.LP then
				local ok, s = pcall(sampleOf, player, now)
				if ok and s then
					for _, fn in ipairs(subs) do
						local okFn, err = pcall(fn, player, s)
						if not okFn then DH.fail("net.onIncoming", err) end
					end
				end
			end
		end
	end
	---Watch other players' replicated bodies. `fn(player, sample)` runs once a frame for each (sample: t, serverT, pos, vel, look, parts, moveDir, walk, moving, tool).
	---@return table connection with :Disconnect()
	function Net.onIncoming(fn)
		subs[#subs + 1] = fn
		if not conn then conn = DH.janitor:add(S.Run.Heartbeat:Connect(poll), "net.incoming") end
		return { Disconnect = function()
			for i, f in ipairs(subs) do if f == fn then table.remove(subs, i) break end end
			if #subs == 0 and conn then conn:Disconnect(); conn = nil end
		end }
	end
	Net.incomingSource = "poll"
	function Net.sampleOf(player) return sampleOf(player, os.clock()) end
end

-- ---- capture and diff: how the position field was found (and how to find it again after an update)
---Log this client's outgoing packets for `seconds`: every 0xA1 whole (hex) with where the body was, other ids counted.
function Net.capture(seconds, label, done)
	if not Net.available then if done then done({ error = "raknet unavailable" }) end return end
	local rows, others, snap = {}, {}, nil
	local started = os.clock()
	local snapConn = S.Run.PostSimulation:Connect(function()
		local root = DH.root()
		if root then local cf = root.CFrame; snap = { x = cf.X, y = cf.Y, z = cf.Z, t = os.clock() } end
	end)
	local function hex(s) local out = table.create(#s); for i = 1, #s do out[i] = string.format("%02x", string.byte(s, i)) end return table.concat(out) end
	local function hook(packet)
		pcall(function()
			local s = packet.AsString
			if packet.PacketId == Codec.ID then
				rows[#rows + 1] = { t = os.clock() - started, hex = hex(s), hrp = snap }
			else
				local key = string.format("%02X", packet.PacketId)
				local o = others[key] or { n = 0, min = math.huge, max = 0 }
				others[key] = o
				o.n += 1; o.min = math.min(o.min, #s); o.max = math.max(o.max, #s)
			end
		end)
	end
	pcall(rk.add_send_hook, hook)
	task.delay(seconds, function()
		pcall(rk.remove_send_hook, hook)
		snapConn:Disconnect()
		local result = { label = label, seconds = seconds, a1 = rows, others = others }
		pcall(writefile, "monster-build/results/net_capture_" .. tostring(label) .. ".json", S.Http:JSONEncode(result))
		if done then done(result) end
	end)
end

---Which byte offsets (1-based, within the packet) differ between two captures' packets of the same length?
---@return table offset -> number of packet pairs that differ there
function Net.diff(rowsA, rowsB)
	local function unhex(h) local out = {}; for i = 1, #h, 2 do out[#out + 1] = string.char(tonumber(string.sub(h, i, i + 1), 16)) end return table.concat(out) end
	local counts = {}
	for i = 1, math.min(#rowsA, #rowsB) do
		local a, b = unhex(rowsA[i].hex), unhex(rowsB[i].hex)
		if #a == #b then
			for at = 1, #a do
				if string.byte(a, at) ~= string.byte(b, at) then counts[at] = (counts[at] or 0) + 1 end
			end
		end
	end
	return counts
end

---Check the codec against captured rows: median position error (studs) and how many decoded.
function Net.verify(rows)
	local errors, decoded = {}, 0
	local function unhex(h) local out = {}; for i = 1, #h, 2 do out[#out + 1] = string.char(tonumber(string.sub(h, i, i + 1), 16)) end return table.concat(out) end
	for _, row in ipairs(rows) do
		local parsed = Codec.parse(unhex(row.hex))
		if parsed then
			decoded += 1
			if row.hrp then errors[#errors + 1] = math.sqrt((parsed.x - row.hrp.x) ^ 2 + (parsed.y - row.hrp.y) ^ 2 + (parsed.z - row.hrp.z) ^ 2) end
		end
	end
	table.sort(errors)
	return { rows = #rows, decoded = decoded, median = errors[math.max(1, math.ceil(#errors / 2))], max = errors[#errors] }
end

-- ---- lifecycle
local lastCheck = 0
function Net.init()
	scanRaknet()
	if Net.available then installHook() end
	DH.janitor:add(S.Run.Heartbeat:Connect(function()
		-- a held body whose driver stopped asking is let go (a stalled loop must not leave the server body behind)
		local now = os.clock()
		if Net.on and now - Net.lastHold > 0.5 then
			DH.warn("net.stale", "hold went stale: releasing", 5)
			local root = DH.root()
			Net.release(root and root.CFrame)
		end
		if now - lastCheck > 2 then
			lastCheck = now
			if type(rk) == "table" and type(rk.is_enabled) == "function" and Net.on then
				local ok, enabled = pcall(rk.is_enabled)
				if ok and enabled == false then Net.deny("raknet library was switched off") end
			end
		end
	end), "net.watch")
end
function Net.enable() if Net.available then installHook() end end
function Net.disable()
	local root = DH.root()
	Net.release(root and root.CFrame)
	Net.on = false
	removeHook()
end
Net.stop = Net.disable -- (the older block's name for it)
function Net.status()
	return {
		available = Net.available, denied = Net.denied, reason = Net.reason, on = Net.on, hooks = Net.hooks, rxNames = Net.rxNames,
		sent = Net.sent, failed = Net.failed, blocked = Net.blocked, unparsed = Net.unparsed, noHeader = Net.noHeader, hookFaults = Net.hookFaults,
		rate = math.floor(Net.rate * 10) / 10, layouts = Net.layouts, headerKnown = header ~= nil, incoming = Net.incomingSource, mode = Net.mode,
	}
end
DH.register("net", Net)
end
-- >>> src/40_fakepos.lua
do
-- ---- fakepos: where the server is told the body is. The driver loop is the Desync block below (it owns the body swap and the
-- strike hooks); this module computes the new modes, arbitrates the sources that may ask for a place, and reports.
-- Priority when things collide: panic > defense void > physrep ride > ragebot / api > the configured mode > normal movement.
local Modes = DH.F.modes(DH.ENV)
local Orbit = DH.F.orbit(DH.ENV)
DH.Orbit = Orbit
local Fakepos = {
	state = Modes.new(), rng = Random.new(), sources = {}, backend = "off", degraded = false,
	panicked = false, owner = "none", server = nil, real = nil, orbitVelocity = nil,
}
DH.Fakepos = Fakepos

Fakepos.MODES = {
	{ "static", "Static offset" }, { "follow", "Follow offset" }, { "jitter", "Jitter" }, { "anchor", "Anchor" }, { "thunder", "Orbit strafe (sky)" },
}
local OWN = { static = true, follow = true, jitter = true, anchor = true, thunder = true }

DH.define("monster.fakepos.offX", { kind = "slider", default = 0, min = -300, max = 300, step = 1, label = "Offset X", desc = "Static / Follow: right (+) or left (-).", group = "fakepos" })
DH.define("monster.fakepos.offY", { kind = "slider", default = 0, min = -300, max = 300, step = 1, label = "Offset Y", desc = "Static / Follow: up (+) or down (-).", group = "fakepos" })
DH.define("monster.fakepos.offZ", { kind = "slider", default = 30, min = -300, max = 300, step = 1, label = "Offset Z", desc = "Static / Follow: behind (+) or in front (-).", group = "fakepos" })
DH.define("monster.fakepos.radius", { kind = "slider", default = 25, min = 1, max = 150, step = 1, label = "Jitter radius", desc = "Jitter: how far from you they see you.", group = "fakepos", suffix = " st" })
DH.define("monster.fakepos.rate", { kind = "slider", default = 120, min = 20, max = 1000, step = 10, label = "Jitter rate", desc = "Jitter: milliseconds between new places.", group = "fakepos", suffix = " ms" })
DH.define("monster.fakepos.anchorKey", { kind = "keybind", default = "None", label = "Anchor key", desc = "Anchor: press to hold where you stand; press again to let go.", group = "fakepos" })
DH.define("monster.fakepos.resetOnKO", { kind = "toggle", default = true, label = "Reset on KO", desc = "A knock clears the anchor and the jitter.", group = "fakepos" })
DH.define("monster.fakepos.backend", { kind = "dropdown", default = "auto", label = "Backend", desc = "Auto: raknet when it works, else the body swap. Velocity is unmeasured.", group = "fakepos",
	options = { { "auto", "Auto" }, { "raknet", "Raknet" }, { "swap", "Body swap" }, { "velocity", "Velocity (unmeasured)" } } })
DH.define("monster.fakepos.orbitAround", { kind = "dropdown", default = "target", label = "Orbit around", desc = "Orbit strafe: the target (you, when nobody is near) or always yourself.", group = "fakepos",
	options = { { "target", "The target" }, { "me", "Me" } } })
DH.define("monster.fakepos.moveReal", { kind = "toggle", default = false, label = "Push the real body (orbit)", desc = "Orbit strafe also runs your own body round the target (capped on the ground).", group = "fakepos" })

---The orbit settings as a params table for Orbit.step, from K; the sky variant stays inside what a packet can carry.
function Fakepos.orbitParams(packets)
	local K = DH.K.get
	local p = {
		speed = K("ORBIT_SPEED"), radius = K("ORBIT_RADIUS"), heightHigh = K("ORBIT_H1"), heightLow = K("ORBIT_H2"), heightRate = K("ORBIT_FLIP"),
		jitterH = K("ORBIT_JIT_H"), jitterV = K("ORBIT_JIT_V"), jitterRate = K("ORBIT_JIT_RATE"), jitterFlip = 0.025, velocity = K("ORBIT_VEL"),
	}
	if packets then
		p.heightHigh, p.heightLow = math.min(p.heightHigh, 900), math.min(p.heightLow, 870)
		p.radius = math.min(p.radius, 400)
	end
	return p
end

---The new modes, for the Desync block's fakeOf: nil for any mode that is not one of these.
---@param where string
---@param real CFrame where the body really is
---@param centre Vector3? what the orbit goes round (the target; nil = you)
---@param packets boolean whether raknet carries the result (then it is kept inside |coord| < 1000)
---@return CFrame?
function Fakepos.compute(where, real, centre, packets)
	if not OWN[where] then return nil end
	local now = os.clock()
	if where ~= "thunder" then Fakepos.orbitVelocity = nil end
	if where == "thunder" then
		if DH.get("monster.fakepos.orbitAround") == "me" then centre = real.Position end
		local cf, velocity = Orbit.step(now, centre or real.Position, real.Position, Fakepos.orbitParams(packets))
		if packets then cf = Orbit.fit(cf, 1000) end
		Fakepos.orbitVelocity = DH.get("monster.fakepos.moveReal") and velocity or nil
		return cf
	end
	local opts = {
		offset = Vector3.new(DH.get("monster.fakepos.offX"), DH.get("monster.fakepos.offY"), DH.get("monster.fakepos.offZ")),
		radius = DH.get("monster.fakepos.radius"), rate = DH.get("monster.fakepos.rate"),
	}
	local cf = Modes.compute(where, Fakepos.state, real, opts, now, Fakepos.rng)
	if cf and packets then cf = Orbit.fit(cf, 1000) end
	return cf
end

---The real body's push for the orbit strafe, capped while it stands on the ground (the game's speed lock is 40 studs/s).
function Fakepos.applyVelocity(root)
	local velocity = Fakepos.orbitVelocity
	if not velocity or not root then return end
	local humanoid = DH.humanoid()
	local grounded = humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
	if grounded and velocity.Magnitude > DH.K.get("ORBIT_GROUND_CAP") then velocity = velocity.Unit * DH.K.get("ORBIT_GROUND_CAP") end
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, root.AssemblyLinearVelocity.Y, velocity.Z)
end

-- ---- sources: who may ask for a place, by priority
Fakepos.PRIORITY = { panic = 5, defense = 4, rage = 3, net = 2.5, api = 2.5 }

---Ask for the server body to be at `value` (a CFrame, or a function(real) -> CFrame?). nil withdraws the request.
function Fakepos.setSource(name, value, priority)
	if value == nil then Fakepos.sources[name] = nil; return end
	if typeof(value) == "CFrame" and value == CFrame.new() then Fakepos.sources[name] = nil; return end -- (identity means off)
	Fakepos.sources[name] = { value = value, priority = priority or Fakepos.PRIORITY[name] or 2.5 }
end
function Fakepos.clearSource(name) Fakepos.sources[name] = nil end
---True when some source wants a place right now (a source that returns nil this step does not count).
function Fakepos.hasForced()
	if Fakepos.panicked or next(Fakepos.sources) == nil then return false end
	local root = DH.root()
	return Fakepos.forced(root and root.CFrame or CFrame.new()) ~= nil
end
---The CFrame the highest-priority source wants this step (nil: none). Asked twice in a step (wanted, then fakeOf): answered once.
function Fakepos.forced(real)
	if Fakepos.panicked then return nil end
	local stamp = os.clock()
	if Fakepos.cache and Fakepos.cache.real == real and stamp - Fakepos.cache.t < 0.004 then return Fakepos.cache.result end
	local result = Fakepos.pickSource(real)
	Fakepos.cache = { real = real, t = stamp, result = result }
	return result
end
function Fakepos.pickSource(real)
	local best, bestPriority
	for name, source in pairs(Fakepos.sources) do
		if not bestPriority or source.priority > bestPriority then best, bestPriority = name, source.priority end
	end
	if not best then Fakepos.owner = DH.get("monster.fake") and "config" or "none"; return nil end
	local value = Fakepos.sources[best].value
	local cf = value
	if type(value) == "function" then
		local ok, result = pcall(value, real)
		if not ok then DH.fail("fakepos.source:" .. best, result); return nil end
		cf = result
	end
	if cf ~= nil then Fakepos.owner = best end
	return cf
end

---A physrep ride or a panic suspends the configured modes (the ride and the fake position never run together).
function Fakepos.suspended()
	return Fakepos.panicked or (DH.Physrep ~= nil and DH.Physrep.isAttached())
end

---Published by the driver each step.
function Fakepos.publish(real, server, backend)
	Fakepos.real, Fakepos.server = real, server
	if backend then Fakepos.backend, Fakepos.degraded = backend, backend ~= "raknet" end
end
function Fakepos.getServerCFrame() return Fakepos.server or Fakepos.real end
function Fakepos.getRealCFrame()
	local root = DH.root()
	return root and root.CFrame or Fakepos.real
end

---Anchor key: hold where you stand, or let go.
function Fakepos.toggleAnchor()
	local root = DH.root()
	if Fakepos.state.anchor then
		Modes.clearAnchor(Fakepos.state)
		return false
	end
	if root then Modes.setAnchor(Fakepos.state, root.CFrame); return true end
	return false
end
---A knock (or a stop) resets what the modes remember, by setting.
function Fakepos.onIdle(character)
	if DH.get("monster.fakepos.resetOnKO") and (DH.knocked(character) or not character) then
		Fakepos.state = Modes.new()
	end
end

function Fakepos.panic() Fakepos.panicked = true; Fakepos.sources = {} end
function Fakepos.unpanic() Fakepos.panicked = false end

function Fakepos.init() end
function Fakepos.enable() DH.set("monster.fake", true, true) end
function Fakepos.disable()
	Fakepos.sources = {}
	Fakepos.server = nil
	DH.set("monster.fake", false, true)
	DH.set("monster.desync", false, true)
	Fakepos.state = Modes.new()
end
function Fakepos.status()
	return {
		mode = DH.get("monster.fakeWhere"), enabled = DH.get("monster.fake") == true or DH.get("monster.desync") == true,
		backend = Fakepos.backend, degraded = Fakepos.degraded, owner = Fakepos.owner, panicked = Fakepos.panicked,
		sources = (function() local names = {}; for name in pairs(Fakepos.sources) do names[#names + 1] = name end; return names end)(),
		anchored = Fakepos.state.anchor ~= nil,
		server = Fakepos.server and { Fakepos.server.X, Fakepos.server.Y, Fakepos.server.Z } or nil,
		suspended = Fakepos.suspended(),
	}
end
DH.register("fakepos", Fakepos)
end
-- >>> src/41_void.lua
do
-- ---- void: the body sent where nobody can reach it, in phases (see pure/voidsm.lua). The Desync block holds the body there
-- (the sky box over raknet, or a body swap far out) and brings it back for a strike; this module decides WHEN, and WHERE.
local SM = DH.F.voidsm()
local Void = {
	sm = nil, state = { voided = false, phase = "idle", holdLeft = 0 }, rng = Random.new(), waiting = false, ramps = 0, diedOnce = false,
	-- what the engine was given for the two big constants: (1.88e13, 1e29, 9.98e14) and (18812581888888, 99999999999999999999999999999, 998235235621111)
	NAN1 = Vector3.new(1.8812581888888e13, 9.9999999999999e29, 9.98235235621111e14),
	NAN2 = Vector3.new(18812581888888, 99999999999999999999999999999, 998235235621111),
}
DH.Void = Void

DH.define("monster.void.position", { kind = "dropdown", default = "sky", label = "Void position", group = "void",
	desc = "Sky: a random place high over the map, sent by raknet. Far: a body swap a billion studs out. NaN 1 / NaN 2: the two big constants. Orbit: the strafe.",
	options = { { "sky", "Sky (raknet, safe)" }, { "far", "Far (body swap)" }, { "nan1", "NaN 1 (clamped)" }, { "nan2", "NaN 2 (clamped)" }, { "orbit", "Orbit strafe" } } })
DH.define("monster.void.protect", { kind = "toggle", default = false, label = "Void when threatened", desc = "Go to the void while an armed player is near, come back after a calm hold.", group = "void" })
DH.define("monster.void.whenDead", { kind = "toggle", default = true, label = "Void when the target dies", desc = "Hide for a few seconds after a knock.", group = "void" })
DH.define("monster.void.whileWaiting", { kind = "toggle", default = false, label = "Void while waiting", desc = "Hide while the ragebot has nothing to shoot or is reloading.", group = "void" })
DH.define("monster.void.respawnRamp", { kind = "toggle", default = true, label = "Void after respawn", desc = "After a death: a long hold, then shorter ones, then out.", group = "void" })
DH.define("monster.void.key", { kind = "keybind", default = "None", label = "Void key", desc = "Hold / toggle the void with a key.", group = "void" })
DH.define("monster.void.keyMode", { kind = "dropdown", default = "Toggle", label = "Void key mode", group = "void", desc = "Hold, Toggle, or Always.",
	options = { { "Hold", "Hold" }, { "Toggle", "Toggle" }, { "Always", "Always" } } })

local function build()
	local K = DH.K.get
	return { baitDelay = K("VOID_BAIT"), hold = K("VOID_HOLD"), peek = K("VOID_PEEK"), ramp = { K("VOID_RAMP1"), K("VOID_RAMP2"), K("VOID_RAMP3"), K("VOID_RAMP4") } }
end
Void.sm = SM.new(build())

---Ask for the void (`ttl` seconds, or until cancelled).
function Void.request(source, ttl) Void.sm:request(source, os.clock(), ttl) end
function Void.cancel(source) Void.sm:cancel(source) end

---True while the body is to be voided (a request is held, or a respawn ramp is on, or the older toggle: Where = Void).
function Void.active()
	return Void.state.voided or (DH.get("monster.fake") == true and DH.get("monster.fakeWhere") == "void")
end
---"orbit" and "orbit-thunder" are what the ragebot's strafe forces; otherwise the setting.
function Void.style() return Void.forceStyle or DH.get("monster.void.position") end

---A body swap writes this to the REAL body, so it must stay a number the engine and the server can carry: the two big constants
---(1e29 and up) are what ends in "Error 260" (the server cannot read the position), so they are never written, only used as a style name.
Void.SWAP_MAX = 2e9 -- (the far box's own limit, measured to hold)
function Void.safe(v)
	if typeof(v) ~= "Vector3" then return nil end
	local m = Void.SWAP_MAX
	if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z then return nil end -- NaN
	if math.abs(v.X) > m or math.abs(v.Y) > m or math.abs(v.Z) > m then return nil end -- inf and anything past the limit
	return v
end

---Where the body swap puts the server body for `style` (a Vector3). The sky box and the far box are the measured ones;
---NaN 1 / NaN 2 land in the far box too (guarded: `Void.guarded` counts how often a big constant was turned down).
function Void.spot(style)
	local r = Void.rng
	local want
	if style == "nan1" or style == "nan2" then
		Void.guarded = (Void.guarded or 0) + 1
		DH.warn("void.guard", "NaN void swapped for the far box (a 1e29 body swap ends in error 260)", 30)
		style = "far"
	end
	if style == "far" then want = Vector3.new(r:NextNumber(-1.5e9, 1.5e9), r:NextNumber(4e8, 2e9), r:NextNumber(-1.5e9, 1.5e9))
	else want = Vector3.new(r:NextNumber(-1000, 1000), r:NextNumber(600, 1000), r:NextNumber(-1000, 1000)) end
	return Void.safe(want) or Vector3.new(0, 800, 0)
end

---The key's request: Hold, Toggle or Always are handled by the key module, which calls this.
function Void.keyState(on)
	if on then Void.request("key") else Void.cancel("key") end
end

---The ragebot has (or no longer has) nothing to shoot.
function Void.setWaiting(on)
	if on == Void.waiting then return end
	Void.waiting = on
	if on and DH.get("monster.void.whileWaiting") then Void.request("waiting") else Void.cancel("waiting") end
end

function Void.targetDied()
	if DH.get("monster.void.whenDead") then Void.request("target-dead", DH.K.get("VOID_DEAD_HOLD")) end
end

local function onCharacter(character)
	if Void.diedOnce and DH.get("monster.void.respawnRamp") then
		Void.diedOnce = false
		Void.ramps += 1
		Void.sm:respawned(os.clock())
	end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid then DH.janitor:add(humanoid.Died:Connect(function() Void.diedOnce = true end), "void.died") end
	end)
end

function Void.init()
	DH.janitor:add(DH.LP.CharacterAdded:Connect(onCharacter), "void.character")
	if DH.LP.Character then onCharacter(DH.LP.Character) end
	local acc = 0
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("void.step", function(dt)
		acc += dt
		if acc < 1 / 30 then return end
		acc = 0
		local cfg = build()
		Void.sm.cfg.baitDelay, Void.sm.cfg.hold, Void.sm.cfg.peek, Void.sm.cfg.ramp = cfg.baitDelay, cfg.hold, cfg.peek, cfg.ramp
		local near = DH.Defense ~= nil and DH.Defense.threatNear() or false
		Void.state = Void.sm:update(os.clock(), near)
	end)), "void.step")
end
function Void.enable() end
function Void.disable()
	Void.sm:reset()
	Void.state = { voided = false, phase = "idle", holdLeft = 0 }
	Void.waiting = false
end
function Void.status()
	local s = Void.state
	return { active = Void.active(), phase = s.phase, holdLeft = s.holdLeft, ramp = s.ramp, wanted = s.wanted, style = Void.style(), ramps = Void.ramps, releases = Void.sm.releases, guarded = Void.guarded or 0 }
end
DH.register("void", Void)
end
-- >>> src/42_physrep.lua
do
-- ---- physrep: ride a target's root part with PhysicsRepRootPart (logic and reasons to let go: pure/physcore.lua).
-- While bound, the CFrame the local root is given is read by the server RELATIVE to the bound root (measured on Potassium; the
-- Volt probe and the live ride test say whether the same holds here). So the spot is written after the physics step and put back
-- before the next step and before the frame is drawn, like the body swap; shots take their origin from the glued body.
local PhysF = DH.F.physcore(DH.ENV)
local Phys = { offset = nil, real = nil, put = nil, nudge = 1 }
DH.Physrep = Phys

DH.define("monster.physrep.on", { kind = "toggle", default = true, label = "Ride the target (bag / stomp)", desc = "Stomp and bag spots move with a moving target.", group = "physrep" })

local io = {
	now = os.clock,
	isPart = function(x) return typeof(x) == "Instance" and x:IsA("BasePart") end,
	inWorld = function(p) return p.Parent ~= nil and p:IsDescendantOf(workspace) end,
	isLocal = function(p) local c = DH.character(); return c ~= nil and p:IsDescendantOf(c) end,
	localRoot = function() return DH.root() end,
	distance = function(a, b) return (a.Position - b.Position).Magnitude end,
	get = function(part, name)
		if type(gethiddenproperty) ~= "function" then return false, "gethiddenproperty is missing" end
		local ok, value = pcall(gethiddenproperty, part, name)
		return ok, value
	end,
	set = function(part, name, value)
		if type(sethiddenproperty) ~= "function" then return false, "sethiddenproperty is missing" end
		local ok, err = pcall(sethiddenproperty, part, name, value)
		return ok, err
	end,
}
local core = PhysF.new(io, { maxRange = DH.K.get("PHYS_RANGE"), offset = CFrame.new(0, DH.K.get("PHYS_UP"), 0) })
Phys.core = core
Phys.PRIORITY = PhysF.PRIORITY

---@param targetRoot BasePart
---@param offsetCF CFrame? the spot in the target's frame (default: PHYS_UP above it)
---@return boolean, string?
function Phys.attach(targetRoot, offsetCF)
	if DH.get("monster.physrep.on") ~= true then return false, "switched off" end
	core.cfg.maxRange = DH.K.get("PHYS_RANGE")
	local ok, why = core:attach(targetRoot, offsetCF or CFrame.new(0, DH.K.get("PHYS_UP"), 0))
	if ok then Phys.offset = core.offset end
	return ok, why
end
function Phys.detach(reason) return core:detach(reason) end
function Phys.isAttached() return core:isAttached() end
function Phys.target() return core:getTarget() end

---The spot in the world the server has the body at while riding.
function Phys.serverBody()
	local target = core:getTarget()
	if not (target and core.offset) then return nil end
	return PhysF.serverBody(target.CFrame, core.offset)
end
---The origin a shot from `handle` must carry while riding (the handle as the glued body has it).
function Phys.originFor(handle)
	local target, root = core:getTarget(), DH.root()
	if not (target and root and handle and core.offset) then return nil end
	return PhysF.shotOrigin(target.CFrame, core.offset, root.CFrame, handle.CFrame)
end
---When the property is unusable: a world spot that keeps up with the target by its velocity.
function Phys.fallbackSpot(targetRoot, offsetVec, prediction)
	return PhysF.fallbackSpot(targetRoot.Position, targetRoot.AssemblyLinearVelocity, prediction or DH.lag(), offsetVec or Vector3.new(0, DH.K.get("PHYS_UP"), 0))
end

local function context()
	local target = core:getTarget()
	local ctx = {}
	local localChar = DH.character()
	if not localChar or not DH.root() then ctx.localRespawned = true
	elseif DH.knocked(localChar) or (DH.humanoid() and DH.humanoid().Health <= 0) then ctx.localKO = true end
	if target then
		local model = target.Parent
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if not model then ctx.targetGone = true
		elseif humanoid and humanoid.Health <= 0 then ctx.targetDead = true
		elseif DH.knocked(model) then ctx.targetKO = true end
		local player = model and S.Players:GetPlayerFromCharacter(model)
		if model and not player then ctx.targetGone = true end
	end
	ctx.panic = Phys.core.panic
	ctx.defense = DH.Void ~= nil and DH.Void.state.voided and DH.Defense ~= nil and DH.Defense.active()
	return ctx
end

function Phys.init()
	local function step()
		if not core:isAttached() then Phys.put = nil; return end
		local still, reason = core:tick(context())
		if not still then
			DH.warn("physrep.detach", "let go: " .. tostring(reason), 2)
			return
		end
		local root = DH.root()
		if not root then return end
		Phys.real = root.CFrame
		Phys.nudge = -Phys.nudge
		Phys.put = core.offset * CFrame.new(0.02 * Phys.nudge, 0, 0) -- (a body that stands still sends nothing: the nudge keeps it sending)
		root.CFrame = Phys.put
	end
	local function putBack()
		local root = DH.root()
		if Phys.put and root and Phys.real then root.CFrame = Phys.real end
		Phys.put = nil
	end
	DH.janitor:add(S.Run.PostSimulation:Connect(DH.safe("physrep.step", step)), "physrep.post")
	DH.janitor:add(S.Run.PreSimulation:Connect(DH.safe("physrep.back", putBack)), "physrep.pre")
	DH.janitor:add(S.Run.PreRender:Connect(DH.safe("physrep.render", putBack)), "physrep.render")
	DH.janitor:add(DH.LP.CharacterAdded:Connect(function() core:detach("local respawn") end), "physrep.respawn")
end
function Phys.enable() end
function Phys.disable(reason)
	core:detach(reason or "disable")
	local root = DH.root()
	if root and Phys.real and Phys.put then root.CFrame = Phys.real end
	Phys.put = nil
end
function Phys.setPanic(on) core:setPanic(on) end
function Phys.status() local s = core:status(); s.target = s.target and s.target:GetFullName() or nil; return s end
DH.register("physrep", Phys)
end
-- >>> src/50_ragebot.lua
do
-- ---- ragebot: MONSTER's own fighter. It picks a target (pure/targeting.lua), shoots from where the server believes the body is,
-- stomps with the physrep ride, moves by the chosen mode, and lets a plugin replace where it stands (setStrafeOverride).
-- It does not run together with BasedHub's own ragebot (two of them would shoot twice): it waits while that one is on.
-- Server rules it is built on (measured 2026-10 on the 2-alt rig, memory da-hood-ragebot): a shot's origin must be within 17 studs of where
-- the server has the body; the hit point within 22 of the part; a hop of more than ~10 studs needs 0.10-0.23 s before shots count;
-- a stomp counts from 1.5 to 9.5 studs above a knocked body and does nothing during a reload.
local Targeting = DH.F.targeting()
local Patterns = DH.F.patterns(DH.ENV)
local Rage = {
	tstate = {}, entry = nil, player = nil, paused = false, resumeTo = nil, autoPaused = nil, override = nil,
	fired = 0, stomps = 0, reloads = 0, spread = 0, spot = nil, spotSince = 0, nextShot = 0, reloadUntil = 0, equipAt = 0, stompAt = 0,
	nextJump = 0, lastPick = -1, oneTapUntil = 0, stompingNow = false, lastSight = { t = -1 }, targetWasKO = false, kills = 0,
}
DH.Rage = Rage

local function defineRage(id, def) def.group = "rage"; DH.define("monster.rage." .. id, def) end
defineRage("on", { kind = "toggle", default = false, label = "Ragebot", desc = "Fights from the fake position. Off while BasedHub's own ragebot runs." })
defineRage("key", { kind = "keybind", default = "None", label = "Ragebot key", desc = "Turn it on and off with a key." })
defineRage("keyMode", { kind = "dropdown", default = "Toggle", label = "Key mode", desc = "Hold, Toggle, or Always.", options = { { "Hold", "Hold" }, { "Toggle", "Toggle" }, { "Always", "Always" } } })
defineRage("targetMode", { kind = "dropdown", default = "threat", label = "Target", desc = "Who it picks.",
	options = { { "threat", "Biggest threat" }, { "closest-to-mouse", "Closest to mouse" }, { "closest-to-me", "Closest to me" }, { "lowest-health", "Lowest health" } } })
defineRage("targets", { kind = "input", default = "", label = "Only these players", desc = "Names, comma between. Empty: everyone who is not a friend." })
defineRage("fov", { kind = "slider", default = 160, min = 10, max = 180, step = 5, label = "FOV", desc = "Degrees off your camera line.", suffix = "°" })
defineRage("walls", { kind = "toggle", default = true, label = "Wall check", desc = "Skip players behind walls." })
defineRage("teamCheck", { kind = "toggle", default = false, label = "Team check", desc = "Skip your own team." })
defineRage("switchWait", { kind = "slider", default = 0.14, min = 0, max = 2, step = 0.02, label = "Switch wait", desc = "Seconds before it changes target.", suffix = " s" })
defineRage("part", { kind = "dropdown", default = "head", label = "Aim part", desc = "Head or torso.", options = { { "head", "Head" }, { "torso", "Torso" } } })
defineRage("weapon", { kind = "input", default = "auto", label = "Weapon", desc = "auto, or part of a gun's name ([Rifle], Double)." })
defineRage("flame", { kind = "toggle", default = false, label = "Flamethrower", desc = "Use the flamethrower up close (not measured)." })
defineRage("salvo", { kind = "toggle", default = true, label = "Salvo", desc = "Shotguns send all five pellets." })
defineRage("pipeline", { kind = "toggle", default = true, label = "Pipeline", desc = "Send the next shot without waiting for the answer." })
defineRage("oneTap", { kind = "toggle", default = false, label = "One tap", desc = "Head only, then wait for the hit before the next." })
defineRage("snipe", { kind = "toggle", default = false, label = "Snipe", desc = "Far targets only when they stand still." })
defineRage("autoReload", { kind = "toggle", default = true, label = "Auto reload", desc = "Reload an empty gun." })
defineRage("smartReload", { kind = "toggle", default = true, label = "Smart reload", desc = "Top the gun up while nobody is in sight." })
defineRage("strafe", { kind = "toggle", default = false, label = "Strafe", desc = "Orbit strafe: the server sees you whirl high over them; each shot brings you back." })
defineRage("strafeStyle", { kind = "dropdown", default = "sky", label = "Strafe height", desc = "Sky stays inside what a packet can carry; Thunder goes 200000 up (body swap).",
	options = { { "sky", "Sky" }, { "thunder", "200000 up" } } })
defineRage("chase", { kind = "toggle", default = false, label = "Chase", desc = "Your own body runs at the target." })
defineRage("walk", { kind = "toggle", default = false, label = "Walk to target", desc = "Your own body walks up to 15 studs from the target." })
defineRage("jump", { kind = "toggle", default = false, label = "Jump at target", desc = "Your own body jumps while closing in." })
defineRage("stomp", { kind = "toggle", default = true, label = "Stomp", desc = "Finish a knocked target from above." })
defineRage("pattern", { kind = "dropdown", default = "none", label = "Pattern", desc = "Where the server sees you, round the target.",
	options = { { "none", "None" }, { "ring", "Ring" }, { "pounce", "Pounce" }, { "lure", "Lure" }, { "haunt", "Haunt" }, { "ambush", "Ambush" }, { "press", "Press" }, { "swarm", "Swarm" } } })
defineRage("safety", { kind = "toggle", default = true, label = "Safety pauses", desc = "Pause when knocked, loading, in a vehicle, or a dangerous player is near." })

local function opt(id) return DH.get("monster.rage." .. id) end
function Rage.on() return opt("on") == true end

-- ---- the other players, as the targeting module wants them
local function isFriend(player)
	local roster = B and B.Roster
	return roster ~= nil and roster.friends ~= nil and roster.friends[player.UserId] == true
end

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
local function clear(from, to, ignoreA, ignoreB)
	sightParams.FilterDescendantsInstances = { ignoreA, ignoreB, workspace.CurrentCamera }
	return workspace:Raycast(from, to - from, sightParams) == nil
end

local function screenInfo(pos)
	local camera = workspace.CurrentCamera
	if not camera then return 1e4, 180 end
	local v, on = camera:WorldToViewportPoint(pos)
	local mouse = S.Input:GetMouseLocation()
	local dist = on and (Vector2.new(v.X, v.Y) - mouse).Magnitude or 1e4
	local dir = pos - camera.CFrame.Position
	local angle = dir.Magnitude > 0 and math.deg(math.acos(math.clamp(camera.CFrame.LookVector:Dot(dir.Unit), -1, 1))) or 0
	return dist, angle
end

function Rage.candidates()
	local list = {}
	local me = DH.root()
	local character = DH.character()
	if DH.Defense then DH.Defense.assess() end
	for _, player in ipairs(S.Players:GetPlayers()) do
		if player ~= DH.LP then
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local humanoid = c and c:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				local pos = root.Position
				local screenDist, angle = screenInfo(pos)
				local entry = {
					id = player.UserId, name = string.lower(player.Name), player = player, pos = pos, health = humanoid.Health, armor = DH.armor(c),
					ko = DH.knocked(c) or humanoid.Health <= 1.5, dead = humanoid.Health <= 0, friend = isFriend(player), team = player.Team,
					forceField = DH.hasShield(c), screenDist = screenDist, aimAngle = angle, root = root, character = c, humanoid = humanoid,
				}
				if me and opt("walls") then entry.visible = clear(me.Position + Vector3.new(0, 1.5, 0), pos, character, c) else entry.visible = true end
				list[#list + 1] = entry
			end
		end
	end
	-- threat and crowding for the threat mode
	for _, a in ipairs(list) do
		local crowd = 0
		for _, b in ipairs(list) do
			if a ~= b and not b.ko and (a.pos - b.pos).Magnitude < 60 then crowd += 1 end
		end
		a.crowd = crowd
		a.threat = (DH.Defense and DH.Defense.threatOf and DH.Defense.threatOf(a.player)) or 0
	end
	return list
end

local function targetSet()
	local text = opt("targets")
	if type(text) ~= "string" or text == "" then return nil end
	local set = {}
	for name in string.gmatch(text, "[^,%s]+") do set[string.lower(name)] = true end
	return next(set) and set or nil
end

---Pick (and keep) a target, at 10 Hz.
function Rage.pick(now)
	if now - Rage.lastPick < 0.1 then return Rage.entry end
	Rage.lastPick = now
	local root = DH.root()
	local cfgPick = {
		mode = opt("targetMode"), fov = opt("fov"), walls = opt("walls"), teamCheck = opt("teamCheck"), switchWait = opt("switchWait"),
		range = 2000, ignoreFriends = true,
	}
	local ctx = { mePos = root and root.Position, meTeam = DH.LP.Team, targets = targetSet() }
	local list = Rage.candidates()
	-- a knocked target is kept for the stomp even though the filter drops knocked players
	local held = Rage.entry and Rage.tstate.id == Rage.entry.id and Rage.entry
	local id, _, entry = Targeting.pick(Rage.tstate, list, now, ctx, cfgPick)
	if not entry and held then
		for _, c in ipairs(list) do
			if c.id == held.id and c.ko and not c.dead and opt("stomp") then entry = c; Rage.tstate.id = c.id end
		end
	end
	Rage.entry = entry
	Rage.player = entry and entry.player or nil
	return entry
end

function Rage.target() return Rage.player end

-- ---- weapons
local function toolValue(tool, name, default)
	local v = tool:FindFirstChild(name)
	return v and tonumber(v.Value) or default
end
local function spareAmmo(tool)
	local data = DH.LP:FindFirstChild("DataFolder")
	local inv = data and data:FindFirstChild("Inventory")
	local held = inv and inv:FindFirstChild(tool.Name)
	return held and tonumber(held.Value) or 0
end
local function isShotgun(tool)
	local n = string.lower(tool.Name)
	return string.find(n, "shotgun", 1, true) ~= nil or string.find(n, "double-barrel", 1, true) ~= nil or string.find(n, "sg]", 1, true) ~= nil
end
function Rage.gunRange(tool) return toolValue(tool, "Range", DH.K.get("RAGE_RANGE")) end -- (the tool's own Range value; the K number when it has none)

local function allGuns()
	local out, character = {}, DH.character()
	local function scan(parent)
		for _, item in ipairs(parent and parent:GetChildren() or {}) do
			if item:IsA("Tool") and item:FindFirstChild("Ammo") and item:FindFirstChild("Handle") then out[#out + 1] = item end
		end
	end
	scan(character); scan(DH.LP:FindFirstChildOfClass("Backpack"))
	return out
end

local function configuredOrder()
	local ok, list = pcall(function() return Config and Config.get("dahood.guns") end)
	return (ok and type(list) == "table") and list or {}
end

---The gun to use now (nil when none has a round and none can be reloaded).
function Rage.pickGun(distance)
	local guns = allGuns()
	if #guns == 0 then return nil end
	local want = string.lower(tostring(opt("weapon") or "auto"))
	if opt("flame") and distance and distance <= DH.K.get("DEF_FLAME") then
		for _, g in ipairs(guns) do if string.find(string.lower(g.Name), "flame", 1, true) and g.Ammo.Value > 0 then return g end end
	end
	if want ~= "auto" and want ~= "" then
		for _, g in ipairs(guns) do if string.find(string.lower(g.Name), want, 1, true) then return g end end
		return nil
	end
	local character = DH.character()
	local held = character and character:FindFirstChildOfClass("Tool")
	if held and held:FindFirstChild("Ammo") and held.Ammo.Value > 0 then return held end
	for _, name in ipairs(configuredOrder()) do
		for _, g in ipairs(guns) do if g.Name == name and (g.Ammo.Value > 0 or spareAmmo(g) > 0) then return g end end
	end
	for _, g in ipairs(guns) do if g.Ammo.Value > 0 then return g end end
	for _, g in ipairs(guns) do if spareAmmo(g) > 0 then return g end end
	return nil
end

local function equip(gun, now)
	local character, humanoid = DH.character(), DH.humanoid()
	if gun.Parent == character then return true end
	if humanoid and now >= Rage.equipAt then
		Rage.equipAt = now + 0.4
		pcall(function() humanoid:EquipTool(gun) end)
	end
	return false
end

local function remoteMain() return S.Rep:FindFirstChild("MainEvent") end

function Rage.reload(gun, now)
	if now < Rage.reloadUntil then return false end
	local remote = remoteMain()
	if not remote or spareAmmo(gun) <= 0 then return false end
	remote:FireServer("Reload", gun)
	Rage.reloadUntil = now + 3
	Rage.reloads += 1
	return true
end

-- ---- what to aim at
---@return table? { pos, part, info, how }, string? why
function Rage.aim(entry, gun)
	local c = entry.character
	local wantHead = opt("part") == "head" or opt("oneTap") == true
	local partName = wantHead and "Head" or "UpperTorso"
	local part = c:FindFirstChild(partName) or c:FindFirstChild("HumanoidRootPart")
	if not part then return nil, "no part" end
	local lead = DH.lag()
	local pos, info, why = DH.Resolver.aimAt(entry.player, partName, lead)
	if pos then return { pos = pos, part = part, info = info, how = "resolver" } end
	if why == "low confidence" then return nil, why end
	local vel = entry.root.AssemblyLinearVelocity
	if vel.Magnitude > DH.K.get("RES_MAX_SPEED") then vel = Vector3.new(0, 0, 0) end
	return { pos = part.Position + vel * lead, part = part, how = "replicated" }
end

---Where the server will see the shot leave from: the glued body, a raknet fake, or the real handle.
function Rage.serverOrigin(handle)
	if DH.Physrep.isAttached() then return DH.Physrep.originFor(handle) end
	local root, server = DH.root(), DH.Fakepos.server
	if server and root and DH.Net.on then return handle.Position + (server.Position - root.Position) end
	return handle.Position
end

---Everything that has to be true before a shot is sent.
function Rage.canFire(entry, gun, aim, now)
	local handle = gun:FindFirstChild("Handle")
	if not handle then return false, "no handle" end
	if now < Rage.nextShot then return false, "cooldown" end
	if now < Rage.reloadUntil then return false, "reloading" end
	if now < Rage.oneTapUntil then return false, "waiting for the hit" end
	local origin = Rage.serverOrigin(handle)
	if not origin then return false, "no origin" end
	local dist = (aim.pos - origin).Magnitude
	if dist > Rage.gunRange(gun) then return false, "out of range" end
	-- arrival: the server counts shots from a new place only after a delay (0.10-0.23 s measured); riding and strikes handle their own
	local void = DH.Void.active()
	-- (the wait follows the ping, capped by RAGE_ARRIVE: a fixed 0.25 s equalled the ring's own hold, so a shot almost never got a window)
	local arrive = math.min(DH.K.get("RAGE_ARRIVE"), math.clamp(DH.ping() + DH.K.get("RAGE_ARRIVE_PAD"), 0.08, 0.4))
	if not void and not DH.Physrep.isAttached() and now - Rage.spotSince < arrive then return false, "arriving" end
	if opt("snipe") and dist > 150 and entry.root.AssemblyLinearVelocity.Magnitude > 2 then return false, "snipe: target is moving" end
	if now - Rage.lastSight.t > 0.1 then
		Rage.lastSight = { t = now, ok = clear(origin, aim.pos, DH.character(), entry.character) }
	end
	if opt("walls") and not Rage.lastSight.ok then return false, "no line" end
	return true
end

function Rage.shoot(gun, entry, aim, now)
	local remote, handle, ammo = remoteMain(), gun:FindFirstChild("Handle"), gun:FindFirstChild("Ammo")
	if not (remote and handle and ammo) then return false end
	if ammo.Value <= 0 then
		if opt("autoReload") then Rage.reload(gun, now) end
		return false
	end
	local cooldown = toolValue(gun, "ShootingCooldown", 0.3)
	Rage.nextShot = now + cooldown + (opt("pipeline") and 0.03 or (DH.ping() * 2 + 0.05))
	-- riding: the origin is the glued body's; otherwise the natural handle position (the shot hook moves it for a raknet fake)
	local origin = DH.Physrep.isAttached() and DH.Physrep.originFor(handle) or handle.Position
	local up = Vector3.new(0, 1, 0)
	if isShotgun(gun) and opt("salvo") then
		local stamp = workspace:GetServerTimeNow()
		Rage.spread += 1
		for pellet = 1, 5 do remote:FireServer("ShootGun", handle, origin, aim.pos, aim.part, up, stamp, Rage.spread, pellet) end
	else
		remote:FireServer("ShootGun", handle, origin, aim.pos, aim.part, up)
	end
	Rage.fired += 1
	if opt("oneTap") then Rage.oneTapUntil = now + 0.5 end
	if aim.info then DH.Resolver.noteShot(entry.player, aim.info) end
	return true
end

-- ---- where it stands
local function patternK()
	local k = {}
	for name, default in pairs(Patterns.DEFAULT_K) do
		local ok, v = pcall(function() return Config and Config.get("dahood.k." .. name) end)
		k[name] = (ok and type(v) == "number") and v or default
	end
	return k
end

---Replace where the ragebot stands. fn(position, unsafe, part) -> CFrame | nil (nil: use the default). Last registered wins.
function Rage.setStrafeOverride(fn) Rage.override = fn end
function Rage.clearStrafeOverride() Rage.override = nil end

---The target's position, for the orbit strafe (the Desync block asks).
function Rage.centre()
	return Rage.entry and Rage.entry.root and Rage.entry.root.Position or nil
end

function Rage.engaged()
	return Rage.on() and not Rage.paused and Rage.autoPaused == nil and Rage.entry ~= nil
end

---The fake-position source: the server body's place for this step (nil: the configured mode, or the real place).
function Rage.stand(real)
	if not Rage.engaged() then return nil end
	local entry = Rage.entry
	local root = entry.root
	if not (root and root.Parent) then return nil end
	local now = os.clock()
	local cf
	if entry.ko and opt("stomp") and not DH.Physrep.isAttached() and not Rage.stompingNow then
		cf = nil
	elseif Rage.stompingNow and not DH.Physrep.isAttached() then
		local spot = DH.Physrep.fallbackSpot(root, Vector3.new(0, DH.K.get("RAGE_STOMP"), 0))
		cf = CFrame.new(spot)
	elseif opt("pattern") ~= "none" and not entry.ko then
		cf = Patterns[opt("pattern")](root.Position, now, patternK(), { vel = root.AssemblyLinearVelocity, look = root.CFrame.LookVector })
	end
	local hook = Rage.override
	if hook then
		local base = (cf or real).Position
		local ok, replaced = pcall(hook, base, DH.Defense and DH.Defense.unsafe() or false, entry.character:FindFirstChild("Head") or root)
		if ok and typeof(replaced) == "CFrame" then cf = replaced elseif not ok then DH.fail("strafeOverride", replaced) end
	end
	if cf then
		local packets = DH.Net.on or DH.Net.ready()
		if packets then cf = DH.Orbit.fit(cf, 1000) end
		if not Rage.spot or (cf.Position - Rage.spot).Magnitude > 12 then Rage.spotSince = now end
		Rage.spot = cf.Position
	else
		Rage.spot = nil
	end
	return cf
end

-- ---- safety
local function autoPauseReason()
	if opt("safety") ~= true then return nil end
	if B and B.DaHood and B.DaHood.on == true then return "BasedHub's ragebot is on" end
	local character = DH.character()
	local ready, why = DH.ready(character)
	if not ready then return "me: " .. tostring(why) end
	local humanoid = DH.humanoid()
	if humanoid and (humanoid.SeatPart ~= nil or humanoid.Sit) then return "seated" end
	local a = DH.Defense and DH.Defense.assessment
	if a and a.top and Rage.player and a.top.id ~= Rage.player.UserId and a.topScore >= 0.6 and a.top.tool ~= "none"
		and (a.top.pos - (DH.root() and DH.root().Position or a.top.pos)).Magnitude <= DH.K.get("DEF_SAFE") and not DH.hasShield(character) then
		return "dangerous: " .. tostring(a.top.name)
	end
	return nil
end

function Rage.pause()
	if Rage.paused then return end
	Rage.resumeTo, Rage.paused = Rage.on(), true
end
function Rage.resume()
	if not Rage.paused then return end
	Rage.paused = false
	if Rage.resumeTo then DH.set("monster.rage.on", true, true) end
	Rage.resumeTo = nil
end
---`set_ragebot(true|false|nil)`: nil toggles.
function Rage.set(state)
	if state == nil then state = not Rage.on() end
	DH.set("monster.rage.on", state == true, true)
	if state ~= true then Rage.stop() end
	return Rage.on()
end

-- ---- the step
local function realBody(entry, now)
	local humanoid, root = DH.humanoid(), DH.root()
	if not (humanoid and root) or DH.Physrep.isAttached() or DH.Void.active() then return end
	local tpos = entry.root.Position
	local dist = (tpos - root.Position).Magnitude
	if opt("chase") then
		humanoid:MoveTo(tpos + entry.root.AssemblyLinearVelocity * 0.25)
	elseif opt("walk") then
		if dist > 15 then humanoid:MoveTo(tpos) else humanoid:Move(Vector3.new(0, 0, 0)) end
	end
	if opt("jump") and dist < 60 and now >= Rage.nextJump then
		Rage.nextJump = now + 1.1
		humanoid.Jump = true
	end
end

local function stompStep(entry, now)
	if not opt("stomp") then return end
	local root = entry.root
	local height = DH.K.get("RAGE_STOMP")
	Rage.stompingNow = true
	if not DH.Physrep.isAttached() then
		local ok = DH.Physrep.attach(root, CFrame.new(0, height, 0))
		if not ok then Rage.stompingNow = true end -- (world spot with the velocity lead takes over in stand())
	end
	if now >= Rage.stompAt and now >= Rage.reloadUntil then
		local remote = remoteMain()
		if remote and (not DH.Physrep.isAttached() or now - DH.Physrep.core.since >= DH.K.get("RAGE_ARRIVE")) then
			remote:FireServer("Stomp")
			Rage.stomps += 1
			Rage.stompAt = now + 0.55
		end
	end
end

function Rage.stop()
	Rage.entry, Rage.player, Rage.spot, Rage.stompingNow = nil, nil, nil, false
	Rage.tstate = {}
	if DH.Physrep then DH.Physrep.detach("ragebot stopped") end
	if DH.Void then DH.Void.cancel("rage-strafe"); DH.Void.forceStyle = nil; DH.Void.setWaiting(false) end
	DH.Fakepos.clearSource("rage")
end

local function step(dt)
	local now = os.clock()
	if not Rage.on() then
		if Rage.entry or Rage.stompingNow then Rage.stop() end
		Rage.autoPaused, Rage.why = nil, "off"
		return
	end
	Rage.autoPaused = autoPauseReason()
	if Rage.paused or Rage.autoPaused then
		Rage.why = "paused: " .. (Rage.paused and "by a plugin" or tostring(Rage.autoPaused))
		DH.Fakepos.clearSource("rage")
		if Rage.entry then Rage.entry, Rage.player = nil, nil end
		if DH.Physrep.isAttached() then DH.Physrep.detach("ragebot paused") end
		return
	end
	local entry = Rage.pick(now)
	DH.Fakepos.setSource("rage", function(real) return Rage.stand(real) end)
	if not entry then
		Rage.why = "no target"
		Rage.stompingNow = false
		if DH.Physrep.isAttached() then DH.Physrep.detach("no target") end
		DH.Void.setWaiting(true)
		DH.Void.cancel("rage-strafe"); DH.Void.forceStyle = nil
		-- smart reload while nobody is in sight
		if opt("smartReload") then
			local gun = Rage.pickGun(nil)
			local held = DH.character() and DH.character():FindFirstChildOfClass("Tool")
			local ammo = held and held:FindFirstChild("Ammo")
			if held and ammo and toolValue(held, "MaxAmmo", ammo.Value) > ammo.Value then Rage.reload(held, now) end
			if gun then equip(gun, now) end
		end
		return
	end
	DH.Void.setWaiting(false)
	local dist = (entry.root.Position - (DH.root() and DH.root().Position or entry.root.Position)).Magnitude

	-- the target went down
	if entry.ko and not Rage.targetWasKO then Rage.kills += 1; DH.Void.targetDied() end
	Rage.targetWasKO = entry.ko
	if entry.dead or not entry.ko then Rage.stompingNow = false; if DH.Physrep.isAttached() and not entry.ko then DH.Physrep.detach("target up") end end

	-- the strafe is the void with the orbit for its place; the strike inside it brings the body back for a shot
	if opt("strafe") and not entry.ko then
		DH.Void.forceStyle = opt("strafeStyle") == "thunder" and "orbit-thunder" or "orbit"
		DH.Void.request("rage-strafe", 0.5)
	else
		DH.Void.cancel("rage-strafe"); DH.Void.forceStyle = nil
	end

	if entry.ko then
		Rage.why = opt("stomp") and "target down: stomping" or "target down"
		stompStep(entry, now)
		return
	end
	realBody(entry, now)
	local gun = Rage.pickGun(dist)
	if not gun then Rage.why = "no gun with a round or spare ammo"; return end
	if not equip(gun, now) then Rage.why = "equipping " .. gun.Name; return end
	local aim, aimWhy = Rage.aim(entry, gun)
	if not aim then Rage.why = "aim: " .. tostring(aimWhy); return end
	local ok, why = Rage.canFire(entry, gun, aim, now)
	Rage.why = ok and "firing" or tostring(why)
	if ok then Rage.shoot(gun, entry, aim, now) end
	if opt("autoReload") and gun.Ammo.Value <= DH.K.get("RAGE_RELOAD_AT") then Rage.reload(gun, now) end
end

function Rage.init()
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("rage.step", step)), "rage.step")
end
function Rage.enable() DH.set("monster.rage.on", true, true) end
function Rage.disable() DH.set("monster.rage.on", false, true); Rage.stop() end
function Rage.status()
	local entry = Rage.entry
	return {
		on = Rage.on(), paused = Rage.paused, autoPaused = Rage.autoPaused, target = Rage.player and Rage.player.Name or nil,
		ko = entry and entry.ko or nil, fired = Rage.fired, stomps = Rage.stomps, reloads = Rage.reloads, kills = Rage.kills,
		riding = DH.Physrep and DH.Physrep.isAttached() or false, override = Rage.override ~= nil, why = Rage.why,
	}
end
DH.register("ragebot", Rage)
end
-- >>> src/51_resolver.lua
do
-- ---- resolver: where a player's real body is now, with a confidence (estimators and the vote: pure/estimators.lua).
-- Volt has no receive hook, so the history is read from the engine's replicated bodies (Net.onIncoming), a sample a frame.
local Est = DH.F.estimators(DH.ENV)
local Resolver = { per = {}, pending = {}, shots = 0, confirmed = 0, missed = 0, lastCfgAt = -1, cfg_ = nil }
DH.Resolver = Resolver

DH.define("monster.resolver.on", { kind = "toggle", default = true, label = "Resolver", desc = "Aim at where a hiding body really is, not where it shows.", group = "resolver" })
DH.define("monster.resolver.skipLow", { kind = "toggle", default = true, label = "Skip unsure shots", desc = "Below the minimum confidence: no shot. Off: shoot anyway.", group = "resolver" })
DH.define("monster.resolver.learn", { kind = "toggle", default = true, label = "Learn from shots", desc = "A guess that gets hits counts more for that player (this session only).", group = "resolver" })
DH.define("monster.resolver.overlay", { kind = "toggle", default = false, label = "Show every guess", desc = "A colour per estimator on the target; the winner in green.", group = "resolver" })

local COLORS = {
	raw = Color3.fromRGB(235, 235, 235), parts = Color3.fromRGB(70, 220, 255), pattern = Color3.fromRGB(255, 90, 220),
	cues = Color3.fromRGB(255, 225, 70), deadreckon = Color3.fromRGB(255, 150, 50), result = Color3.fromRGB(60, 255, 110),
}

local function cfg()
	local now = os.clock()
	if Resolver.cfg_ and now - Resolver.lastCfgAt < 1 then return Resolver.cfg_ end
	local K = DH.K.get
	Resolver.cfg_ = {
		windowSeconds = K("RES_WINDOW"), maxJump = K("RES_MAX_JUMP"), maxSpeed = K("RES_MAX_SPEED"), agreeSigma = K("RES_SIGMA"), minConfidence = K("RES_MIN_CONF"),
	}
	Resolver.lastCfgAt = now
	return Resolver.cfg_
end

local function record(player)
	local rec = Resolver.per[player]
	if not rec then
		rec = { history = Est.history(DH.K.get("RES_WINDOW")), learner = Est.learner(), memory = {}, cache = nil }
		Resolver.per[player] = rec
	end
	return rec
end

local function onSample(player, sample)
	local rec = record(player)
	rec.history.seconds = DH.K.get("RES_WINDOW")
	local previous = rec.history:last()
	rec.history:push(sample)
	if Est.gate(sample, previous, cfg()) then rec.memory.sample = sample end
	rec.cache = nil
end

---@param player Player
---@return table? { pos, cf, confidence, method, low, all }
function Resolver.get(player)
	local rec = Resolver.per[player]
	if not rec then return nil end
	local list = rec.history:list()
	if #list == 0 then return nil end
	local now = os.clock()
	if rec.cache and now - rec.cacheT < 0.004 then return rec.cache end
	local r = Est.estimate(list, now, cfg(), rec.learner.weights, rec.memory)
	r.low = r.pos == nil or r.confidence < cfg().minConfidence
	if r.pos then
		local look = list[#list].look or Vector3.new(0, 0, -1)
		local flat = Vector3.new(look.X, 0, look.Z)
		r.cf = flat.Magnitude > 0.01 and CFrame.lookAt(r.pos, r.pos + flat.Unit) or CFrame.new(r.pos)
	end
	rec.cache, rec.cacheT = r, now
	return r
end

local DEFAULT_OFFSET = { Head = Vector3.new(0, 1.6, 0), UpperTorso = Vector3.new(0, 0.6, 0), LowerTorso = Vector3.new(0, -0.3, 0), HumanoidRootPart = Vector3.new(0, 0, 0) }
---Where to aim for `partName`: the resolver's body place plus the part's offset from the root, led by `lead` seconds.
---@return Vector3?, table? info (the resolver result), string? why
function Resolver.aimAt(player, partName, lead)
	if DH.get("monster.resolver.on") ~= true then return nil, nil, "off" end
	local r = Resolver.get(player)
	if not r or not r.pos then return nil, r, "no estimate" end
	if r.low and DH.get("monster.resolver.skipLow") then return nil, r, "low confidence" end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local part = character and character:FindFirstChild(partName)
	local offset = DEFAULT_OFFSET[partName] or Vector3.new(0, 0, 0)
	if root and part then
		local seen = part.Position - root.Position
		if seen.Magnitude < 8 then offset = seen end
	end
	local list = Resolver.per[player].history:list()
	local last = list[#list]
	local vel = (last and last.vel and last.vel.Magnitude < DH.K.get("RES_MAX_SPEED")) and last.vel or Vector3.new(0, 0, 0)
	return r.pos + offset + vel * (lead or 0), r
end

---A shot was sent at a guess: watch the target for damage and nudge that method's weight.
function Resolver.noteShot(player, result)
	if DH.get("monster.resolver.learn") ~= true or not result then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	Resolver.shots += 1
	Resolver.pending[#Resolver.pending + 1] = { player = player, method = result.method, life = humanoid.Health + DH.armor(character), t = os.clock() }
end

local function judge()
	local now, window = os.clock(), DH.K.get("RES_WATCH")
	for i = #Resolver.pending, 1, -1 do
		local p = Resolver.pending[i]
		if now - p.t >= window then
			table.remove(Resolver.pending, i)
			local character = p.player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local rec = Resolver.per[p.player]
			if humanoid and rec then
				local hit = humanoid.Health + DH.armor(character) < p.life - 0.5
				rec.learner:reward(p.method, hit)
				if hit then Resolver.confirmed += 1 else Resolver.missed += 1 end
			end
		end
	end
end

-- ---- overlay: one mark per estimator on the target, the winner in green
local marks = {}
local function mark(key)
	local m = marks[key]
	if m then return m end
	local ok, square = pcall(function() return Drawing.new("Square") end)
	local okText, text = pcall(function() return Drawing.new("Text") end)
	if not (ok and okText) then return nil end
	square.Filled, square.Thickness, square.Size, square.Color, square.Visible = false, 1.5, Vector2.new(10, 10), COLORS[key] or COLORS.result, false
	text.Size, text.Color, text.Outline, text.Center, text.Visible = 12, COLORS[key] or COLORS.result, true, false, false
	DH.janitor:add(function() pcall(function() square:Remove() end); pcall(function() text:Remove() end) end, "resolver.mark")
	m = { square = square, text = text }
	marks[key] = m
	return m
end
local function hideMarks() for _, m in pairs(marks) do m.square.Visible = false; m.text.Visible = false end end

local function draw()
	if DH.get("monster.resolver.overlay") ~= true then if next(marks) then hideMarks() end return end
	local target = DH.Rage and DH.Rage.target and DH.Rage.target() or nil
	local r = target and Resolver.get(target)
	local camera = workspace.CurrentCamera
	if not (r and camera) then hideMarks(); return end
	local shown = {}
	local function put(key, pos, label)
		local m = mark(key)
		if not m then return end
		local point, onScreen = camera:WorldToViewportPoint(pos)
		m.square.Visible, m.text.Visible = onScreen, onScreen
		if onScreen then
			m.square.Position = Vector2.new(point.X - 5, point.Y - 5)
			m.text.Position = Vector2.new(point.X + 8, point.Y - 6)
			m.text.Text = label
		end
		shown[key] = true
	end
	for _, e in ipairs(r.all or {}) do
		if e and e.pos and e.confidence and e.confidence > 0 then put(e.method, e.pos, string.format("%s %.2f", e.method, e.confidence)) end
	end
	if r.pos then put("result", r.pos, string.format("= %s %.2f", r.method, r.confidence)) end
	for key, m in pairs(marks) do if not shown[key] then m.square.Visible, m.text.Visible = false, false end end
end

function Resolver.init()
	Resolver.conn = DH.Net.onIncoming(DH.safe("resolver.sample", onSample))
	DH.janitor:add(Resolver.conn, "resolver.incoming")
	local acc = 0
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("resolver.step", function(dt)
		acc += dt
		for _, rec in pairs(Resolver.per) do rec.learner:decay(dt) end
		if acc < 0.1 then return end
		acc = 0
		judge()
	end)), "resolver.step")
	DH.janitor:add(S.Run.PreRender:Connect(DH.safe("resolver.draw", draw)), "resolver.draw")
	DH.janitor:add(S.Players.PlayerRemoving:Connect(function(player) Resolver.per[player] = nil end), "resolver.leave")
end
function Resolver.enable() end
function Resolver.disable() hideMarks(); Resolver.pending = {} end
function Resolver.status()
	local target = DH.Rage and DH.Rage.target and DH.Rage.target() or nil
	local r = target and Resolver.get(target)
	local count = 0
	for _ in pairs(Resolver.per) do count += 1 end
	return {
		on = DH.get("monster.resolver.on"), tracked = count, target = target and target.Name or nil,
		method = r and r.method or nil, confidence = r and math.floor(r.confidence * 100) / 100 or nil, low = r and r.low or nil,
		shots = Resolver.shots, confirmed = Resolver.confirmed, missed = Resolver.missed, source = DH.Net.incomingSource,
	}
end
DH.register("resolver", Resolver)
end
-- >>> src/52_defense.lua
do
-- ---- defense: anti-bag, anti-flame, anti-bait, built on the void. Every decision is in pure/threat.lua (tested without a game);
-- this module only describes the world to it, ten times a second, and asks the void for what it decides.
local Threat = DH.F.threat()
local Defense = { assessment = nil, per = {}, lastTrigger = -math.huge, triggers = 0, last = 0, reasons = {} }
DH.Defense = Defense

DH.define("monster.defense.on", { kind = "toggle", default = false, label = "Defense", desc = "Void when a threat is near, as set below.", group = "defense" })
DH.define("monster.defense.antiBag", { kind = "toggle", default = true, label = "Anti bag", desc = "Knocked, with someone about to pick you up: go to the void.", group = "defense" })
DH.define("monster.defense.antiFlame", { kind = "toggle", default = true, label = "Anti flame", desc = "A flamethrower close or closing: go to the void.", group = "defense" })
DH.define("monster.defense.antiBait", { kind = "toggle", default = true, label = "Anti bait", desc = "An armed player waiting by your way back: stay hidden.", group = "defense" })

local function cfg()
	local K = DH.K.get
	return { safeDistance = K("DEF_SAFE"), gunRange = K("DEF_GUN"), flameRange = K("DEF_FLAME"), bagRange = K("DEF_BAG"), teleportJump = K("DEF_TELE") }
end

---What a held tool means for a fight.
function Defense.classify(tool)
	if not tool then return "none" end
	local name = string.lower(tool.Name)
	if string.find(name, "flame", 1, true) then return "flame" end
	if tool:FindFirstChild("Ammo") and tool:FindFirstChild("Handle") then return "gun" end
	if string.find(name, "combat", 1, true) or string.find(name, "knife", 1, true) or string.find(name, "bat", 1, true) or string.find(name, "sword", 1, true)
		or string.find(name, "katana", 1, true) or string.find(name, "machete", 1, true) or string.find(name, "pitchfork", 1, true) or string.find(name, "shovel", 1, true) then
		return "melee"
	end
	return "none"
end

local function isFriend(player)
	local roster = B and B.Roster
	return roster ~= nil and roster.friends ~= nil and roster.friends[player.UserId] == true
end

local function describe()
	local now = os.clock()
	local rootMe = DH.root()
	if not rootMe then return nil end
	local character = DH.character()
	local humanoid = DH.humanoid()
	local me = {
		pos = rootMe.Position, ko = DH.knocked(character), health = humanoid and humanoid.Health or 100,
		armor = DH.armor(character), protected = DH.hasShield(character),
	}
	local players = {}
	for _, player in ipairs(S.Players:GetPlayers()) do
		if player ~= DH.LP then
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local humanoidOther = c and c:FindFirstChildOfClass("Humanoid")
			if root and humanoidOther and humanoidOther.Health > 0 then
				local per = Defense.per[player] or { pos = root.Position, t = now, stillSince = now }
				Defense.per[player] = per
				local dt = now - per.t
				local moved = (root.Position - per.pos).Magnitude
				local teleported = Threat.teleport(per.pos, root.Position, dt, cfg())
				if teleported then per.teleAt = now end
				if moved > 0.5 then per.stillSince = now end
				per.pos, per.t = root.Position, now
				players[#players + 1] = {
					id = player.UserId, name = player.Name, pos = root.Position, vel = root.AssemblyLinearVelocity,
					ko = DH.knocked(c), friend = isFriend(player), protected = DH.hasShield(c),
					tool = Defense.classify(c:FindFirstChildOfClass("Tool")),
					still = now - per.stillSince, teleported = per.teleAt ~= nil and now - per.teleAt < 2,
				}
			end
		end
	end
	return me, players
end

---The picture, at most ten times a second.
function Defense.assess(force)
	local now = os.clock()
	if Defense.assessment and not force and now - Defense.last < 0.1 then return Defense.assessment end
	Defense.last = now
	local me, players = describe()
	if not me then Defense.assessment = nil; return nil end
	local returnPos = DH.Fakepos and DH.Fakepos.real and DH.Fakepos.real.Position or me.pos
	Defense.assessment = Threat.assess(me, players, cfg(), returnPos)
	Defense.me, Defense.players = me, players
	return Defense.assessment
end

local function wanted()
	return DH.get("monster.defense.on") == true or DH.get("monster.void.protect") == true
		or (DH.Void ~= nil and DH.Void.state.wanted == true) or (DH.Rage ~= nil and DH.Rage.on())
end

---How much one player threatens me right now (0..1), from the last picture.
function Defense.threatOf(player)
	local me = Defense.me
	if not me then return 0 end
	for _, other in ipairs(Defense.players or {}) do
		if other.id == player.UserId then return math.min(1, Threat.score(me, other, cfg())) end
	end
	return 0
end

function Defense.threatNear()
	if not wanted() then return false end
	local a = Defense.assess()
	return a ~= nil and a.threatNear == true
end
function Defense.unsafe()
	local a = Defense.assessment or Defense.assess()
	return a ~= nil and a.unsafe == true
end
---True for a moment after the defense asked for the void (physrep must be let go, the ride is outranked).
function Defense.active() return os.clock() - Defense.lastTrigger < 1.6 end

local function trigger(source, reason)
	Defense.lastTrigger = os.clock()
	Defense.triggers += 1
	Defense.reasons[source] = reason
	if DH.Physrep then DH.Physrep.detach("defense void") end
	if DH.Void then DH.Void.request("defense:" .. source, 1.5) end
end

function Defense.init()
	local acc = 0
	DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("defense.step", function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		if not wanted() then return end
		local a = Defense.assess(true)
		if not a then return end
		if DH.get("monster.defense.on") then
			if a.antiBag and DH.get("monster.defense.antiBag") then trigger("bag", a.reasons[1]) end
			if a.antiFlame and DH.get("monster.defense.antiFlame") then trigger("flame", a.reasons[#a.reasons]) end
			if a.camper and DH.get("monster.defense.antiBait") and DH.Void and DH.Void.state.voided then trigger("camper", "camper") end
		end
		if DH.get("monster.void.protect") and a.threatNear then trigger("protect", "threat near") end
	end)), "defense.step")
	DH.janitor:add(S.Players.PlayerRemoving:Connect(function(player) Defense.per[player] = nil end), "defense.leave")
end
function Defense.enable() end
function Defense.disable()
	Defense.assessment = nil
	Defense.lastTrigger = -math.huge
	if DH.Void then for _, source in ipairs({ "bag", "flame", "camper", "protect" }) do DH.Void.cancel("defense:" .. source) end end
end
function Defense.status()
	local a = Defense.assessment
	return {
		on = DH.get("monster.defense.on"), triggers = Defense.triggers, active = Defense.active(),
		threatNear = a and a.threatNear or false, unsafe = a and a.unsafe or false, top = a and a.top and a.top.name or nil,
		topScore = a and math.floor(a.topScore * 100) / 100 or 0, reasons = a and a.reasons or {},
	}
end
DH.register("defense", Defense)
end
-- >>> src/60_api.lua
do
-- ---- api: the same entry points a plugin written for the Unnamed Enhancements ragebot calls (set_ragebot, get_target, set_desync_cframe ...),
-- so such plugins run against MONSTER unchanged. Both call styles work: api.f(x) and api:f(x). Identity (CFrame.new()) means off.
local API = {}
DH.API = API

local function method(fn)
	return function(first, ...)
		if first == API then return fn(...) end
		return fn(first, ...)
	end
end

function DH.notify(text, seconds)
	local ok = pcall(function() Window.toast({ title = "MONSTER", text = tostring(text), icon = "skull", time = seconds or 3 }) end)
	if not ok then DH.warn("notify", tostring(text), 1) end
end

API.set_ragebot = method(function(state) return DH.Rage.set(state) end)

---kind: "ragebot" (the current target), "silent" or "aimbot" (the player nearest the mouse who is not a friend).
API.get_target = method(function(kind)
	if kind == "ragebot" or kind == nil then return DH.Rage.target() end
	local best, bestDist
	for _, entry in ipairs(DH.Rage.candidates()) do
		if not entry.friend and not entry.ko and entry.visible and (not bestDist or entry.screenDist < bestDist) then best, bestDist = entry.player, entry.screenDist end
	end
	return best
end)

API.get_character_cache = method(function(player)
	local character = typeof(player) == "Instance" and player.Character
	if not character then return nil end
	local cache = { Character = character, Humanoid = character:FindFirstChildOfClass("Humanoid") }
	for _, part in ipairs(character:GetChildren()) do
		if part:IsA("BasePart") then cache[part.Name] = part end
	end
	return cache
end)

API.get_status_cache = method(function(player)
	local character = typeof(player) == "Instance" and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	return {
		ko = DH.knocked(character), dead = humanoid.Health <= 0, armor = DH.armor(character), health = humanoid.Health, maxHealth = humanoid.MaxHealth,
		shield = DH.hasShield(character), tool = (character:FindFirstChildOfClass("Tool") or {}).Name, state = humanoid:GetState().Name,
		sitting = humanoid.SeatPart ~= nil or humanoid.Sit,
	}
end)

---Both put the server body at `cframe` (it is the same idea here); the identity CFrame withdraws it.
API.set_server_cframe = method(function(cframe) DH.Fakepos.setSource("api", cframe) end)
API.set_desync_cframe = method(function(cframe) DH.Fakepos.setSource("api", cframe) end)

API.teleport = method(function(cframe)
	local root = DH.root()
	if root and typeof(cframe) == "CFrame" then root.CFrame = cframe end
end)
API.notify = method(function(text, seconds) DH.notify(text, seconds) end)
API.on_event = method(function(name, fn) return DH.on(name, fn) end)
API.PauseRageBot = method(function() DH.Rage.pause() end)
API.ResumeRageBot = method(function() DH.Rage.resume() end)
API.ragebot_strafe_override = method(function(fn) if fn == nil then DH.Rage.clearStrafeOverride() else DH.Rage.setStrafeOverride(fn) end end)
API.setStrafeOverride = API.ragebot_strafe_override

-- the UI keys a plugin reads
local OPTION = {
	ragebot_active = "monster.rage.on", ragebot_keybind = "monster.rage.key", ragebot_strafe = "monster.rage.strafe", ragebot_chase = "monster.rage.chase",
	ragebot_walk_to_target = "monster.rage.walk", ragebot_jump_at_target = "monster.rage.jump", ragebot_targets = "monster.rage.targets",
	ragebot_weapon = "monster.rage.weapon", ragebot_flame = "monster.rage.flame", ragebot_stomp_offset = "monster.k.RAGE_STOMP",
	character_prot_void = "monster.void.protect",
}
API.get_option = method(function(key) local id = OPTION[key]; return id and DH.get(id) or nil end)
API.set_option = method(function(key, value) local id = OPTION[key]; if id then DH.set(id, value, true); return true end return false end)

API.status = method(function() return DH.status() end)
API.panic = method(function() DH.panic("api") end)
API.probe = method(function(options) return DH.Probe.run(options) end)
API.version = DH.version

function API.install()
	genv.MONSTER_API = API
	genv.MONSTER_DH = DH
end
function API.remove()
	if genv.MONSTER_API == API then genv.MONSTER_API = nil end
	if genv.MONSTER_DH == DH then genv.MONSTER_DH = nil end
end
end
-- >>> src/70_ui.lua
do
-- ---- ui: keybinds (Hold / Toggle / Always), the panic key, tabs, and the status panel. The values live in BasedHub's Config,
-- so every setting is saved with the profile and a missing, extra or odd value is tolerated (see pure/cfgstore.lua).
local UI = {}
DH.UI = UI

DH.define("monster.panic.key", { kind = "keybind", default = "End", label = "Panic key", desc = "Stops everything, restores the real position on both channels, takes the hooks off.", group = "suite" })

-- ---- keys
do
	local binds = {}
	---@param name string label for the toast
	---@param keyId string config id of the key  @param modeId string? config id of Hold/Toggle/Always
	---@param onState fun(on: boolean)
	function UI.bind(name, keyId, modeId, onState)
		local bind = { name = name, keyId = keyId, modeId = modeId, onState = onState, state = false, always = false }
		binds[#binds + 1] = bind
		return bind
	end
	local function set(bind, on, quiet)
		if bind.state == on then return end
		bind.state = on
		pcall(bind.onState, on)
		if not quiet then DH.notify(bind.name .. ": " .. (on and "on" or "off"), 2) end
	end
	local function matches(input, key)
		if not key then return false end
		if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then return input.KeyCode == key end
		return input.UserInputType == key
	end
	function UI.startKeys()
		DH.janitor:add(S.Input.InputBegan:Connect(DH.safe("ui.keydown", function(input)
			if S.Input:GetFocusedTextBox() then return end
			for _, bind in ipairs(binds) do
				local mode = bind.modeId and DH.get(bind.modeId) or "Toggle"
				if mode ~= "Always" and matches(input, DH.keyOf(DH.get(bind.keyId))) then
					if mode == "Hold" then set(bind, true) else set(bind, not bind.state) end
				end
			end
		end)), "ui.keydown")
		DH.janitor:add(S.Input.InputEnded:Connect(DH.safe("ui.keyup", function(input)
			for _, bind in ipairs(binds) do
				local mode = bind.modeId and DH.get(bind.modeId) or "Toggle"
				if mode == "Hold" and matches(input, DH.keyOf(DH.get(bind.keyId))) then set(bind, false) end
			end
		end)), "ui.keyup")
		local acc = 0
		DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("ui.always", function(dt)
			acc += dt
			if acc < 0.5 then return end
			acc = 0
			for _, bind in ipairs(binds) do
				local mode = bind.modeId and DH.get(bind.modeId) or "Toggle"
				if mode == "Always" and not bind.always then bind.always = true; set(bind, true)
				elseif mode ~= "Always" and bind.always then bind.always = false; set(bind, false) end
			end
		end)), "ui.always")
	end
	-- the panic key is not a mode bind: one press
	DH.janitor:add(S.Input.InputBegan:Connect(DH.safe("ui.panic", function(input)
		if S.Input:GetFocusedTextBox() then return end
		if matches(input, DH.keyOf(DH.get("monster.panic.key"))) then DH.panic("key") end
	end)), "ui.panic")
end

-- ---- panic and stop
function DH.panic(reason)
	if DH.panicked then return end
	DH.panicked = true
	DH.warn("panic", tostring(reason), 0.1)
	DH.fire("panic", reason)
	local root = DH.root()
	pcall(function() DH.Fakepos.panic() end)
	pcall(function() DH.set("monster.fake", false, true); DH.set("monster.desync", false, true) end)
	pcall(function() DH.Physrep.setPanic(true) end)
	pcall(function() DH.Rage.disable() end)
	pcall(function() DH.Void.disable() end)
	pcall(function() DH.Defense.disable() end)
	-- both channels back to the real place: the server body (raknet) and the desync/body-swap one
	pcall(function() DH.Net.release(root and root.CFrame) end)
	pcall(function() if DH.desyncStop then DH.desyncStop() end end)
	pcall(function() DH.Net.disable() end)
	pcall(function() DH.Probe.disable() end)
	DH.janitor:clean()
	pcall(function() DH.API.remove() end)
	DH.notify("PANIC: everything is off and unhooked (" .. tostring(reason) .. "). Reload MONSTER to use it again.", 6)
end

---Unload: every module off, every connection and hook released.
function DH.stop()
	if DH.stopped then return end
	DH.stopped = true
	DH.fire("unload")
	DH.disableAll("unload")
	pcall(function() if DH.desyncStop then DH.desyncStop() end end)
	DH.janitor:clean()
	DH.save()
	pcall(function() DH.API.remove() end)
end

-- ---- tabs
local function control(section, id)
	local def = DH.SCHEMA[id]
	if not def then return end
	local label, desc = def.label or id, def.desc
	if def.kind == "toggle" then section:toggle({ id = id, label = label, desc = desc, default = def.default })
	elseif def.kind == "slider" then section:slider({ id = id, label = label, desc = desc, min = def.min, max = def.max, step = def.step, default = def.default, suffix = def.suffix })
	elseif def.kind == "dropdown" then section:dropdown({ id = id, label = label, desc = desc, options = def.options, default = def.default })
	elseif def.kind == "keybind" then section:keybind({ id = id, label = label, desc = desc, default = def.default })
	elseif def.kind == "input" then section:input({ id = id, label = label, desc = desc, default = def.default })
	end
end
UI.control = control

local function controls(section, ids) for _, id in ipairs(ids) do control(section, id) end end

---Called from the Desync tab's own build: the new fake-position modes, the void, and physrep, beside the older controls.
function UI.extras(page)
	local fp = page:section({ title = "Fake position modes", icon = "map-pin", desc = "Pick Static, Follow, Jitter, Anchor or Orbit strafe under Where." })
	controls(fp, { "monster.fakepos.offX", "monster.fakepos.offY", "monster.fakepos.offZ", "monster.fakepos.radius", "monster.fakepos.rate",
		"monster.fakepos.anchorKey", "monster.fakepos.resetOnKO", "monster.fakepos.backend", "monster.fakepos.orbitAround", "monster.fakepos.moveReal" })
	local void = page:section({ title = "Void", icon = "orbit", desc = "Where the body goes, when, and for how long." })
	controls(void, { "monster.void.position", "monster.void.protect", "monster.void.whenDead", "monster.void.whileWaiting", "monster.void.respawnRamp", "monster.void.key", "monster.void.keyMode" })
	local ride = page:section({ title = "Ride the target", icon = "shuffle", desc = "PhysicsRepRootPart: the stomp spot moves with the target." })
	controls(ride, { "monster.physrep.on" })
end

local function addPage(id, title, icon, build)
	task.spawn(function()
		local giveUp = os.clock() + 60
		while not (Window.pages and Window.pages["dahood.ragebot"]) and os.clock() < giveUp and GUI.Parent do task.wait(0.25) end
		local rage = Window.pages and Window.pages["dahood.ragebot"]
		if not rage or DH.stopped then return end
		local last = rage.order
		for _, page in ipairs(Window.order) do
			if page.group == rage.group and page.order > last then last = page.order end
		end
		Window.page({ id = id, title = title, icon = icon, group = rage.group, order = last + 1, eyebrow = rage.eyebrow, build = build })
		UI.pages = UI.pages or {}
		UI.pages[#UI.pages + 1] = id
	end)
end

local STATUS = {}
local function statusText()
	local fp, net, void, rage, res, def, phys = DH.Fakepos.status(), DH.Net.status(), DH.Void.status(), DH.Rage.status(), DH.Resolver.status(), DH.Defense.status(), DH.Physrep.status()
	return {
		string.format("Fake position: %s via %s%s  owner %s%s", tostring(fp.mode), tostring(fp.backend), fp.degraded and " (DEGRADED)" or "", tostring(fp.owner), fp.suspended and " (suspended)" or ""),
		string.format("Raknet: %s  sent %d  blocked %d  failed %d  %.1f/s%s", net.available and "ready" or ("off: " .. tostring(net.reason)), net.sent, net.blocked, net.failed, net.rate, net.denied and "  DENIED" or ""),
		string.format("Void: %s%s  Defense: threat %s", void.phase, void.ramp and (" ramp " .. void.ramp) or "", def.threatNear and (tostring(def.top) .. " " .. def.topScore) or "none"),
		string.format("Target: %s  fired %d  stomps %d  kills %d%s", rage.target or "none", rage.fired, rage.stomps, rage.kills, rage.autoPaused and ("  PAUSED: " .. rage.autoPaused) or ""),
		string.format("Resolver: %s %s  shots %d (hit %d)", res.method or "-", res.confidence and string.format("%.2f", res.confidence) or "-", res.shots, res.confirmed),
		string.format("Ride: %s  Last error: %s", phys.attached and "on" or (phys.why or "off"), tostring(DH.lastError or "none")),
	}
end

function UI.init()
	UI.bind("Ragebot", "monster.rage.key", "monster.rage.keyMode", function(on) DH.Rage.set(on) end)
	UI.bind("Void", "monster.void.key", "monster.void.keyMode", function(on) DH.Void.keyState(on) end)
	UI.startKeys()
	-- the anchor key is one press
	DH.janitor:add(S.Input.InputBegan:Connect(DH.safe("ui.anchor", function(input)
		if S.Input:GetFocusedTextBox() then return end
		local key = DH.keyOf(DH.get("monster.fakepos.anchorKey"))
		if key and ((typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode and input.KeyCode == key) or input.UserInputType == key) then
			DH.notify("Anchor: " .. (DH.Fakepos.toggleAnchor() and "held here" or "let go"), 2)
		end
	end)), "ui.anchor")

	addPage("dahood.mrage", "Rage", "skull", function(page)
		local a = page:section({ title = "Ragebot", icon = "skull", desc = "MONSTER's own fighter: shoots from the fake position." })
		controls(a, { "monster.rage.on", "monster.rage.key", "monster.rage.keyMode", "monster.rage.safety" })
		local t = page:section({ title = "Targets", icon = "search", desc = "Who it picks, and who it never does." })
		controls(t, { "monster.rage.targetMode", "monster.rage.targets", "monster.rage.fov", "monster.rage.walls", "monster.rage.teamCheck", "monster.rage.switchWait" })
		local f = page:section({ title = "Firing", icon = "settings-2", desc = "The gun, and how it is fired." })
		controls(f, { "monster.rage.part", "monster.rage.weapon", "monster.rage.flame", "monster.rage.salvo", "monster.rage.pipeline", "monster.rage.oneTap", "monster.rage.snipe", "monster.rage.autoReload", "monster.rage.smartReload" })
		local m = page:section({ title = "Movement", icon = "orbit", desc = "Where it stands and how your own body moves." })
		controls(m, { "monster.rage.strafe", "monster.rage.strafeStyle", "monster.rage.pattern", "monster.rage.chase", "monster.rage.walk", "monster.rage.jump", "monster.rage.stomp" })
	end)
	addPage("dahood.mresolver", "Resolver", "radio", function(page)
		local a = page:section({ title = "Resolver", icon = "radio", desc = "Finds the real body of a player who hides." })
		controls(a, { "monster.resolver.on", "monster.resolver.skipLow", "monster.resolver.learn", "monster.resolver.overlay" })
		local k = page:section({ title = "Tuning", icon = "settings-2", desc = "The numbers the estimators use." })
		for _, def in ipairs(DH.KDEFS) do if def[6] == "resolver" then control(k, DH.K.id(def[1])) end end
	end)
	addPage("dahood.mdefense", "Defense", "shield", function(page)
		local a = page:section({ title = "Defense", icon = "shield", desc = "Anti bag, anti flame, anti bait: all by going to the void." })
		controls(a, { "monster.defense.on", "monster.defense.antiBag", "monster.defense.antiFlame", "monster.defense.antiBait" })
		local k = page:section({ title = "Tuning", icon = "settings-2", desc = "Distances and holds." })
		for _, def in ipairs(DH.KDEFS) do if def[6] == "defense" or def[6] == "void" then control(k, DH.K.id(def[1])) end end
	end)
	addPage("dahood.msuite", "Suite", "settings-2", function(page)
		local s = page:section({ title = "Status", icon = "radio", desc = "What the suite is doing now." })
		STATUS.lines = {}
		for i = 1, 6 do STATUS.lines[i] = s:label("") end
		local acc = 0
		STATUS.conn = DH.janitor:add(S.Run.Heartbeat:Connect(DH.safe("ui.status", function(dt)
			acc += dt
			if acc < 0.25 then return end
			acc = 0
			if not STATUS.lines[1].frame.Parent then return end
			for i, text in ipairs(statusText()) do STATUS.lines[i].set(text) end
		end)), "ui.status")
		local act = page:section({ title = "Actions", icon = "shield", desc = "Panic stops and unhooks everything." })
		act:button({ label = "Panic", text = "Stop all", style = "danger", desc = "Everything off, real position restored, hooks removed. Reload to use it again.", run = function() DH.panic("button") end })
		act:button({ label = "Probe", text = "Run", desc = "What this executor can do: written to monster_probe.json.", run = function()
			DH.Probe.run({ done = function(r) DH.notify("Probe done: raknet " .. tostring(r.scan.raknet.present) .. ", receive hooks " .. tostring(#r.scan.receive)) end })
		end })
		controls(act, { "monster.panic.key" })
		local groups, order = {}, {}
		for _, def in ipairs(DH.KDEFS) do
			if def[6] ~= "resolver" and def[6] ~= "defense" and def[6] ~= "void" then
				if not groups[def[6]] then groups[def[6]] = {}; order[#order + 1] = def[6] end
				table.insert(groups[def[6]], def[1])
			end
		end
		for _, name in ipairs(order) do
			local sec = page:section({ title = "Tuning: " .. name, icon = "settings-2", desc = "Numbers from measurement; change with care." })
			for _, k in ipairs(groups[name]) do control(sec, DH.K.id(k)) end
		end
	end)
end
function UI.enable() end
function UI.disable()
	for _, id in ipairs(UI.pages or {}) do pcall(function() if Window.pages and Window.pages[id] then Window.removePage(id) end end) end
	UI.pages = {}
end
function UI.status() return { pages = UI.pages and #UI.pages or 0 } end
DH.register("ui", UI)
end
-- >>> src/80_wire.lua
do
-- ---- wire: start the modules in dependency order (only in Da Hood), publish the API
DH.sanitize()
if not DH.isDaHood then
	DH.skipped = "not Da Hood (GameId " .. tostring(game.GameId) .. ")"
else
	for _, name in ipairs({ "net", "fakepos", "void", "physrep", "defense", "resolver", "ragebot", "ui" }) do
		local module = DH.modules[name]
		local ok, err = pcall(function() if module.init then module.init() end end)
		if not ok then DH.fail("init:" .. name, err) end
	end
	DH.API.install()
end
end
end

-- >>> src/90_desync_legacy.lua
-- [dh] wired to the suite by tools/patch_legacy.py
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
	local Rak = DH.Net -- the packet layer is the suite's net module (pure/codec.lua + src/30_net.lua), under the names this loop uses
	local function rakOn() return Rak.available and Config.get("monster.rak") == true end
	local function voiding() return DH.Void.active() end

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

	local function wanted()
		if DH.Fakepos.suspended() then return false end
		return Config.get("monster.desync") == true or Config.get("monster.fake") == true or DH.Void.active() or DH.Fakepos.hasForced()
	end
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
		local forced = DH.Fakepos.forced(cframe)
		if forced then return forced end
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
			local suite
			if where == "thunder" then
				local target = pick(cframe.Position)
				local theirRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				suite = DH.Fakepos.compute(where, cframe, DH.Rage.centre() or (theirRoot and theirRoot.Position), rakOn())
			else
				suite = DH.Fakepos.compute(where, cframe, nil, rakOn())
			end
			if suite then
				centre = suite
			elseif where == "offset" then
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
			DH.Fakepos.publish(root and root.CFrame, nil)
			DH.Fakepos.onIdle(character)
			hideBox()
			hunt.player, frozenAt = nil, nil
			ghost.shift, ghost.real, ghost.home, ghost.decoy = nil, nil, nil, false
			return
		end
		real = root.CFrame
		DH.Fakepos.applyVelocity(root)
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
					local style = DH.Void.style()
					if style == "orbit" or style == "orbit-thunder" then
						Rak.hold(DH.Fakepos.compute("thunder", real, DH.Rage.centre(), true), root, dt)
						return
					end
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
			local style = DH.Void.style()
			if style == "orbit" or style == "orbit-thunder" then
				put, putVoid = DH.Fakepos.compute("thunder", real, DH.Rage.centre(), false), true
			else
				if Config.get("monster.voidSpam") or not voidSpot or style == "nan1" or style == "nan2" then
					voidSpot = DH.Void.spot(style == "sky" and "far" or style)
				end
				put, putVoid = CFrame.new(voidSpot), true
			end
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
		DH.Fakepos.publish(real, fake, packets and "raknet" or "swap")
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
				options = { { "decoy", "Decoy" }, { "ghost", "Ghost" }, { "target", "On target" }, { "void", "Void" }, { "orbit", "Orbit target" }, { "offset", "Offset" }, { "freeze", "Freeze" }, { "below", "Below" }, { "behind", "Behind" }, { "side", "Side" }, { "above", "Above" }, table.unpack(DH.Fakepos.MODES) }, default = "decoy" })
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
			DH.UI.extras(page)
		end })
	end)

	DH.desyncStop = function() Desync.stop() end
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

-- >>> src/99_tail.lua
-- [dh] wired to the suite by tools/patch_legacy.py
-- ---- Unload: nothing of MONSTER's is left behind
local unload = B.unload
if unload then
	B.unload = function(...)
		renamer:Disconnect()
		for _, connection in ipairs(adopted) do connection:Disconnect() end
		DH.stop()
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

warn("[MONSTER] v4 loaded: intro=" .. tostring(introReady) .. " board=" .. tostring(boardReady) .. " caught=" .. tostring(caught) .. " dh=" .. DH.build .. (DH.skipped and (" (" .. DH.skipped .. ")") or ""))
