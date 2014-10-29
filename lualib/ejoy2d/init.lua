local fw = require "window.c"
fw.init()
local skynet = require "skynet"
local shader = require "ejoy2d.shader"

if skynet.getenv("platform") == "android" then
	fw.WorkDir = [[/sdcard/shoucangjia/]]
elseif skynet.getenv("platform") == "linux" then
	fw.WorkDir = [[./]]
end
fw.AnimationFramePerFrame = 1

local ejoy2d = {}
ejoy2d.FRAME_TIME = 100/30

local touch = {
	"BEGIN",
	"END",
	"MOVE",
	"CANCEL"
}

local gesture = {
	"PAN",
	"TAP",
	"PINCH",
    "PRESS",
    "DOUBLE_TAP",
}

local timeout_id = 0
local remove_timeout = {}

function ejoy2d.timeout(interval,func)
	timeout_id = timeout_id + 1
	local id = timeout_id

	local function update()
		if remove_timeout[id] then
			remove_timeout[id] = nil
			return
		end
		if func() then
			return
		end
		skynet.timeout(interval,update)
	end

	skynet.timeout(interval,update)
	return id
end

function ejoy2d.remove_timeout(id)
	if id and id <= timeout_id then
		remove_timeout[id] = true
	end
end

local table_list,table_pattern = {},[[./asset/table/?.lua]]

function ejoy2d.load_table(...)
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

function ejoy2d.start(callback)
	fw.EJOY2D_DRAWFRAME = assert(callback.drawframe)

	fw.EJOY2D_TOUCH = function(x,y,what,id)
		return callback.touch(touch[what],x,y,id)
	end
    fw.EJOY2D_GESTURE = function(what, x1, y1, x2, y2, state)
		return callback.gesture(gesture[what], x1, y1, x2, y2, state)
	end
	fw.EJOY2D_MESSAGE = assert(callback.message)
  	fw.EJOY2D_HANDLE_ERROR = assert(callback.handle_error)
  	fw.EJOY2D_RESUME = assert(callback.on_resume)
	fw.EJOY2D_PAUSE = assert(callback.on_pause)
	fw.EJOY2D_WIN_INIT = function()
		shader.init()
		print("shader init")
		callback.screen_init()
	end
	fw.inject()
	fw.win_init()

	ejoy2d.timeout(ejoy2d.FRAME_TIME,fw.event_handle)
	ejoy2d.timeout(ejoy2d.FRAME_TIME,fw.update_frame)
end

function ejoy2d.clear(color)
	return shader.clear(color)
end

return ejoy2d
