local skynet = require "skynet"
local ej = require "ejoy2dx"
local action = require "action"

local sprite_meta = {}
local SPRITE_RESERVED_PROP = {
	frame			= "rwc",
	matrix			= "r",
	visible			= "rwc",
	text			= "rwc",
	color			= "rwc",
	additive		= "rwc",
	message			= "rw",
	frame_count		= "rc",
	ani				= "w",
	program			= "w",
	scissor			= "w",
	world_matrix	= "",
	touch_count		= "w",
}

local sprite_list = {}
debug.setmetatable(sprite_list,{__mode = "v"})

local function create_sprite(spr_ptr,packname)
	local spr = sprite_list[spr_ptr]
	if spr then return spr end
	spr = {_spr_ptr = spr_ptr}
	spr._packname = packname
	spr._children = {}
	spr._touch_handle = {}
	sprite_list[spr_ptr] = spr

	return debug.setmetatable(spr, sprite_meta)
end

function sprite_meta:ps(...)
	ej.win_send("sprite_ps",self._spr_ptr,...)
end

function sprite_meta:sr(...)
	ej.win_send("sprite_sr",self._spr_ptr,...)
end

function sprite_meta:fetch(name)
	if self._children[name] then return self._children[name] end
	local child_ptr = ej.win_call("sprite_fetch",self._spr_ptr,name)
	if child_ptr then
		local child = create_sprite(child_ptr,self._packname)
		child._parent = self._spr_ptr
		child._name = name
		self._children[name] = child
		return child
	end
end

function sprite_meta:children()
	local children = ej.win_call("sprite_children",self._spr_ptr)
	for index,data in ipairs(children) do
		local name,child_ptr = table.unpack(data)
		local child = sprite_list[child_ptr]
		if not child then
			child = create_sprite(child_ptr,self._packname)
			child._parent = self._spr_ptr
		end
		if name then
			child._name = name
			self._children[name] = child
		end
		children[index] = child
	end

	return children
end

function sprite_meta:mount(name,child)
	local spr_ptr,old_child = nil,self._children[name]
	if child then spr_ptr = child._spr_ptr end
	ej.win_call("sprite_mount",self._spr_ptr,name,spr_ptr)
	if old_child then
		old_child._parent = nil
		old_child._name = nil
	end
	if child then
		child._name = name
	end
	self._children[name] = child
end

function sprite_meta:detach(child)
	if type(child) == "string" then child = self:fetch(child) end
	assert(child._parent == self._spr_ptr)
	ej.win_call("sprite_detach",self._spr_ptr,child._spr_ptr)
	child._parent = nil
	if child._name then
		self._children[child._name] = nil
		child._name = nil
	end
	return child
end

local ani_sprite_list = {}

ej.register_update_func(function()
	local end_func_list = {}

	for spr_ptr,_ in pairs(ani_sprite_list) do
		local spr = sprite_list[spr_ptr]
		if spr and spr._cur_ani then
			local ani = spr._cur_ani
			ani.step = ani.step + 1
			if ani.step > ani._freq then
				ani.step = ani.step - ani._freq
				spr.frame = spr.frame + ani._speed * ani._dir
				if ani._last_frame and ((ani._dir > 0 and spr.frame >= ani._last_frame) or (ani._dir < 0 and spr.frame <= ani._last_frame)) then
					ani_sprite_list[spr_ptr] = nil
					spr._cur_ani = nil
					if ani._end_func then table.insert(end_func_list,ani._end_func) end
				end
			end
		else
			ani_sprite_list[spr_ptr] = nil
		end
	end

	for _,end_func in ipairs(end_func_list) do
		end_func()
	end
end)

