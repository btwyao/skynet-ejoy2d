local ej = require "ejoy2d"
local fw = require "window.c"
local pack = require "ejoy2d.simplepackage"
local matrix = require "ejoy2d.matrix"
local sprite_c = require "ejoy2d.sprite.c"
local matrix_c = require "ejoy2d.matrix.c"
local skynet = require "skynet"
local particle = require "ejoy2d.particle"
local view = require "ejoy2d.view"

local game = {}
local command = {}
local NORET = {}
local sprite_list = {}
local touch_list = {}
local cover_list = {}
local particle_list = {}
local cur_service = nil
local cur_session = nil

local def_width,def_height = 1280,720
local screencoord = {}

function command.screen_size()
	return fw.window_width(),fw.window_height()
end

function command.screen_scale()
	return screencoord.scale or 1
end

function command.load_package(tbl)
	pack.load(tbl)
end

function command.new_sprite(packname,name,mat)
	local spr = ej.sprite(packname,name)
	if mat then
		mat = matrix(mat)
		spr.matrix = mat
	end
	local spr_ptr = spr:sprite_ptr()
	if not sprite_list[cur_service] then sprite_list[cur_service] = {} end
	sprite_list[cur_service][spr_ptr] = spr
	return spr_ptr
end

function command.delete_sprite(spr_ptr)
	if touch_list[cur_service] then touch_list[cur_service][spr_ptr] = nil end
	if cover_list[spr_ptr] then
		sprite_c.del_cover(cover_list[spr_ptr]._cover)
		ej.remove_timeout(cover_list[spr_ptr].timer_id)
		cover_list[spr_ptr] = nil
	end
	if particle_list[spr_ptr] then
		ej.remove_timeout(particle_list[spr_ptr].running_id)
		particle_list[spr_ptr] = nil
	end
	sprite_list[cur_service][spr_ptr] = nil
	return NORET
end

function command.sprite_ps(spr_ptr,...)
	sprite_list[cur_service][spr_ptr]:ps(...)

	return NORET
end

function command.sprite_sr(spr_ptr,...)
	sprite_list[cur_service][spr_ptr]:sr(...)

	return NORET
end

function command.sprite_fetch(spr_ptr,name)
	local child = sprite_list[cur_service][spr_ptr]:fetch(name)
	if child then
		local child_ptr = child:sprite_ptr()
		sprite_list[cur_service][child_ptr] = child
		return child_ptr
	end
end

function command.sprite_children(spr_ptr)
	local spr = sprite_list[cur_service][spr_ptr]
	local ret = spr:children()
	for index,child in ipairs(ret) do
		local child_ptr = child:sprite_ptr()
		local name = child.name
		sprite_list[cur_service][child_ptr] = child
		ret[index] = {name,child_ptr}
	end
	return ret
end

function command.sprite_mount(spr_ptr,name,child_ptr)
	local child
	if child_ptr then child = sprite_list[cur_service][child_ptr] end
	sprite_list[cur_service][spr_ptr]:mount(name,child)
end

function command.sprite_detach(spr_ptr,child_ptr)
	local child = sprite_list[cur_service][child_ptr]
	sprite_list[cur_service][spr_ptr]:detach(child)
end

function command.sprite_aabb(spr_ptr)
	return sprite_list[cur_service][spr_ptr]:aabb{}
end

function command.sprite_trans(spr_ptr1,spr_ptr2)
	local spr1 = sprite_list[cur_service][spr_ptr1]
	local spr2 = sprite_list[cur_service][spr_ptr2]
	spr1:trans_pos(spr2)

	return NORET
end

function command.sprite_worldPos(spr_ptr)
	return sprite_list[cur_service][spr_ptr]:world_pos()
end

function command.sprite_matrixBy(spr_ptr,mat)
	local spr = sprite_list[cur_service][spr_ptr]
--	spr.matrix = matrix(mat)
	matrix_c.mul(spr.matrix,matrix(mat))

	return NORET
end

function command.sprite_psBy(spr_ptr,...)
	local spr = sprite_list[cur_service][spr_ptr]

	local srt,mat = {...},{}
	if #srt == 1 then
		mat.scale = srt[1]
	elseif #srt == 2 then
		mat.x,mat.y = srt[1],srt[2]
	else
		mat.x,mat.y,mat.scale = srt[1],srt[2],srt[3]
	end

	matrix_c.mul(spr.matrix,matrix(mat))

