-- ============================================================================
--  MONSTER Hub Loader v2
--
--  Loads BasedHub, then skins it as MONSTER: dark crimson theme, gothic fonts,
--  atmospheric overlays, rebranded UI, custom cinematic, and MONSTER intro.
--
--  Usage: execute this file in your executor.
-- ============================================================================

-- ---- Step 1: Load BasedHub ----
loadstring(game:HttpGet("https://raw.githubusercontent.com/Mrzaytoon/based-hub/main/loader.lua"))()

-- ---- Step 2: Wait for BASED to boot ----
local genv = getgenv()
local waited = 0
while not genv.BASED and waited < 30 do
	task.wait(0.25)
	waited = waited + 0.25
end
local B = genv.BASED
if not B then warn("[MONSTER] BASED hub did not load"); return end

local tries = 0
while not B.Window or not B.Window.built do
	task.wait(0.25)
	tries = tries + 1
	if tries > 120 then break end
end
task.wait(0.5)

-- ---- Step 3: Grab references ----
local Theme = B.Theme
local T = B.T
local UI = B.UI
local Window = B.Window
local Config = B.Config
local util = B.util
local hex = util.hex

local GUI = Window.gui
if not GUI then
	warn("[MONSTER] Window.gui is nil, cannot reskin")
	return
end

-- ---- Step 4: MONSTER colour scheme ----
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

table.insert(Theme.accents, 1, {
	id    = "crimson",
	label = "Crimson",
	color = hex("8B0000"),
})

Theme.set({
	scheme = "monster",
	accent = hex("8B0000"),
	glass  = 0.85,
	radius = 0.8,
})

T.ok   = hex("3D8B37")
T.warn = hex("C9842A")
T.bad  = hex("DC143C")

-- BasedHub's own brand film would play before ours; this persists in prefs
pcall(Config.set, "app.intro", "off")

-- ---- Step 5: REBRAND all "BASED" text to "MONSTER" ----
-- BasedHub redraws some labels (e.g. the Menu style dropdown) after boot, so
-- each renamed label keeps a watcher that renames it again.
local watched = setmetatable({}, { __mode = "k" })

local function rebrand(label)
	if not (label:IsA("TextLabel") or label:IsA("TextButton")) or label.Text ~= "BASED" then return end
	label.Text = "MONSTER"
	if watched[label] then return end
	watched[label] = true
	label:GetPropertyChangedSignal("Text"):Connect(function()
		if label.Text == "BASED" then label.Text = "MONSTER" end
	end)
end

for _, d in ipairs(GUI:GetDescendants()) do rebrand(d) end
GUI.DescendantAdded:Connect(function(d) task.defer(rebrand, d) end)

-- ---- Step 6: Download cinematic image and set home hero ----
task.defer(function()
	local ok, err = pcall(function()
		local imgUrl = "https://raw.githubusercontent.com/MATERU1403/MONSTER/main/cinematic/damon_dark.jpg"
		local imgData = game:HttpGet(imgUrl)
		if not imgData or #imgData < 100 then
			warn("[MONSTER] Failed to download cinematic image")
			return
		end

		local fileName = "monster_hero.jpg"
		writefile(fileName, imgData)
		local contentId = getcustomasset(fileName)

		local function findHeroStill(parent)
			for _, desc in ipairs(parent:GetDescendants()) do
				if desc:IsA("ImageLabel") and desc.Name == "Still" then
					local hero = desc.Parent
					if hero and hero.Name == "Hero" then
						return desc
					end
				end
			end
			return nil
		end

		local still = findHeroStill(GUI)
		if still then
			still.Image = contentId
			still.ScaleType = Enum.ScaleType.Crop
			still.ImageTransparency = 0
		else
			for _, page in ipairs(GUI:GetDescendants()) do
				if page.Name == "home" and (page:IsA("Frame") or page:IsA("ScrollingFrame")) then
					for _, d in ipairs(page:GetDescendants()) do
						if d:IsA("ImageLabel") and d.Name == "Still" then
							d.Image = contentId
							d.ScaleType = Enum.ScaleType.Crop
							d.ImageTransparency = 0
							break
						end
					end
					break
				end
			end
		end
	end)
	if not ok then warn("[MONSTER] Hero image error: " .. tostring(err)) end
end)