function sprite_meta:run_animation(tbl)
	end_func,speed,amount,reversed = tbl.end_func,tbl.speed,tbl.amount,tbl.reversed
	speed = speed or 1
	amount = amount or 1
	reversed = reversed or false
	if speed <= 0 then error("Invalid param:speed "..speed) end
	local start_frame,last_frame,direction = 0,nil,1

	start_frame = self.frame - math.fmod(self.frame,self.frame_count)

	if reversed then
		direction = -1
		self.frame = self.frame_count - 1
		start_frame = start_frame + self.frame_count - 1
	end
	if amount > 0 then
		last_frame = start_frame - direction + direction * self.frame_count * amount
		if (last_frame - self.frame) * direction <= 0 then
			if end_func then end_func() end
			return
		end
	end

	local ani = {_last_frame = last_frame, _dir = direction, _end_func = end_func, step = 0}
	if speed < 1 then
		ani._freq = 1/speed
		ani._speed = 1
	else
		ani._freq = 1
		ani._speed = speed
	end

	self._cur_ani = ani
	ani_sprite_list[self._spr_ptr] = true
end

function sprite_meta:stop_animation()
	ani_sprite_list[self._spr_ptr] = nil
	self._cur_ani = nil
end

local TOUCH_KIND = {
	press		= true,		--按下
	release		= true,		--在触摸物上松开
	cancel		= true,		--在触摸物外松开
	shift		= true,		--触摸时移动，带移动向量
	begin		= true,		--按下，带坐标
	move		= true,		--触摸时移动，带当前坐标
	["end"]		= true,		--松开，带坐标
	end_bt		= true,		--松开，同时返回松开处的可触摸物（除刚开始的触摸物）
	sclick		= true,		--短按，带坐标
	lclick		= true,		--长按
	choose		= true,		--点击触摸物，并持续超过0.5秒，带坐标
	smove		= true,		--移动中停留0.5秒以上,带当前坐标
}

ej.register_command("touch_event",function(spr_ptr,kind,...)
	local spr = sprite_list[spr_ptr]
	if not spr or not spr._touch_handle[kind] then return ej.NORET end
	for _,func in ipairs(spr._touch_handle[kind]) do
		func(spr,...)
	end
	return ej.NORET
end)

function sprite_meta:register_touch_handle(kind,func)
	if not TOUCH_KIND[kind] then error("Unsupport touch kind " .. kind) end
	if not self._touch_handle[kind] then
		self._touch_handle[kind] = {}
		ej.win_call("touch_reg",self._spr_ptr,kind)
	end
	table.insert(self._touch_handle[kind],func)
end

function sprite_meta:release_touch_handle(kind,func)
	local func_list = self._touch_handle[kind]
	if not func_list then return end
	if func then
		for i,v in ipairs(func_list) do
			if v == func then
				table.remove(func_list,i)
				break
			end
		end
	else
		func_list = {}
	end
	if #func_list == 0 then
		self._touch_handle[kind] = nil
		ej.win_call("touch_del",self._spr_ptr,kind)
	end
end

function sprite_meta:view_flag()
	return "spr",self._spr_ptr
end

function sprite_meta:aabb()
	return ej.win_call("sprite_aabb",self._spr_ptr)
end

function sprite_meta:sprite_trans(spr)
	ej.win_send("sprite_trans",self._spr_ptr,spr._spr_ptr)
end

function sprite_meta:world_pos()
	return ej.win_call("sprite_worldPos",self._spr_ptr)
end

-- ui interface
function sprite_meta:matrixBy(mat)
	ej.win_send("sprite_matrixBy",self._spr_ptr,mat)
end

-- ui interface
function sprite_meta:psBy(...)
	ej.win_send("sprite_psBy",self._spr_ptr,...)
end

local sprite_type ={	-- see in spritepack.h
	"PICTURE",
	"ANIMATION",
	"POLYGON",
	"LABEL",
	"PANEL",
	"ANCHOR",
}

function sprite_meta:sprite_type()
	if self._type then return self._type end
	local i = ej.win_call("sprite_getter",self._spr_ptr,"type")
	self._type = sprite_type[i]
	return self._type
end

function action.spr_opaqueBy(target,byValue,time)
	local act = action.linear(ej.FRAME_TIME)
	local cnt = math.ceil(time/ej.FRAME_TIME)
	local perValue = byValue/cnt
	local curValue = 0

	function act:total_cnt()
		return cnt
	end

	function act:step()
		curValue = curValue + perValue
		local int
		if curValue > 0 then int = math.floor(curValue) else int = math.ceil(curValue) end
		if int ~= 0 then
			target.color = target.color + int * 0x1000000
			curValue = curValue - int
		end

	end

	return act