--	local srt = {...}
--	if #srt == 1 then
--		matrix_c.scale(spr.matrix,srt[1])
--	elseif #srt == 2 then
--		matrix_c.trans(spr.matrix,srt[1],srt[2])
--	else
--		matrix_c.scale(spr.matrix,srt[3])
--		matrix_c.trans(spr.matrix,srt[1],srt[2])
--	end

	return NORET
end

function command.sprite_getter(spr_ptr,key)
	if key == "matrix" then
		local mat = sprite_list[cur_service][spr_ptr][key]
		return table.pack(matrix(mat):export())
	end

	return sprite_list[cur_service][spr_ptr][key]
end

function command.sprite_setter(spr_ptr,key,v)
	if key ~= "touch_count" then
		sprite_list[cur_service][spr_ptr][key] = v
		return NORET
	end

	if not touch_list[cur_service] then touch_list[cur_service] = {} end
	if not touch_list[cur_service][spr_ptr] then touch_list[cur_service][spr_ptr] = {} end
	touch_list[cur_service][spr_ptr][key] = v

	return NORET
end

function command.new_cover(spr_ptr,tbl)
	local spr = sprite_list[cur_service][spr_ptr]
	local cache_tex = ej.dynamic_tex()
	ej.dynamic_tex(tbl._dynamic_tex)
	spr:dynamic_tex(table.unpack(tbl._dynamic_tex))
	tbl._service,tbl.radius,tbl.good_list,tbl.choose_goods = cur_service,tbl._init_radius,{},{}
	tbl._cover = sprite_c.cover(tbl._widthGrid,tbl._heightGrid,tbl._grid_pixels,cache_tex)
	tbl._spr = spr
	cover_list[spr_ptr] = tbl
end

local function cover_enter(spr_ptr)
	local tbl = cover_list[spr_ptr]
	if tbl.disabled or tbl.vol <= 0 then return end
	local spr,config = tbl._spr,{{10,3},{50,1},{60,0},{70,-1},{9999,-3}}
	tbl.radius = tbl._init_radius
	tbl.lx,tbl.ly = tbl.x,tbl.y
	tbl.vol = sprite_c.cover_erase(spr,tbl._cover,tbl.vol,tbl.radius,tbl.x,tbl.y)

	local function update()
		if tbl.disabled or tbl.vol <= 0 or not tbl.x or not tbl.y then
			tbl.timer_id = nil
			return true
		end

		local dx,dy = math.abs(tbl.x-tbl.lx),math.abs(tbl.y-tbl.ly)
		for _,v in ipairs(config) do
			if dx < v[1] and dy < v[1] then
				tbl.radius = tbl.radius + v[2]*tbl._expand_radius
				break
			end
		end

		if tbl.radius > tbl._max_radius then tbl.radius = tbl._max_radius end
		if tbl.radius < tbl._init_radius then tbl.radius = tbl._init_radius end

		tbl.vol = sprite_c.cover_erase(spr,tbl._cover,tbl.vol,tbl.radius,tbl.lx,tbl.ly,tbl.x,tbl.y)
		tbl.lx,tbl.ly = tbl.x,tbl.y

		skynet.send(tbl._service,"lua","cover_curVol",spr_ptr,tbl.vol)
	end

	if tbl.timer_id then
		ej.remove_timeout(tbl.timer_id)
	end
	tbl.timer_id = ej.timeout(10,update)
end

local function cover_leave(spr_ptr)
	local tbl = cover_list[spr_ptr]
	tbl.lx,tbl.ly,tbl.x,tbl.y = nil,nil,nil,nil
	if tbl.timer_id then
		ej.remove_timeout(tbl.timer_id)
		tbl.timer_id = nil
	end
	for k,v in pairs(tbl.good_list) do
		if not tbl.choose_goods[k] and sprite_c.cover_checkGood(v) then
			command.cover_rmGood(spr_ptr,k)
			tbl.choose_goods[k] = true
			skynet.send(tbl._service,"lua","cover_discoveredGood",spr_ptr,k)
		end
	end
end

function command.cover_vol(spr_ptr,vol)
	local tbl = cover_list[spr_ptr]
	if tbl.vol < 0 then tbl.vol = 0 end
	tbl.vol = tbl.vol + vol
end

function command.cover_disabled(spr_ptr,disabled)
	local tbl = cover_list[spr_ptr]
	tbl.disabled = disabled
end

function command.cover_addGood(spr_ptr,good_ptr,gx,gy,scale)
	local tbl = cover_list[spr_ptr]
	local good = sprite_list[cur_service][good_ptr]
	local cg = sprite_c.cover_addGood(tbl._cover,good,gx,gy,scale)
	tbl.good_list[good_ptr] = cg
end

