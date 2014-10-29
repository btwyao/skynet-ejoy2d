local ej = require "ejoy2dx"
local skynet = require "skynet"

local view_meta = {}
local view_list = {}
debug.setmetatable(view_list,{__mode = "v"})

function view_meta.__index(v, key)
	return view_meta[key]
end

function view_meta.__gc(v)
	ej.win_send("delete_view",v._id)
end

function view_meta:view_flag()
	return "set",self._id
end

function view_meta:insert(v,...)
	if v._view then
		if v._view ~= self._id then
			error("Insert view failed:element already in view")
		else
			self:remove(v)
		end
	end
	local str,id = v:view_flag()
	ej.win_send("view_insert",self._id,str,id,...)
	v._view = self._id
	self._elements[v] = true
end

function view_meta:update(v,...)
	if v._view ~= self._id then error("Update view failed:element not in view") end
	local str,id = v:view_flag()
	ej.win_send("view_update",self._id,str,id,...)
end

function view_meta:remove(v)
	if not self._elements[v] then return end
	local str,id = v:view_flag()
	ej.win_send("view_remove",self._id,str,id)
	v._view = nil
	self._elements[v] = nil
end

function view_meta:clear()
	for k,v in pairs(self._elements) do
		self:remove(k)
	end
end

function view_meta:contain(v)
	return self._elements[v]
end

function view_meta:aabb()
	return ej.win_call("view_aabb",self._id)
end

function view_meta:register_touch_handle(kind,func)
	for k,v in pairs(self._elements) do
		k.message = true
		k:register_touch_handle(kind,func)
	end
end

function view_meta:release_touch_handle(kind,func)
	for k,v in pairs(self._elements) do
		k:release_touch_handle(kind,func)
	end
end

function view_meta:elements()
	local ret = {}
	for k,v in pairs(self._elements) do
		table.insert(ret,k)
	end
	return ret
end

function view_meta:get_element(name)
	return self._elements_byName[name]
end

function view_meta:touch_disabled(disabled)
	ej.win_call("view_touch_disabled",self._id,disabled)
end

function view_meta:touch_locked(locked)
	ej.win_call("view_touch_locked",self._id,locked)
end

function view_meta:type()
	return "view"
end

-- ui interface
function view_meta:matrixBy(mat)
	for k,v in pairs(self._elements) do
		k:matrixBy(mat)
	end
--	ej.win_call("view_matrixBy",self._id,mat)
end

-- ui interface
function view_meta:psBy(...)
	for k,v in pairs(self._elements) do
		k:psBy(...)
	end
--	ej.win_call("view_psBy",self._id,...)
end

function view_meta:view_srt(srt)
	ej.win_send("view_srt",self._id,srt)
end

local view = {meta = view_meta}

function view.new(tbl)
	local id = ej.win_call("new_view",tbl.order)
	local v ={_id = id}
	v._elements,v._elements_byName = {},{}
	view_list[id] = v

	return debug.setmetatable(v, view_meta)
end

function view.new_meta()
	local meta = {
		__index = view_meta.__index,
		__gc = view_meta.__gc,
	}
	return meta
end

function view.get(id)
	return view_list[id]
end

return view
