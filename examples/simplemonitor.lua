local skynet = require "skynet"

-- It's a simple service exit monitor, you can do something more when a service exit.

local command = {}
local NORET = {}
local service_map = {}
local ejoy2dx_service = {}

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,	-- PTYPE_CLIENT = 3
	unpack = function() end,
	dispatch = function(_, address)
		if ejoy2dx_service[address] then
			skynet.send("WINDOW","lua","service_exit",address)
			ejoy2dx_service[address] = nil
		end
		local w = service_map[address]
		if w then
			for watcher in pairs(w) do
				skynet.redirect(watcher, address, "error", 0, "")
			end
			service_map[address] = false
		end
	end
}

function command.WATCH(watcher, service)
	local w = service_map[service]
	if not w then
		if w == false then
			return false
		end
		w = {}
		service_map[service] = w
	end
	w[watcher] = true
	return true
end

function command.EJOY2DX(service)
	ejoy2dx_service[service] = true
end

skynet.dispatch("lua", function(session, address, cmd , ...)
	cmd = string.upper(cmd)
	local f = command[cmd]
	if f then
		local ret
		if cmd == "WATCH" then
			ret = f(address,...)
		else
			ret = f(...)
		end
		if ret ~= NORET then
			skynet.ret(skynet.pack(ret))
		end
	else
		skynet.ret(skynet.pack {"Unknown command"} )
	end
end)

skynet.start(function() end)