function command.cover_rmGood(spr_ptr,good_ptr)
	local tbl = cover_list[spr_ptr]
	sprite_c.cover_rmGood(tbl._cover,tbl.good_list[good_ptr])
	tbl.good_list[good_ptr] = nil
end

function command.new_particle(name)
	local ps = particle.new(name)
	local spr = ps.group
	local spr_ptr = spr:sprite_ptr()
	if not sprite_list[cur_service] then sprite_list[cur_service] = {} end
	sprite_list[cur_service][spr_ptr] = spr
	particle_list[spr_ptr] = ps

	return spr_ptr
end

function command.particle_run(spr_ptr)
	local ps = particle_list[spr_ptr]
	if ps.running_id then ej.remove_timeout(ps.running_id) end

	ps.running_id = ej.timeout(ej.FRAME_TIME,function()
		ps:update(ej.FRAME_TIME/100)
		if not ps.is_active then
			ps.running_id = nil
			return true
		end
	end)

	return NORET
end

function command.particle_stop(spr_ptr)
	local ps = particle_list[spr_ptr]
	if ps.running_id then ej.remove_timeout(ps.running_id) end

	return NORET
end

local root_view = view.new("assign")
local view_list = {}

function command.new_view(order)
	if not view_list[cur_service] then view_list[cur_service] = {} end
	local v = view.new(order,cur_service)
	view_list[cur_service][v._id] = v

	return v._id
end

function command.delete_view(id)
	view_list[cur_service][id] = nil
	return NORET
end

function command.view_insert(parent_id,child_type,child_id,...)
	local parent,child

	if child_type == "spr" then
		child = sprite_list[cur_service][child_id]
	else
		child = view_list[cur_service][child_id]
	end

	if parent_id == 0 then
		parent = root_view
	else
		parent = view_list[cur_service][parent_id]
	end

	local element = parent:insert(child,...)
	element._service = cur_service

	return NORET
end

function command.view_update(parent_id,child_type,child_id,...)
	local parent,child

	if child_type == "spr" then
		child = sprite_list[cur_service][child_id]
	else
		child = view_list[cur_service][child_id]
	end

	if parent_id == 0 then parent = root_view else parent = view_list[cur_service][parent_id] end

	parent:update(child,...)

	return NORET
end

function command.view_remove(parent_id,child_type,child_id)
	local parent,child

	if child_type == "spr" then
		child = sprite_list[cur_service][child_id]
	else
		child = view_list[cur_service][child_id]
	end

	if parent_id == 0 then parent = root_view else parent = view_list[cur_service][parent_id] end

	parent:remove(child)

	return NORET
end

function command.view_touch_disabled(id,disabled)
	local view = view_list[cur_service][id]
	view.touch_disabled = disabled
end

function command.view_touch_locked(id,locked)
	local view = view_list[cur_service][id]
	view.touch_locked = locked
end

function command.view_aabb(id)
	local view = view_list[cur_service][id]
	return view:aabb{}
end

function command.view_srt(id,srt)
	local view = view_list[cur_service][id]
	view.srt = srt

	return NORET
end

local GRID_LEN = 75*1.414/2
local GRID_NUMX = (18+12+8)*2
local GRID_NUMY = (12+6+9)*2

--local sc_mat = matrix{}
--sc_mat:trans(-536.5,136.8)
--sc_mat:scale(1,2)
--sc_mat:rot(-45)
--print(sc_mat:export())
--sc_mat = matrix{}
--sc_mat:rot(45)
--sc_mat:scale(1,1/2)
--sc_mat:trans(536.5,-136.8)
--print(sc_mat:export())

local cur_check_flag = true

local function draw_scene_grid(view,gy,gx,srt)
	local grid = view.grid_set[gy][gx]
	if grid.checked == cur_check_flag then return end
	local has_element,min_pos,min_element = false,nil,nil
	for element,_ in pairs(grid.obj) do
		if element.draw_checked ~= cur_check_flag then
			has_element = true
			if element.gx == gx then
				if not element.x then
					local anchor = element._value:fetch(element._anchor)
					element.x,element.y = anchor:world_pos()
				end
				if not min_pos or element.y < min_pos then
					min_pos = element.y
					min_element = element
				end
			end
		end
	end
	if min_element then
		min_element.draw_checked = cur_check_flag
		min_element._value:draw(srt)
		min_element.x,min_element.y = nil
		return min_element.gy-min_element.area_len+1,min_element.gx-min_element.area_width+1
	elseif has_element then
		return true
	end

	grid.checked = cur_check_flag
end

