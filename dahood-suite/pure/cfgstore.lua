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
