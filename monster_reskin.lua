-- ============================================================================
--  MONSTER Visual Reskin
--
--  Run AFTER BasedHub loads. Changes ONLY visual appearance:
--    - Colour scheme: deep black base, blood red accent, bone white text
--    - Accent: crimson blood red
--    - Fonts: heavy gothic feel (BuilderExtended / Code)
--    - Brand text: "BASED" -> "MONSTER"
--    - Decorative overlays: vignette, subtle red glow, blood drip accents
--    - Glass: lower for darker, more opaque feel
--
--  Does NOT touch: layout, tab positions, settings, keybinds, functionality
-- ============================================================================

local genv = getgenv()

-- Wait for BASED to load
local B
local waited = 0
while not genv.BASED and waited < 30 do
	task.wait(0.25)
	waited += 0.25
end
B = genv.BASED
if not B then warn("[MONSTER] BASED hub not found after 30s"); return end

local Theme = B.Theme
local T = B.T
local UI = B.UI
local Window = B.Window
local Config = B.Config
local Motion = B.Motion
local util = B.util

-- ============================= SCHEME =====================================
-- Inject the MONSTER scheme: pitch black base, warm bone ink, muted blood sub
local hex = util.hex

Theme.schemes.monster = {
	label = "Monster",
	base = hex("050208"),       -- near-black with faint purple undertone
	ink  = hex("E8E0D4"),       -- warm bone white
	sub  = hex("8B7E72"),       -- muted taupe
	faint = hex("4A3F3A"),      -- dark brown-grey
	shadow = 0.25,              -- deep shadows
	fill = { 0.06, 0.10, 0.15 },
	stroke = { 0.12, 0.22 },
	dark = true,
}
table.insert(Theme.schemeOrder, "monster")

-- Add blood accent to the accent list
table.insert(Theme.accents, 1, {
	id = "crimson",
	label = "Crimson",
	color = hex("8B0000"),
})

-- Apply the MONSTER scheme + accent
Theme.set({
	scheme = "monster",
	accent = hex("8B0000"),     -- dark crimson
	glass = 0.85,               -- more opaque: mysterious
	radius = 0.8,               -- slightly sharper corners
})

-- Override semantic colours for the horror palette
T.ok   = hex("3D8B37")         -- muted forest green (less cheerful)
T.warn = hex("C9842A")         -- amber
T.bad  = hex("DC143C")         -- crimson

-- ============================= BRAND =====================================
-- Replace "BASED" text with "MONSTER" wherever it appears in the UI
task.defer(function()
	-- The brand label in the sidebar (src/08_window line ~3806)
	local gui = B.gui
	if not gui then return end

	local function findAndReplace(parent, target, replacement)
		for _, child in ipairs(parent:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				if child.Text == target then
					child.Text = replacement
				end
			end
		end
	end

	-- Wait for the window to build
	local tries = 0
	while not Window.built and tries < 120 do
		task.wait(0.25)
		tries += 1
	end
	if not Window.built then return end

	-- Replace brand text
	task.wait(0.5)
	findAndReplace(gui, "BASED", "MONSTER")

	-- The eyebrow above the page title defaults to "BASED"
	if Window.eyebrow then
		Window.eyebrow.Text = "MONSTER"
	end

	-- Hook the eyebrow setter so new pages show "MONSTER" too
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
end)

-- ============================= FONTS =====================================
-- Override the type ramp for a heavier, more gothic feel
-- Keep the same keys so layout is unchanged, just swap the font references
task.defer(function()
	local F = B.F
	if not F then return end

	-- Use heavier weights for a more imposing feel
	local ok, gothic = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Bold)
	local ok2, gothicHeavy = pcall(Font.fromName, "BuilderExtended", Enum.FontWeight.Heavy)
	local ok3, mono = pcall(Font.fromName, "RobotoMono", Enum.FontWeight.Medium)

	if ok then
		-- Override heading fonts to the wider, heavier face
		F.text600 = gothic
		if ok2 then F.text700 = gothicHeavy end
	end

	-- Trigger a font sweep to apply changes across all bound labels
	if UI.sweepFonts then
		task.wait(0.3)
		UI.sweepFonts()
	end
end)

