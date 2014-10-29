local skynet = require "skynet"

local ejoy2dx = {}
local command = {}
ejoy2dx.NORET = {}
ejoy2dx.FRAME_TIME = 100/30

skynet.dispatch("lua", function(session, address, cmd , ...)
	local f = command[cmd]
	if f then
		local ret = f(...)
		if ret ~= ejoy2dx.NORET then
			skynet.ret(skynet.pack(ret))
		end
	else
		skynet.ret(skynet.pack {"Unknown command"} )
	end
end)

function ejoy2dx.register_command(name,func)
	command[name] = func
end

function ejoy2dx.win_send(...)
	return skynet.send("WINDOW","lua",...)
end

function ejoy2dx.win_call(...)
	return skynet.call("WINDOW","lua",...)
end

function ejoy2dx.send(service,...)
	return skynet.send(service,"lua",...)
end

function ejoy2dx.call(service,...)
	return skynet.call(service,"lua",...)
end

local update_func = {}

function ejoy2dx.register_update_func(func)
	table.insert(update_func,func)
end

local package_pattern
if skynet.getenv("platform") == "android" then
	package_pattern = [[/sdcard/shoucangjia/asset/interface/?]]
elseif skynet.getenv("platform") == "linux" then
	package_pattern = [[./asset/interface/?]]
end

function ejoy2dx.package_name(filename)
	return string.gsub(package_pattern,"([^?]*)?([^?]*)","%1"..filename.."%2")
end

local window_width,window_height

function ejoy2dx.screen_size()
	if not window_width then
		window_width,window_height = ejoy2dx.win_call("screen_size")
	end

	return window_width,window_height
end

local window_scale

function ejoy2dx.screen_scale()
	if not window_scale then
		window_scale = ejoy2dx.win_call("screen_scale")
	end

	return window_scale
end

local timeout_id = 0
local remove_timeout = {}

function ejoy2dx.timeout(interval,func)
	timeout_id = timeout_id + 1
	local id,logic_time,real_time = timeout_id,skynet.now()

	local function update()
		if remove_timeout[id] then
			remove_timeout[id] = nil
			return
		end
		real_time = skynet.now()

		while logic_time < real_time do
			if func() then return end
			logic_time = logic_time + interval
		end

		skynet.timeout(interval,update)
	end

	skynet.timeout(interval,update)
	return id
end

function ejoy2dx.remove_timeout(id)
	if id and id <= timeout_id then
		remove_timeout[id] = true
	end
end

local service_view = nil

function ejoy2dx.service_view(v,pos)
	if service_view then error("Already exit service view") end
	if v._view then error("Element already in view") end
	local str,id = v:view_flag()
	ejoy2dx.win_send("view_insert",0,str,id,pos)
	v._view = 0
	service_view = v
end

function command.service_touch_disabled(disabled)
	if not service_view then return end
	service_view:touch_disabled(disabled)
	return ejoy2dx.NORET
end

local table_list,table_pattern = {}
if skynet.getenv("platform") == "android" then
	table_pattern = [[/sdcard/shoucangjia/asset/table/?.lua]]
elseif skynet.getenv("platform") == "linux" then
	table_pattern = [[./asset/table/?.lua]]
end

function ejoy2dx.load_table(...)
	local keys = {...}
	local filename = keys[1]
	local tbl = table_list[filename]
	if not tbl then
		tbl = dofile(string.gsub(table_pattern,"([^?]*)?([^?]*)","%1"..filename.."%2"))
		table_list[filename] = tbl
	end

	for i = 2,#keys do
		if not tbl then error("No such table") end
		tbl = tbl[keys[i]]
	end

	return tbl
end

function ejoy2dx.package_name(filename)
	return string.gsub(package_pattern,"([^?]*)?([^?]*)","%1"..filename.."%2")
end

function ejoy2dx.start(func)
    skynet.start(function()
		skynet.call(skynet.exit_monitor(), "lua", "EJOY2DX", skynet.self())

		func()

		ejoy2dx.timeout(ejoy2dx.FRAME_TIME,function()
			for _,f in ipairs(update_func) do f() end
		end)
	end)
end

return ejoy2dx