local function draw_scene(view,gy,gx,srt)
	local min_y = gy
	local x,y
	for x = gx,GRID_NUMX do
		if x == gx+1 then min_y = 1 end
		for y = min_y,GRID_NUMY do
			local gy2,gx2 = draw_scene_grid(view,y,x,srt)
			if gy2 and gx2 then
				return draw_scene(view,gy2,gx2,srt)
			elseif gy2 then
				break
			end
		end
	end
end

local function draw(view,srt)
	if view._order == "scene" then
		draw_scene(view,1,1,srt)
		cur_check_flag = not cur_check_flag
		return
	end

	local scissor = 0
	for _,v in ipairs(view) do
		if v._type == "view" then
			draw(v._value,v._value.srt or srt)
		else
			v._value:draw(srt)
			if v._value.type == 5 and v._value.scissor then scissor = scissor + 1 end
		end
	end
	if scissor > 0 then
		sprite_c.scissor_pop(scissor)
	end
end

function game.drawframe()
	ej.clear(0xff808080)	-- clear (0.5,0.5,0.5,1) gray
	draw(root_view,screencoord)
end

function command.touch_reg(spr_ptr,kind)
	if not touch_list[cur_service] then touch_list[cur_service] = {} end
	if not touch_list[cur_service][spr_ptr] then touch_list[cur_service][spr_ptr] = {} end
	touch_list[cur_service][spr_ptr][kind] = true
end

function command.touch_del(spr_ptr,kind)
	if not touch_list[cur_service] or not touch_list[cur_service][spr_ptr] then return end
	touch_list[cur_service][spr_ptr][kind] = nil
end

local touch = nil

local function touch2(x,y,view,srt,max,min)
	local touched_ptr,service
	for i = max, min, -1 do
		local v = view[i]
		if v._type == "view" and not v._value.touch_disabled then
			touched_ptr,service = touch(x,y,v._value,v._value.srt or srt)
		elseif v._type == "sprite" and v._value.message then
			local touched = v._value:test(x,y,srt)
			if touched then
				touched_ptr = touched:sprite_ptr()
				service = v._service
				local tbl = cover_list[touched_ptr]
				if tbl then
					local x0,y0,_,_ = touched:aabb(srt)
					tbl.x = x-x0
					tbl.y = y-y0
				end
			end
		end
		if touched_ptr or (v._type == "view" and v._value.touch_locked) then return touched_ptr,service end
	end
end

touch = function(x,y,view,srt)
	local touched_ptr,service
	local start = #(view)
	for i = start, 1, -1 do
		local v = view[i]
		if v._type == "sprite" and v._value.type == 5 and v._value.scissor then
			local touched = v._value:test(x,y,srt)
			if touched then
				touched_ptr,service = touch2(x,y,view,srt,start,i)
				if touched_ptr or view.touch_locked then return touched_ptr,service end
			end
			start = i - 1
		end
	end
	if start > 0 then return touch2(x,y,view,srt,start,1) end
end

local touched_info = nil

