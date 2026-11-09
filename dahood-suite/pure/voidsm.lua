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
