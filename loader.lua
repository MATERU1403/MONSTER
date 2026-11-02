-- ============================================================================
--  MONSTER Hub Loader
--
--  Loads BasedHub, then skins it as MONSTER: dark crimson theme, gothic fonts,
--  atmospheric overlays, and rebranded UI. All visuals, no layout changes.
--
--  Usage: execute this file in your executor. It loads BasedHub from GitHub,
--  waits for it to initialise, then applies the MONSTER reskin on top.
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

-- wait for the window to build
local tries = 0
while not B.Window or not B.Window.built do
	task.wait(0.25)
	tries = tries + 1
	if tries > 120 then break end
end
task.wait(0.5)

-- ---- Step 3: MONSTER Visual Reskin ----
local Theme = B.Theme
local T = B.T
local UI = B.UI
local Window = B.Window
local Config = B.Config
local util = B.util
local hex = util.hex

-- ========================= COLOUR SCHEME =================================
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

-- ========================= REBRAND =======================================
local function replaceText(parent, target, replacement)
	for _, child in ipairs(parent:GetDescendants()) do
		if (child:IsA("TextLabel") or child:IsA("TextButton")) and child.Text == target then
			child.Text = replacement
		end
	end
end

if B.gui then
	replaceText(B.gui, "BASED", "MONSTER")
end

if Window.eyebrow then
	Window.eyebrow.Text = "MONSTER"
end

local origSetPage = Window.setPage
if origSetPage then
	Window.setPage = function(...)
		local result = origSetPage(...)
		task.defer(function()
			if Window.eyebrow and Window.eyebrow.Text == "BASED" then
				Window.eyebrow.Text = "MONSTER"
			end
		end)
		return result
	end
end

-- ========================= FONTS =========================================
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

-- ========================= DECORATIVE OVERLAYS ===========================
task.defer(function()
	local gui = B.gui
	if not gui then return end

	local windowFrame
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("Frame") and child.Name == "Window" then
			windowFrame = child
			break
		end
	end
	if not windowFrame then
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("Frame") and child.AbsoluteSize.X > 200 and child.AbsoluteSize.Y > 200 then
				windowFrame = child
				break
			end
		end
	end
	if not windowFrame then return end

	-- Vignette: subtle edge darkening
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

	-- Blood line at top with glow
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

	-- Breathing pulse on the blood accent
	local pulseAlpha = 0
	local pulseDir = 1
	local PULSE_SPEED = 0.4
	local PULSE_MIN = 0.0
	local PULSE_MAX = 0.15

	local heartbeat = game:GetService("RunService").Heartbeat
	local pulseConn
	pulseConn = heartbeat:Connect(function(dt)
		if not windowFrame.Parent then
			pulseConn:Disconnect()
			return
		end
		pulseAlpha = pulseAlpha + dt * PULSE_SPEED * pulseDir
		if pulseAlpha >= 1 then pulseAlpha = 1; pulseDir = -1
		elseif pulseAlpha <= 0 then pulseAlpha = 0; pulseDir = 1 end
		local t = PULSE_MIN + (PULSE_MAX - PULSE_MIN) * (0.5 - 0.5 * math.cos(pulseAlpha * math.pi))
		bloodLine.BackgroundTransparency = 0.3 - t
		bloodGlow.BackgroundTransparency = 0.92 - t * 0.5
	end)

	-- Bottom shadow
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

-- ========================= CLEANUP ON UNLOAD =============================
local origUnload = B.unload
if origUnload then
	B.unload = function(...)
		pcall(function()
			local gui = B.gui
			if gui then
				for _, child in ipairs(gui:GetDescendants()) do
					if string.sub(child.Name, 1, 7) == "Monster" then
						child:Destroy()
					end
				end
			end
		end)
		if Theme.schemes.monster then
			Theme.schemes.monster = nil
		end
		return origUnload(...)
	end
end

-- ========================= DONE ==========================================
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

warn("[MONSTER] Visual reskin applied: scheme=monster, accent=crimson")
