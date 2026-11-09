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
