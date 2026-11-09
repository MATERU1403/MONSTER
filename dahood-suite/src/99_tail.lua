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
