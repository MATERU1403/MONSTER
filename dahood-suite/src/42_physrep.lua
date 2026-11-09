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
