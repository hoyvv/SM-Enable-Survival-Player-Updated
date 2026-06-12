if ds_loaded then
	return
end
ds_loaded = true

sm.dispatcher = sm.dispatcher or {}
sm.dispatcher.addons = sm.dispatcher.addons or {}

function sm.dispatcher:Register(name, instance)
	self.addons[name] = instance
end

function sm.dispatcher:Broadcast(eventName, ...)
	local args = { ... }
	for name, addon in pairs(self.addons) do
		if addon[eventName] and type(addon[eventName]) == "function" then
			local success, err = pcall(function()
				addon[eventName](addon, unpack(args))
			end)

			if not success then
				sm.log.error(("Error addon %s (event  %s): %s)"):format(name, eventName, tostring(err)))
			end
		end
	end
end