function game.touch(what,x,y,id)
	if touched_info and not sprite_list[touched_info._service][touched_info._spr_ptr] then
		touched_info = nil
	end

	local data = {}
	if touched_info then
		if touch_list[touched_info._service] then data = touch_list[touched_info._service][touched_info._spr_ptr] or data end
	end

	if what == "BEGIN" then
		if data.touch_count and touched_info.count >= data.touch_count then return end
		local spr_ptr,service = touch(x,y,root_view,screencoord)
		if (not spr_ptr) or (touched_info and spr_ptr ~= touched_info._spr_ptr) then
			return
		end
		if not touched_info then
			touched_info = {_spr_ptr = spr_ptr, _service = service, count = 1}
			if touch_list[touched_info._service] then data = touch_list[touched_info._service][touched_info._spr_ptr] or data end
		else
			touched_info.count = touched_info.count + 1
		end
		touched_info[id] = {x,y}
		if data["press"] then
			skynet.send(service,"lua","touch_event",spr_ptr,"press")
		end
		if data["begin"] then
			skynet.send(service,"lua","touch_event",spr_ptr,"begin",x,y)
		end
		if data["choose"] then
			touched_info[id].choose_timer = ej.timeout(50,function()
				touched_info[id].choose_timer = nil
				skynet.send(service,"lua","touch_event",spr_ptr,"choose",x,y)
				return true
			end)
		end
		if data["sclick"] or data["lclick"] then
			touched_info[id].start_time = skynet.now()
		end

		if cover_list[spr_ptr] then
			cover_enter(spr_ptr)
		end
	elseif what == "MOVE" and touched_info and touched_info[id] then
		if math.abs(x-touched_info[id][1]) > 10 or math.abs(y-touched_info[id][2]) > 10 then
			touched_info[id].moved = true
			if data["choose"] and touched_info[id].choose_timer then
				ej.remove_timeout(touched_info[id].choose_timer)
				touched_info[id].choose_timer = nil
			end
			if data["smove"] then
				if touched_info[id].smove_timer then ej.remove_timeout(touched_info[id].smove_timer) end
				touched_info[id].smove_x = x
				touched_info[id].smove_y = y
				touched_info[id].smove_timer = ej.timeout(50,function()
					touched_info[id].smove_timer = nil
					skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"smove",touched_info[id].smove_x,touched_info[id].smove_y)
					return true
				end)
			end
		end
		if data["shift"] then
			local pre_x,pre_y = touched_info[id][1],touched_info[id][2]
			skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"shift",x-pre_x,y-pre_y)
		end
		if data["move"] then
			skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"move",x,y)
		end
		if data["smove"] then
			touched_info[id].smove_x = x
			touched_info[id].smove_y = y
			if not touched_info[id].smove_timer then
				touched_info[id].smove_timer = ej.timeout(50,function()
					touched_info[id].smove_timer = nil
					skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"smove",touched_info[id].smove_x,touched_info[id].smove_y)
					return true
				end)
			end
		end
		if cover_list[touched_info._spr_ptr] then
			local spr_ptr,service = touch(x,y,root_view,screencoord)
			if spr_ptr ~= touched_info._spr_ptr then
				cover_leave(touched_info._spr_ptr)
				if cover_list[spr_ptr] then cover_enter(spr_ptr) end
			end
		end

		touched_info[id][1],touched_info[id][2] = x,y
	elseif (what == "END" or what == "CANCEL") and touched_info and touched_info[id] then
		local spr_ptr,service
		if data["release"] or data["cancel"] then
			spr_ptr,service = touch(x,y,root_view,screencoord)
		end
		if data["release"] and spr_ptr == touched_info._spr_ptr then
			skynet.send(service,"lua","touch_event",spr_ptr,"release")
		elseif data["cancel"] and spr_ptr ~= touched_info._spr_ptr then
			skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"cancel")
		end
		if data["end"] then
			skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"end",x,y)
		end
		if data["end_bt"] then
			local spr = sprite_list[touched_info._service][touched_info._spr_ptr]
			spr.message = false
			spr_ptr,service = touch(x,y,root_view,screencoord)
			spr.message = true
			skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"end_bt",spr_ptr)
		end
		if data["sclick"] then
			if not touched_info[id].moved and skynet.now() - touched_info[id].start_time < 50 then
				skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"sclick",x,y)
			end
		end
		if data["lclick"] then
			if not touched_info[id].moved and skynet.now() - touched_info[id].start_time > 50 then
				skynet.send(touched_info._service,"lua","touch_event",touched_info._spr_ptr,"lclick")
			end
		end
		if data["choose"] and touched_info[id].choose_timer then
			ej.remove_timeout(touched_info[id].choose_timer)
			touched_info[id].choose_timer = nil
		end
		if data["smove"] and touched_info[id].smove_timer then
			ej.remove_timeout(touched_info[id].smove_timer)
			touched_info[id].smove_timer = nil
		end

		if cover_list[touched_info._spr_ptr] then
			cover_leave(touched_info._spr_ptr)
		end

		if touched_info.count > 1 then
			touched_info.count = touched_info.count - 1
			touched_info[id] = nil
		else
			touched_info = nil
		end
	end
end

function command.service_exit(address)
	touch_list[address] = nil
	for i,v in ipairs(root_view) do
		if v._service == address then
			table.remove(root_view,i)
			break
		end
	end
	view_list[address] = nil
	sprite_list[address] = nil
	return NORET
end

function game.message(...)
end

function game.handle_error(...)
end

function game.on_resume()
end

function game.on_pause()
end

function game.screen_init()
	screencoord.scale = math.min(fw.window_width()/def_width,fw.window_height()/def_height)
	print("screen scale:",screencoord.scale)
end

skynet.dispatch("lua", function(session, address, cmd , ...)
	local f = command[cmd]
	if f then
		cur_service,cur_session = address,session
		local ret = {f(...)}
		cur_service,cur_session = nil
		if ret[1] ~= NORET then
			skynet.ret(skynet.pack(table.unpack(ret)))
		end
	else
		skynet.ret(skynet.pack {"Unknown command"} )
	end
end)

skynet.start(function()
	ej.start(game)
	skynet.register "WINDOW"
end)