-- ============================= DECORATIVE OVERLAYS =======================
-- Add atmospheric visual effects to the hub window
task.defer(function()
	local gui = B.gui
	if not gui then return end

	-- Wait for the window
	local tries = 0
	while not Window.built and tries < 120 do
		task.wait(0.25)
		tries += 1
	end
	if not Window.built then return end
	task.wait(0.3)

	-- Find the main window frame
	local windowFrame
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("Frame") and child.Name == "Window" then
			windowFrame = child
			break
		end
	end
	if not windowFrame then
		-- Try to find any large frame that could be the window
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("Frame") and child.AbsoluteSize.X > 200 and child.AbsoluteSize.Y > 200 then
				windowFrame = child
				break
			end
		end
	end
	if not windowFrame then return end

	-- 1. Vignette overlay — darkens the edges for a cinematic feel
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "MonsterVignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Position = UDim2.fromScale(0, 0)
	vignette.BackgroundTransparency = 1
	vignette.ImageTransparency = 0.7
	vignette.ImageColor3 = Color3.fromRGB(30, 0, 0) -- dark red tint
	vignette.ZIndex = 999
	-- Use a radial gradient via a circular image that fades to transparent
	-- Since we can't load external images, use a UIGradient on a frame instead
	vignette.Image = ""
	vignette.Parent = windowFrame

	-- Create the vignette with UIGradients instead
	vignette:Destroy()

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

	-- 2. Top blood drip accent — a thin red line at the top of the window
	local bloodLine = Instance.new("Frame")
	bloodLine.Name = "MonsterBloodLine"
	bloodLine.Size = UDim2.new(1, 0, 0, 2)
	bloodLine.Position = UDim2.fromScale(0, 0)
	bloodLine.BackgroundColor3 = Color3.fromRGB(139, 0, 0) -- dark crimson
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

	-- 3. Subtle red pulse on the accent elements — makes the UI feel alive
	local pulseAlpha = 0
	local pulseDir = 1
	local PULSE_SPEED = 0.4  -- cycles per second
	local PULSE_MIN = 0.0
	local PULSE_MAX = 0.15

	local heartbeat = game:GetService("RunService").Heartbeat
	local pulseConn
	pulseConn = heartbeat:Connect(function(dt)
		if not windowFrame.Parent then
			pulseConn:Disconnect()
			return
		end

		pulseAlpha += dt * PULSE_SPEED * pulseDir
		if pulseAlpha >= 1 then pulseAlpha = 1; pulseDir = -1
		elseif pulseAlpha <= 0 then pulseAlpha = 0; pulseDir = 1 end

		local t = PULSE_MIN + (PULSE_MAX - PULSE_MIN) * (0.5 - 0.5 * math.cos(pulseAlpha * math.pi))
		bloodLine.BackgroundTransparency = 0.3 - t
		bloodGlow.BackgroundTransparency = 0.92 - t * 0.5
	end)

	-- 4. Bottom shadow — heavier than default for a grounded feel
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

-- ============================= TOAST STYLE ===============================
-- Override toast colours to match the blood aesthetic
task.defer(function()
	if not B.Toast then return end
	local origNote = B.Toast.note
	if not origNote then return end

	B.Toast.note = function(opts, ...)
		-- Tint toast backgrounds with the monster palette
		if type(opts) == "table" and not opts._monster then
			opts._monster = true
			-- Don't change icon or text, just let the theme system handle colours
		end
		return origNote(opts, ...)
	end
end)

-- ============================= CLEANUP ===================================
-- Register an unload hook so the reskin cleans up if BASED is reloaded
local origUnload = B.unload
if origUnload then
	B.unload = function(...)
		-- Remove our overlays
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

		-- Restore the original scheme
		if Theme.schemes.monster then
			Theme.schemes.monster = nil
		end

		return origUnload(...)
	end
end

-- ============================= DONE ======================================
-- Let the user know the reskin is active
task.defer(function()
	task.wait(1)
	if B.Toast and B.Toast.note then
		B.Toast.note({
			icon = "skull",
			text = "MONSTER reskin active",
			sub = "Dark crimson · Gothic · Atmospheric",
		})
	end
end)

warn("[MONSTER] Visual reskin applied: scheme=monster, accent=crimson")