end

function sprite_meta:_parse_text(txt)
	return txt
end

function sprite_meta:fresh_text()
	local txt = self._orig_text
	for k,v in pairs(self._text_tbl) do
		txt = string.gsub(txt,k,v)
	end
	txt = self:_parse_text(txt)
	self._text = txt

	ej.win_send("sprite_setter",self._spr_ptr,"text",txt)
end

local text_tbl = ej.load_table("text")

function sprite_meta:set_text(txt,tbl)
	tbl = tbl or {}
	if type(txt) == "number" then
		txt = text_tbl[txt]
		assert(txt)
	end
	self._orig_text = txt
	self._text_tbl = tbl

	return self:fresh_text()
end

function sprite_meta:set_textBy(k,v)
	self._text_tbl[k] = v
	self:fresh_text()
end

function action.text_integerBy(target,key,byValue,perValue,interval)
	local act = action.linear(interval or 100)

	function act:total_cnt()
		return byValue/perValue
	end

	function act:step()
		target:_set_textBy(key,target._text_tbl[key] + perValue)
	end

	return act
end

function sprite_meta:particle_run()
	ej.win_send("particle_run",self._spr_ptr)
end

function sprite_meta:particle_stop()
	ej.win_send("particle_stop",self._spr_ptr)
end

function action.spr_rotTo(target,time,fromVal,toVal)
	local act = action.linear(ej.FRAME_TIME)
	local cnt = math.ceil(time/ej.FRAME_TIME)
	if not toVal then
		toVal = fromVal
		fromVal = 0
	end

	local perVal,val = (toVal-fromVal)/cnt

	function act:total_cnt()
		val = fromVal
		return cnt
	end

	function act:step()
		val = val + perVal
		target:sr(val)
	end

	return act
end


function sprite_meta:type()
	return "sprite"
end

function sprite_meta.__index(spr, key)
	if sprite_meta[key] then return sprite_meta[key] end

	local rw = SPRITE_RESERVED_PROP[key]
	if rw and string.find(rw,"r") then
		if not string.find(rw,"c") then
			return ej.win_call("sprite_getter",spr._spr_ptr,key)
		end
		local real_key = "_"..key
		local cache = rawget(spr,real_key)
		if not cache then
			cache = ej.win_call("sprite_getter",spr._spr_ptr,key)
			rawset(spr,real_key,cache)
		end
		return cache
	elseif rw then
		print("Unsupport get " .. key)
	end
end

function sprite_meta.__newindex(spr, key, v)
	local rw = SPRITE_RESERVED_PROP[key]
	if rw and string.find(rw,"w") then
		if string.find(rw,"c") then spr["_"..key] = v end
		if key == "ani" then
			spr._frame = 0
			spr._frame_count = nil
			ej.win_send("sprite_setter",spr._spr_ptr,key,v)
		elseif key == "text" then
			spr:set_text(tostring(v or ""))
		else
			ej.win_send("sprite_setter",spr._spr_ptr,key,v)
		end
	elseif rw then
		print("Unsupport set " .. key)
	else
		rawset(spr,key,v)
	end
end

function sprite_meta.__gc(spr)
	ej.win_send("delete_sprite",spr._spr_ptr)
end

local sprite = {meta = sprite_meta}

function sprite.new(packname, name, mat)
	local spr_ptr = ej.win_call("new_sprite",packname,name,mat)
	return create_sprite(spr_ptr,packname)
end

function sprite.particle(name)
	local spr_ptr = ej.win_call("new_particle",name)
	return create_sprite(spr_ptr,"particle")
end

function sprite.new_meta()
	local meta = {
		__index = sprite_meta.__index,
		__newindex = sprite_meta.__newindex,
		__gc = sprite_meta.__gc,
	}
	return meta
end

function sprite.loadpack(tbl)
	ej.win_call("load_package",tbl)
end

function sprite.get(spr_ptr)
	return sprite_list[spr_ptr]
end

return sprite