-- ---- Step 7: Custom MONSTER intro overlay ----
task.defer(function()
	local ok, err = pcall(function()
		local imgUrl1 = "https://raw.githubusercontent.com/MATERU1403/MONSTER/main/cinematic/damon_dark.jpg"
		local imgUrl2 = "https://raw.githubusercontent.com/MATERU1403/MONSTER/main/cinematic/skull_dark.jpg"

		local data1 = game:HttpGet(imgUrl1)
		local data2 = game:HttpGet(imgUrl2)

		writefile("monster_intro_1.jpg", data1)
		writefile("monster_intro_2.jpg", data2)
		local asset1 = getcustomasset("monster_intro_1.jpg")
		local asset2 = getcustomasset("monster_intro_2.jpg")

		local TweenService = game:GetService("TweenService")

		local introGui = Instance.new("ScreenGui")
		introGui.Name = "MonsterIntro"
		introGui.DisplayOrder = 99999
		introGui.IgnoreGuiInset = true
		introGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		introGui.Parent = gethui()

		local bg = Instance.new("Frame")
		bg.Name = "BG"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		bg.BackgroundTransparency = 0
		bg.BorderSizePixel = 0
		bg.ZIndex = 1
		bg.Parent = introGui

		local img1 = Instance.new("ImageLabel")
		img1.Name = "Frame1"
		img1.Size = UDim2.fromScale(1, 1)
		img1.Position = UDim2.fromScale(0, 0)
		img1.BackgroundTransparency = 1
		img1.Image = asset1
		img1.ScaleType = Enum.ScaleType.Crop
		img1.ImageTransparency = 1
		img1.ZIndex = 2
		img1.Parent = bg

		local img2 = Instance.new("ImageLabel")
		img2.Name = "Frame2"
		img2.Size = UDim2.fromScale(1, 1)
		img2.Position = UDim2.fromScale(0, 0)
		img2.BackgroundTransparency = 1
		img2.Image = asset2
		img2.ScaleType = Enum.ScaleType.Crop
		img2.ImageTransparency = 1
		img2.ZIndex = 3
		img2.Parent = bg

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.fromScale(0.8, 0.15)
		title.Position = UDim2.fromScale(0.1, 0.4)
		title.BackgroundTransparency = 1
		title.Text = "MONSTER"
		title.TextColor3 = Color3.fromRGB(139, 0, 0)
		title.TextTransparency = 1
		title.TextScaled = true
		title.Font = Enum.Font.GothamBlack
		title.ZIndex = 10
		title.Parent = bg

		local subtitle = Instance.new("TextLabel")
		subtitle.Name = "Sub"
		subtitle.Size = UDim2.fromScale(0.6, 0.06)
		subtitle.Position = UDim2.fromScale(0.2, 0.56)
		subtitle.BackgroundTransparency = 1
		subtitle.Text = "THE DARKNESS AWAKENS"
		subtitle.TextColor3 = Color3.fromRGB(200, 180, 160)
		subtitle.TextTransparency = 1
		subtitle.TextScaled = true
		subtitle.Font = Enum.Font.Gotham
		subtitle.ZIndex = 10
		subtitle.Parent = bg

		local redLine = Instance.new("Frame")
		redLine.Name = "RedLine"
		redLine.Size = UDim2.new(0, 0, 0, 2)
		redLine.Position = UDim2.fromScale(0.5, 0.54)
		redLine.AnchorPoint = Vector2.new(0.5, 0.5)
		redLine.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
		redLine.BackgroundTransparency = 0.3
		redLine.BorderSizePixel = 0
		redLine.ZIndex = 10
		redLine.Parent = bg

		task.wait(0.3)

		TweenService:Create(img1, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { ImageTransparency = 0 }):Play()
		task.wait(0.8)

		TweenService:Create(img1, TweenInfo.new(4, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1.1, 1.1),
			Position = UDim2.fromScale(-0.05, -0.05),
		}):Play()

		task.wait(1.5)

		TweenService:Create(title, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { TextTransparency = 0 }):Play()
		task.wait(0.3)
		TweenService:Create(redLine, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0.4, 0, 0, 2) }):Play()
		task.wait(0.4)
		TweenService:Create(subtitle, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { TextTransparency = 0.1 }):Play()

		task.wait(2.0)

		TweenService:Create(img1, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { ImageTransparency = 1 }):Play()
		TweenService:Create(title, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
		TweenService:Create(subtitle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 1 }):Play()
		TweenService:Create(redLine, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(0, 0, 0, 2) }):Play()
		task.wait(0.8)

		TweenService:Create(img2, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { ImageTransparency = 0.1 }):Play()
		task.wait(0.5)

		TweenService:Create(img2, TweenInfo.new(3, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1.15, 1.15),
			Position = UDim2.fromScale(-0.075, -0.075),
		}):Play()

		local title2 = Instance.new("TextLabel")
		title2.Name = "Title2"
		title2.Size = UDim2.fromScale(0.8, 0.2)
		title2.Position = UDim2.fromScale(0.1, 0.38)
		title2.BackgroundTransparency = 1
		title2.Text = "MONSTER"
		title2.TextColor3 = Color3.fromRGB(180, 0, 0)
		title2.TextTransparency = 1
		title2.TextScaled = true
		title2.Font = Enum.Font.GothamBlack
		title2.ZIndex = 10
		title2.Parent = bg

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(50, 0, 0)
		stroke.Transparency = 0.5
		stroke.Parent = title2

		task.wait(0.5)
		TweenService:Create(title2, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { TextTransparency = 0 }):Play()

		task.wait(2.5)

		TweenService:Create(img2, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { ImageTransparency = 1 }):Play()
		TweenService:Create(title2, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { TextTransparency = 1 }):Play()
		task.wait(1.5)

		TweenService:Create(bg, TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		task.wait(2.2)

		introGui:Destroy()
	end)
	if not ok then warn("[MONSTER] Intro error: " .. tostring(err)) end
