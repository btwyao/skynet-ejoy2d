local ej = require "ejoy2d"
local skynet = require "skynet"

local view_meta = {ui_type = "view"}

function view_meta.__index(v, key)
	return view_meta[key]
end

function view_meta:is_ui_type(v)
	if not self.ui_type then return false end

	local meta = self
	while meta do
		if meta.ui_type == v then
			return true
		end
		meta = debug.getmetatable(meta)
	end

	return false
end

function view_meta:insert(v,...)
	local element = {_value = v}
	if v:is_ui_type("view") then element._type = "view" else element._type = "sprite" end

	if self._order == "assign" then
		element.pos = ...
		local add = false

		for i,v in ipairs(self) do
			if v.pos > ... then
				table.insert(self,math.max(i-1,1),element)
				add = true
				break
			end
		end

		if add == false then table.insert(self,element) end
	elseif self._order == "scene" then
		assert(v:is_ui_type("sprite"))
		local anchor_name
		anchor_name,element.gx,element.gy,element.area_len,element.area_width = ...
		if element.area_len <1 then element.area_len = 1 end
		if element.area_width <1 then element.area_width = 1 end
		local anchor = element._value:fetch(anchor_name)
		anchor.visible = true
		element._anchor = anchor_name

		for i = 1,element.area_len do
			for j = 1,element.area_width do
				self.grid_set[element.gy-i+1][element.gx-j+1].obj[element] = true
			end
		end

		self[v:sprite_ptr()] = element
		table.insert(self,element)
	else
		table.insert(self,element)
	end

	return element
end

function view_meta:update(v,...)
	if self._order == "assign" then
		local pos = ...
		local old_idx,new_idx

		for i,element in ipairs(self) do
			if old_idx and new_idx then break end
			if element._value == v then old_idx = i end
			if element.pos > pos then
				new_idx = math.max(i-1,1)
			end
		end

		if new_idx > old_idx then new_idx = new_idx-1 end
		element = table.remove(self,old_idx)
		element.pos = pos
		table.insert(self,new_idx,element)
	elseif self._order == "scene" then
		local gx,gy = ...
		local element = self[v:sprite_ptr()]

		for i = 1,element.area_len do
			for j = 1,element.area_width do
				self.grid_set[element.gy-i+1][element.gx-j+1].obj[element] = nil
			end
		end

		for i = 1,element.area_len do
			for j = 1,element.area_width do
				self.grid_set[gy-i+1][gx-j+1].obj[element] = true
			end
		end

		element.gx,element.gy = gx,gy
	end
end

function view_meta:remove(v)
	for i,element in ipairs(self) do
		if element._value == v then
			table.remove(self,i)
			break
		end
	end

	if self._order == "scene" then
		local element = self[v:sprite_ptr()]
		self[v:sprite_ptr()] = nil

		for i = 1,element.area_len do
			for j = 1,element.area_width do
				self.grid_set[element.gy-i+1][element.gx-j+1].obj[element] = nil
			end
		end
	end
end

function view_meta:aabb(srt)
	local minx,miny,maxx,maxy
	for _,v in ipairs(self) do
		local x1,y1,x2,y2 = v._value:aabb(srt)
		if x1 and x1~=x2 and y1~=y2 then
			if not minx or x1 < minx then minx = x1 end
			if not miny or y1 < miny then miny = y1 end
			if not maxx or x2 > maxx then maxx = x2 end
			if not maxy or y2 > maxy then maxy = y2 end
		end
	end
	return minx,miny,maxx,maxy
end

local view = {}
local cur_view_id = 0
local GRID_LEN = 75*1.414/2
local GRID_NUMX = (18+12+8)*2
local GRID_NUMY = (12+6+9)*2


function view.new(order,service)
	local v ={_id = cur_view_id, _order = order or "none", _service = service}
	v.grid_set = {}
	if order == "scene" then
		for i = 1,GRID_NUMY do
			v.grid_set[i] = {}
			for j = 1,GRID_NUMX do
				v.grid_set[i][j] = {checked = false,obj = {}}
			end
		end
	end

	cur_view_id = cur_view_id + 1

	return debug.setmetatable(v, view_meta)
end

return view
