-- ============================================================================
--  MONSTER AC FIX 03: Gait animation — cache track references
--
--  The original calls animator:GetPlayingAnimationTracks() every Heartbeat frame
--  and iterates them with string matching. GetPlayingAnimationTracks() allocates a
--  new table each call, creating GC pressure at 60+ fps.
--
--  Fix: cache the walk/run track references. Only re-fetch when the Animator
--  instance changes or the tracks are no longer playing.
-- ============================================================================

-- PATCH: replace the gait() function

local gaitCache = { animator = nil, walkTrack = nil, runTrack = nil, walkId = nil, runId = nil }

local function gait(me, humanoid, speed)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	local animate = me:FindFirstChild("Animate")
	local walkValue, runValue = animate and animate:FindFirstChild("walk"), animate and animate:FindFirstChild("run")
	local walkAnim = walkValue and walkValue:FindFirstChildOfClass("Animation")
	local runAnim = runValue and runValue:FindFirstChildOfClass("Animation")
	if not (animator and walkAnim and runAnim) then return end

	local walkId = string.match(walkAnim.AnimationId, "%d+$")
	local runId = string.match(runAnim.AnimationId, "%d+$")

	-- Re-fetch tracks only when the animator changed or cache is stale
	if gaitCache.animator ~= animator or gaitCache.walkId ~= walkId or gaitCache.runId ~= runId
		or (gaitCache.walkTrack and not gaitCache.walkTrack.IsPlaying and gaitCache.runTrack and not gaitCache.runTrack.IsPlaying) then
		gaitCache.animator = animator
		gaitCache.walkId, gaitCache.runId = walkId, runId
		gaitCache.walkTrack, gaitCache.runTrack = nil, nil
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			local id = track.Animation and string.match(track.Animation.AnimationId, "%d+$")
			if id and id == walkId then gaitCache.walkTrack = track end
			if id and id == runId then gaitCache.runTrack = track end
		end
	end

	local height = 1
	if humanoid.AutomaticScalingEnabled and humanoid.HipHeight > 0.05 then
		local damp = animate:FindFirstChild("ScaleDampeningPercent")
		height = damp and (1 + (humanoid.HipHeight - 2) * damp.Value / 2) or humanoid.HipHeight / 2
	end
	local pace = speed / 16 * 1.25 / math.max(height, 0.1)
	local walkWeight, runWeight, rate = 0.0001, 0.0001, 1
	if pace <= 0.5 then
		walkWeight, rate = 1, pace / 0.5
	elseif pace < 1 then
		runWeight = (pace - 0.5) / 0.5
		walkWeight = 1 - runWeight
	else
		runWeight, rate = 1, pace
	end

	if gaitCache.walkTrack and gaitCache.walkTrack.IsPlaying then
		gaitCache.walkTrack:AdjustWeight(walkWeight)
		gaitCache.walkTrack:AdjustSpeed(rate)
	end
	if gaitCache.runTrack and gaitCache.runTrack.IsPlaying then
		gaitCache.runTrack:AdjustWeight(runWeight)
		gaitCache.runTrack:AdjustSpeed(rate)
	end
end