end)

-- ---- Step 8: Fonts ----
task.defer(function()
	local F = B.F
	if not F then return end
	local ok, gothic = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Bold)
	local ok2, gothicHeavy = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Heavy)
	if ok then
		F.text600 = gothic
		if ok2 then F.text700 = gothicHeavy end
	end
	if UI and UI.sweepFonts then
		task.wait(0.3)
		UI.sweepFonts()
	end
end)

-- ---- Step 9: Decorative overlays ----
task.defer(function()
	local stage = GUI:FindFirstChild("Stage", true)
	local windowFrame = stage and stage:FindFirstChild("Window")
	if not windowFrame then
		for _, child in ipairs(GUI:GetDescendants()) do
			if child:IsA("Frame") and child.Name == "Window" then
				windowFrame = child
				break
			end
		end
	end
	if not windowFrame then return end

	local vignetteFrame = Instance.new("Frame")
	vignetteFrame.Name = "MonsterVignette"
	vignetteFrame.Size = UDim2.fromScale(1, 1)
	vignetteFrame.Position = UDim2.fromScale(0, 0)
	vignetteFrame.BackgroundColor3 = Color3.fromRGB(8, 0, 0)
	vignetteFrame.BackgroundTransparency = 0.88
	vignetteFrame.BorderSizePixel = 0
	vignetteFrame.ZIndex = 900

	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.85),
		NumberSequenceKeypoint.new(0.7, 0.85),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Rotation = 90
	gradient.Parent = vignetteFrame
	vignetteFrame.Parent = windowFrame

	local bloodLine = Instance.new("Frame")
	bloodLine.Name = "MonsterBloodLine"
	bloodLine.Size = UDim2.new(1, 0, 0, 2)
	bloodLine.Position = UDim2.fromScale(0, 0)
	bloodLine.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
	bloodLine.BackgroundTransparency = 0.3
	bloodLine.BorderSizePixel = 0
	bloodLine.ZIndex = 950
	bloodLine.Parent = windowFrame

	local bloodGlow = Instance.new("Frame")
	bloodGlow.Name = "MonsterBloodGlow"
	bloodGlow.Size = UDim2.new(1, 0, 0, 12)
	bloodGlow.Position = UDim2.fromScale(0, 0)
	bloodGlow.BackgroundColor3 = Color3.fromRGB(139, 0, 0)
	bloodGlow.BackgroundTransparency = 0.92
	bloodGlow.BorderSizePixel = 0
	bloodGlow.ZIndex = 899

	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowGradient.Rotation = 90
	glowGradient.Parent = bloodGlow
	bloodGlow.Parent = windowFrame

	local pulseAlpha = 0
	local pulseDir = 1
	local heartbeat = game:GetService("RunService").Heartbeat
	local pulseConn
	pulseConn = heartbeat:Connect(function(dt)
		if not windowFrame.Parent then
			pulseConn:Disconnect()
			return
		end
		pulseAlpha = pulseAlpha + dt * 0.4 * pulseDir
		if pulseAlpha >= 1 then pulseAlpha = 1; pulseDir = -1
		elseif pulseAlpha <= 0 then pulseAlpha = 0; pulseDir = 1 end
		local t = (0.15) * (0.5 - 0.5 * math.cos(pulseAlpha * math.pi))
		bloodLine.BackgroundTransparency = 0.3 - t
		bloodGlow.BackgroundTransparency = 0.92 - t * 0.5
	end)

	local bottomShadow = Instance.new("Frame")
	bottomShadow.Name = "MonsterShadow"
	bottomShadow.Size = UDim2.new(1, 0, 0, 20)
	bottomShadow.Position = UDim2.new(0, 0, 1, -20)
	bottomShadow.BackgroundColor3 = Color3.fromRGB(5, 2, 8)
	bottomShadow.BackgroundTransparency = 0.7
	bottomShadow.BorderSizePixel = 0
	bottomShadow.ZIndex = 899

	local bottomGrad = Instance.new("UIGradient")
	bottomGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	bottomGrad.Rotation = 90
	bottomGrad.Parent = bottomShadow
	bottomShadow.Parent = windowFrame
end)

-- ---- Step 10: Cleanup on unload ----
local origUnload = B.unload
if origUnload then
	B.unload = function(...)
		pcall(function()
			for _, child in ipairs(GUI:GetDescendants()) do
				if string.sub(child.Name, 1, 7) == "Monster" then
					child:Destroy()
				end
			end
			local introGui = gethui():FindFirstChild("MonsterIntro")
			if introGui then introGui:Destroy() end
		end)
		if Theme.schemes.monster then
			Theme.schemes.monster = nil
		end
		return origUnload(...)
	end
end

-- ---- Done ----
task.defer(function()
	task.wait(1)
	if B.Toast and B.Toast.note then
		B.Toast.note({
			icon = "skull",
			text = "MONSTER loaded",
			sub = "Dark crimson \194\183 Gothic \194\183 Atmospheric",
		})
	end
end)

warn("[MONSTER] v2 reskin applied: scheme=monster, accent=crimson, hero=damon, intro=cinematic")
