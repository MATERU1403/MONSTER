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
