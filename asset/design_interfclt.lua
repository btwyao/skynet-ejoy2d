local skynet = require "skynet"
local ej = require "ejoy2dx"
local ui = require "ui"
local sprite = require "sprite"
local db = require "database"
local action = require "action"
local util = require "util"
local view = require "view"
local item = require "item"
local cskynet = require "skynet.core"

local service_view_pos = tonumber(...)

local root_view,sct_view
local insert_bag_items,fresh_bag_view_items

--scene网格原点:536.5,-136.8
local GRID_X0,GRID_Y0 = 536.5,-136.8
local PY_UI_MAT = {724,362,-724,362,536.5*16,-136.8*16}
local GRID_LEN = 75*1.414/2
local GRID_NUMX = (18+12+8)*2
local GRID_NUMY = (12+6+9)*2
local DEFAULT_AREA = 0
local GRID_SET = {}

for i = 1,GRID_NUMY do
	GRID_SET[i] = {}
	for j = 1,GRID_NUMX do
		GRID_SET[i][j] = {scope_monitor = {},occupy = {}}
	end
end

local hall_dx,hall_dy,hall_ds,hall_width,hall_height = 0,0,1,2560,1748

function ui_grid_pos(x,y)--{{{
	x,y = x - hall_dx,y - hall_dy
	x,y = x/hall_ds,y/hall_ds

	--用matrix误差较大，所以采用这种直接计算的方式
	x,y = x - 536.5,y + 136.8
	y = y * 2
	local px,py = x * 0.707 + y * 0.707, y * 0.707 - x * 0.707
	px,py = px/GRID_LEN,py/GRID_LEN

	return px,py
end
--}}}
function grid_int_pos(gx0,gy0,unit)--{{{
	unit = unit or 1
	local gx,gxf = math.modf(gx0/unit)
	if gxf >= 0.2 then
		gx = gx + 1
	end
	gx = gx * unit

	local gy,gyf = math.modf(gy0/unit)
	if gyf >= 0.2 then
		gy = gy + 1
	end
	gy = gy * unit

	return gx,gy
end
--}}}
function ui_gridI_pos(x,y,unit)--{{{
	local gx,gy = ui_grid_pos(x,y)
	return grid_int_pos(gx,gy,unit)
end
--}}}
function grid_ui_pos(gx,gy)--{{{
	local px,py = gx * GRID_LEN,gy * GRID_LEN
	local x = (px * PY_UI_MAT[1] + py * PY_UI_MAT[3]) / 1024 + PY_UI_MAT[5] / 16
	local y = (px * PY_UI_MAT[2] + py * PY_UI_MAT[4]) / 1024 + PY_UI_MAT[6] / 16
	x,y = x*hall_ds,y*hall_ds
	x,y = x + hall_dx,y + hall_dy

	return x,y
end
--}}}
function grid_ui_vect(gx,gy)--{{{
	local px,py = gx * GRID_LEN,gy * GRID_LEN
	local x = (px * PY_UI_MAT[1] + py * PY_UI_MAT[3]) / 1024
	local y = (px * PY_UI_MAT[2] + py * PY_UI_MAT[4]) / 1024
	x,y = x*hall_ds,y*hall_ds
	return x,y
end
--}}}

local scope_monitor_id,scope_monitor_info = 0,{}

function register_scope_monitor(gx0,gy0,gx1,gy1,func)--{{{
	scope_monitor_id = scope_monitor_id + 1
	scope_monitor_info[scope_monitor_id] = {gx0,gy0,gx1,gy1}
	for i = gy0,gy1 do
		for j = gx0,gx1 do
			GRID_SET[i][j].scope_monitor[scope_monitor_id] = func
			for _,obj in pairs(GRID_SET[i][j].occupy) do
				func("enter",obj)
			end
		end
	end

	return scope_monitor_id
end
--}}}
function release_scope_monitor(sm_id)--{{{
	if not scope_monitor_info[sm_id] then return end
	local gx0,gy0,gx1,gy1 = table.unpack(scope_monitor_info[sm_id])
	scope_monitor_info[sm_id] = nil
	for i = gy0,gy1 do
		for j = gx0,gx1 do
			GRID_SET[i][j].scope_monitor[sm_id] = nil
		end
	end
end
--}}}

local scene_view_meta = view.new_meta()

local scene_view_index = scene_view_meta.__index

function scene_view_meta.__index(sv,key)
	if scene_view_meta[key] then return scene_view_meta[key] end
	return scene_view_index(sv,key)
end

function scene_view_meta:check_occupy(gx0,gy0,gx1,gy1)--{{{
	if not gx1 then gx1,gy1 = gx0,gy0 end

	for i = gy0,gy1 do
		if not self.grid_set[i] then return false end
		for j = gx0,gx1 do
			if not self.grid_set[i][j] or self.grid_set[i][j].occupy[self] then
				return false
			end
		end
	end

	return true
end
--}}}
function scene_view_meta:insert_object(obj,gx,gy)--{{{
	for i = 1,obj._area_len do
		for j = 1,obj._area_width do
			self.grid_set[gy-i+1][gx-j+1].occupy[self] = obj
		end
	end

	for _,func in pairs(self.grid_set[gy][gx].scope_monitor) do
		func("enter",obj)
	end

	self:insert(obj,obj:anchor(),gx,gy,obj._area_len,obj._area_width)
end
--}}}
function scene_view_meta:update_object(obj,gx0,gy0,gx1,gy1)--{{{
	for i = 1,obj._area_len do
		for j = 1,obj._area_width do
			local tbl = self.grid_set[gy0-i+1][gx0-j+1]
			if tbl.occupy[self] ~= obj then
				print("Wrong gx gy for ",obj:type(),gx0,gy0,gx1,gy1)
--				error("Wrong gx gy for object")
			end
			tbl.occupy[self] = nil
		end
	end

	for i = 1,obj._area_len do
		for j = 1,obj._area_width do
			self.grid_set[gy1-i+1][gx1-j+1].occupy[self] = obj
		end
	end

	local pre_sm,last_sm = self.grid_set[gy0][gx0].scope_monitor,self.grid_set[gy1][gx1].scope_monitor
	for sm_id,func in pairs(pre_sm) do
		if not last_sm[sm_id] then func("leave",obj) end
	end
	for sm_id,func in pairs(last_sm) do
		if not pre_sm[sm_id] then func("enter",obj) end
	end

	self:update(obj,gx1,gy1)
end
--}}}
function scene_view_meta:remove_object(object,gx,gy)--{{{
	for i = 1,object._area_len do
		for j = 1,object._area_width do
			local tbl = self.grid_set[gy-i+1][gx-j+1]
			if tbl.occupy[self] ~= object then error("Wrong gx gy for object") end
			tbl.occupy[self] = nil
		end
	end

	for _,func in pairs(self.grid_set[gy][gx].scope_monitor) do
		func("leave",object)
	end

	self:remove(object)
end
--}}}
function ui.scene_view(tbl)--{{{
	local v = view.new(tbl)
	v.grid_set = GRID_SET
	debug.setmetatable(v,scene_view_meta)

	for index,etbl in ipairs(tbl) do
		etbl.packname = tbl.packname
		local object = ui.scene_obj(etbl)
		object:matrixBy(etbl.mat)

		local x,y = object.x,object.y
		local gx,gy = object:grid_pos(x,y,v)
--		print(etbl.name,object._area_width,object._area_len,gx,gy,x,y)
		object:enter_scene(v,gx,gy)

		if etbl.name then v._elements_byName[etbl.name] = object end
	end

	return v
end
--}}}
local scene_obj_meta = sprite.new_meta()--{{{--{{{

local scene_obj_index = scene_obj_meta.__index

function scene_obj_meta.__index(so,key)
	if scene_obj_meta[key] then return scene_obj_meta[key] end
	return scene_obj_index(so,key)
end

function scene_obj_meta:type()
	return "scene_obj"
end

local function update_grid_pos(obj)
	local gx0,gy0 = obj.gx,obj.gy
	local gx1,gy1 = ui_gridI_pos(obj.x,obj.y)
	local x,y = obj.x - hall_dx,obj.y - hall_dy
	obj.hall_x,obj.hall_y = x/hall_ds,y/hall_ds
	if gx1 ~= gx0 or gy1 ~= gy0 then
		obj.gx,obj.gy = gx1,gy1
		obj.scene:update_object(obj,gx0,gy0,gx1,gy1)
	end
end

function scene_obj_meta:matrixBy(mat)
	local x = (self.x * mat[1] + self.y * mat[3]) / 1024 + mat[5] / 16
	local y = (self.x * mat[2] + self.y * mat[4]) / 1024 + mat[6] / 16
	self.x,self.y = x,y

	return scene_obj_index(self,"matrixBy")(self,mat)
end

function scene_obj_meta:psBy(...)
	local tbl = {...}
	local gx,gy,x,y = self.gx,self.gy,self.x,self.y
	if #tbl == 2 then
		local dx,dy = tbl[1],tbl[2]
		self.x,self.y = self.x + dx,self.y + dy
		if self.scene then update_grid_pos(self) end
	elseif #tbl == 1 then
		local ds = tbl[1]

		if self.scene then
			self.x,self.y = self.hall_x*hall_ds+hall_dx,self.hall_y*hall_ds+hall_dy
			update_grid_pos(self)
		else
			self.x = cskynet.intdivide(self.x*16*1024*ds,1024)/16
			self.y = cskynet.intdivide(self.y*16*1024*ds,1024)/16
		end
		scene_obj_index(self,"psBy")(self,ds)
	end

	scene_obj_index(self,"ps")(self,self.x,self.y)
end

function scene_obj_meta:ps(...)
	local tbl = {...}
	if #tbl >1 then
		self.x,self.y = tbl[1],tbl[2]
		if self.scene then update_grid_pos(self) end
	end

	return scene_obj_index(self,"ps")(self,...)
end
--}}}
function scene_obj_meta:anchor()
	return "maodian"
end

function scene_obj_meta:enter_scene(sc,gx,gy)
	assert(self.scene == nil)
	self.scene,self.gx,self.gy = sc,gx,gy
	sc:insert_object(self,gx,gy)
	local x,y = self.x - hall_dx,self.y - hall_dy
	self.hall_x,self.hall_y = x/hall_ds,y/hall_ds

	util.event_handle(self.on_enter_scene,sc,gx,gy)
end

function scene_obj_meta:leave_scene()
	assert(self.scene)
	util.event_handle(self.on_leave_scene)

	self.scene:remove_object(self,self.gx,self.gy)
	self.scene,self.gx,self.gy = nil
end

function scene_obj_meta:grid_pos(x,y,sc,unit)--{{{
	local gx,gy = ui_gridI_pos(x,y,unit)

	if gx <= 0 or gx > GRID_NUMX or gx < self._area_width then return end
	if gy <= 0 or gy > GRID_NUMY or gy < self._area_len then return end

	if sc:check_occupy(gx-self._area_width+1,gy-self._area_len+1,gx,gy) then
		return gx,gy
	end
end
--}}}
function ui.scene_obj(tbl)
	local name = tbl.name
	local i,j = string.find(name,"#")
	if i then name = string.sub(name,1,i-1) end
	local spr = sprite.new(tbl.packname,name)
	local scene_tbl = ej.load_table("scene")
	local good_area = scene_tbl.goods_area[name]
	spr.x,spr.y = 0,0
	spr.on_enter_scene,spr.on_leave_scene = {n=0},{n=0}
	spr._area_len,spr._area_width = DEFAULT_AREA,DEFAULT_AREA
	if good_area then
		spr._area_len,spr._area_width = table.unpack(good_area)
	end

	return debug.setmetatable(spr,scene_obj_meta)
end
--}}}
local scene_npc_meta = sprite.new_meta()--{{{--{{{

local scene_npc_index = scene_obj_meta.__index

function scene_npc_meta.__index(so,key)
	if scene_npc_meta[key] then return scene_npc_meta[key] end
	if so.info[key] then return so.info[key] end
	return scene_npc_index(so,key)
end

function scene_npc_meta:type()
	return "scene_npc"
end

function scene_npc_meta:psBy(...)
	scene_npc_index(self,"psBy")(self,...)

	self.xuetiao:psBy(...)
end

function scene_npc_meta:ps(...)
	scene_npc_index(self,"ps")(self,...)

	local tbl = {...}
	if #tbl > 1 then
		tbl[1],tbl[2] = tbl[1] - 35*hall_ds,tbl[2] - 120*hall_ds
	end
	for _,element in ipairs(self.xuetiao:elements()) do
		element:ps(table.unpack(tbl))
	end
end

function scene_npc_meta:sj_anchor()
	return "SJmaodian"
end

function scene_npc_meta:leave_scene()
	self:stop_walk()
	return scene_npc_index(self,"leave_scene")(self)
end
--}}}

function scene_npc_meta:forbid_move()
	self._forbid_move.cnt,self._forbid_move.n = self._forbid_move.cnt + 1,self._forbid_move.n + 1
	self._forbid_move[self._forbid_move.n] = true
	return self._forbid_move.n
end

function scene_npc_meta:del_forbid_move(id)
	if not self._forbid_move[id] then return end
	self._forbid_move[id] = nil
	self._forbid_move.cnt = self._forbid_move.cnt - 1
end

local WALK_SPEED,RUN_SPEED = 0.05,0.1

function scene_npc_meta:single_walk(gx,gy,func)
	if not self.scene then return end
	if self.walk_timer then
		ej.remove_timeout(self.walk_timer)
		self.walk_timer = nil
	end
	if self.gx == gx and self.gy == gy then return func() end
	if gx > self.gx or gy < self.gy then
		self:sr(hall_ds,hall_ds)
	else
		self:sr(-hall_ds,hall_ds)
	end

	local gx0,gy0 = ui_grid_pos(self.x,self.y)
	local gx_dir,gy_dir
	if gx > gx0 then gx_dir = 1 else gx_dir = -1 end
	if gy > gy0 then gy_dir = 1 else gy_dir = -1 end

	self.walk_timer = ej.timeout(ej.FRAME_TIME,function()
		if self._forbid_move.cnt > 0 then
			if self.ani_state ~= "dongzuo" then
				self.ani_state = "dongzuo"
				self.ani = "dongzuo"
			end
			return
		elseif self.ani_state == "pre_fengpao" then
			self.frame = self.frame + 0.25
			if self.frame >= self.frame_count - 1 then
				self.ani_state = "fengpao"
				self.ani = "fengpao2"
			end
			return
		elseif self.speed == WALK_SPEED and self.ani_state ~= "xingzou" then
			self.ani_state = "xingzou"
			self.ani = "xingzou"
		elseif self.speed == RUN_SPEED and self.ani_state ~= "fengpao" then
			local ps = sprite.particle("yanwu")
			self:mount(self:anchor(),ps)
			ps:particle_run()
			if self.FPbiaoji then
				self.ani_state = "pre_fengpao"
				self.ani = "fengpao1"
				return
			else
				self.ani_state = "fengpao"
				self.ani = "fengpao"
			end
		end

		local frame_speed = math.max(0,0.25 * (1 + (self.buff_data["speed"] or 0) / self.speed))
		self.frame = self.frame + frame_speed

		local speed = math.max(0,self.speed + (self.buff_data.speed or 0))
		local dgx,dgy = gx_dir * speed,gy_dir * speed
		if (gx - gx0 - dgx) * gx_dir < 0 then
			dgx = gx - gx0
		end
		if (gy - gy0 - dgy) * gy_dir < 0 then
			dgy = gy - gy0
		end
		if dgx ~= 0 or dgy ~= 0 then
			gx0,gy0 = gx0 + dgx,gy0 + dgy
			local dx,dy = grid_ui_vect(dgx,dgy)
			self:ps(self.x+dx,self.y+dy)
		else
			self.walk_timer = nil
			func()
			return true
		end
	end)
end

function scene_npc_meta:walk(path,func)--{{{
	local i = #path
	if i == 0 then return func() end

	local gx,gy = path[i][1],path[i][2]

	self:single_walk(gx,gy,function()
		path[i] = nil
		self:walk(path,func)
	end)
end
--}}}
function scene_npc_meta:stop_walk()
	if self.walk_timer then
		ej.remove_timeout(self.walk_timer)
		self.walk_timer = nil
	end
	if self.ani_state ~= "dongzuo" then
		self.ani_state = "dongzuo"
		self.ani = "dongzuo"
	else
		self:stop_animation()
	end
end

function scene_npc_meta:random_walk(func)
	local dir_tbl = {1,0,-1,0,0,1,0,-1,}
	local function walk()
		if math.random(100) < 10 then
			self.ani_state = "dongzuo"
			self.ani = "dongzuo"
			ej.timeout(ej.FRAME_TIME,function()
				self.frame = self.frame + 0.25
				if self.frame >= self.frame_count - 1 then
					walk()
					return true
				end
			end)
--			self:run_animation{speed = 0.25,end_func = walk}
		else
			for i = 1,1000 do
				local v,m = math.random(4),math.random(5)
				local gx,gy = self.gx + dir_tbl[v*2-1]*m,self.gy + dir_tbl[v*2]*m
				local path = self:cal_path(gx,gy,func)
				if path then
					return self:walk(path,walk)
				end
			end

			error("random walk occur endless loop???")
		end
	end

	walk()
end

function scene_npc_meta:cal_path(gx0,gy0,gx1,gy1,func)--{{{
	if not gy1 then
		func,gy1,gx1 = gx1,gy0,gx0
		gx0,gy0 = self.gx,self.gy
	end

	local point = {parent = nil, G = 0, H = math.abs(gx1-gx0) + math.abs(gy1-gy0), gx = gx0, gy = gy0}
	point.F = point.G + point.H
	local point_list,open_list,close_list = {[gx0] = {[gy0] = point}},{},{}
	open_list[point] = true
	local dir_tbl,end_point = {1,0,-1,0,0,1,0,-1,}

	while true do
		local min_point,min,min_H

		for p,_ in pairs(open_list) do
			if p.gx == gx1 and p.gy == gy1 then
				end_point,min_point = p,nil
				break
			end
			if not min or min > p.F then
				min,min_H,min_point = p.F,p.H,p
			elseif min == p.F then
				if min_H > p.H then
					min_H,min_point = p.H,p
				elseif min_H == p.H and p.parent and p.parent.parent and p.gy-p.parent.gy==p.parent.gy-p.parent.parent.gy and p.gy-p.parent.gy==p.parent.gy-p.parent.parent.gy then
					min_point = p
				end
			end
		end

		if not min_point then break end
		open_list[min_point],close_list[min_point] = nil,true

		for v = 1,4 do
			i = dir_tbl[v*2-1]
			j = dir_tbl[v*2]
			local gx,gy = min_point.gx + i,min_point.gy + j
			if self.scene:check_occupy(gx,gy) and (not func or func(gx,gy)) then
				if not point_list[gx] then point_list[gx] = {} end
				if not point_list[gx][gy] then
					local point = {parent = min_point, G = min_point.G + 1, H = math.abs(gx1-gx) + math.abs(gy1-gy), gx = gx, gy = gy}
					point.F = point.G + point.H
					point_list[gx][gy] = point
				end
				local point = point_list[gx][gy]
				if not close_list[point] then
					if open_list[point] then
						if min_point.G + 1 < point.G then
							point.parent,point.G,point.F = min_point,min_point.G + 1,point.G + point.H
						end
					else
						open_list[point] = true
					end
				end
			end
		end
	end

	if not end_point then return end
	local path = {}
	while end_point.parent ~= nil do
		table.insert(path,{end_point.gx,end_point.gy})
		end_point = end_point.parent
	end

	return path
end
--}}}
function scene_npc_meta:add_haoping(youhuoli)--{{{
	self.haoping_max = 50
	if self.haoping >= self.haoping_max then return end

	self.haoping = self.haoping + youhuoli
--	print("haoping:"..self.haoping)
	self.xuetiao:set_percent(self.haoping/self.haoping_max)
	if self.haoping >= self.haoping_max then
		self.speed = RUN_SPEED
	end
end
--}}}
function scene_npc_meta:drop_item()--{{{
	local ratio,good = self.diaobaoJL/1000
	if self.haoping >= self.haoping_max then
		ratio = ratio * 10
	end
	if math.random() > ratio then return end

	if math.random(100) > 90 then
		if #self.carry_goods <= 2 then return end
		local num = math.random(3,#self.carry_goods)
		good = self.carry_goods[num]
		if good.idx == 1803 then
			local cnt = math.min(math.random(self.Jbdieluo),good:get_amount())
			good:add_amount(-cnt)
			if good:get_amount() < 1 then table.remove(self.carry_goods,num) end
			good = item.new(1803)
			good:set_amount(cnt)
		else
			table.remove(self.carry_goods,num)
		end
	else
		local idx = 1800 + math.random(2)
		if idx == 1801 then
			if self.carry_goods[1]:get_amount() < 1 then return end
			local cnt = math.min(math.random(self.Ybdieluo),self.carry_goods[1]:get_amount())
			self.carry_goods[1]:add_amount(-cnt)
			good = item.new(idx)
			good:set_amount(cnt)
		else
			if self.carry_goods[2]:get_amount() < 1 then return end
			local cnt = math.min(math.random(self.JYdieluo),self.carry_goods[2]:get_amount())
			self.carry_goods[2]:add_amount(-cnt)
			good = item.new(idx)
			good:set_amount(cnt)
		end
	end

	return good
end
--}}}
function ui.scene_npc(idx)
	local npc_tbl = ej.load_table("zhanting","base_NPC")
	local info = npc_tbl[idx]
	local npc = ui.scene_obj{packname = "npc", name = info.spritename1}

	local carry_goods,carry_tbl = {},ej.load_table("zhanting","diaobao_NPC")
	local silver_good = item.new(1801)
	silver_good:set_amount(math.random(info.YB_max))
	table.insert(carry_goods,silver_good)
	local exp_good = item.new(1802)
	exp_good:set_amount(math.random(info.JY_max))
	table.insert(carry_goods,exp_good)
	for i = 1,(info.xdw_max-2) do
		local good = item.new(util.random_tblR(carry_tbl[info.diaobaoLB]))
		if good.idx == 1803 then good:set_amount(math.random(info.JB_max)) end
		table.insert(carry_goods,good)
	end

	local pay_goods,pay_tbl = {},ej.load_table("zhanting","shouyaoXQ_NPC")
	for i = 1,info.shouyao1_max do
		local good = item.new(util.random_tblR(pay_tbl[info.shouyaoXQ]))
		good:set_amount(math.random(info.shouyao2_min,info.shouyao2_max))
		table.insert(pay_goods,good)
	end

	npc.speed,npc.haoping,npc.carry_goods,npc.pay_goods,npc.info = WALK_SPEED,0,carry_goods,pay_goods,info
	npc.buff_data,npc._forbid_move = {},{cnt=0,n=0}
	npc.xuetiao = ui.new("background","xuetiao")

	return debug.setmetatable(npc,scene_npc_meta)
end
--}}}

local scene_booth_meta = sprite.new_meta()--{{{

local scene_booth_index = scene_obj_meta.__index

function scene_booth_meta.__index(so,key)
	if scene_booth_meta[key] then return scene_booth_meta[key] end
	return scene_booth_index(so,key)
end

function scene_booth_meta:type()
	return "scene_booth"
end
--}}}
function scene_booth_meta:enter_scene(sc,gx,gy)
	scene_booth_index(self,"enter_scene")(self,sc,gx,gy)

	local gx0,gy0,gx1,gy1 = gx-self._area_width+1-self.item_data:get("zuoyongfw"),gy-self._area_len+1-self.item_data:get("zuoyongfw"),gx+self.item_data:get("zuoyongfw"),gy+self.item_data:get("zuoyongfw")
	if gx0 < 19*2-1 then gx0 = 19*2-1 end
	if gy0 < 4*2-1 then gy0 = 4*2-1 end
	if gx1 > 29*2 then gx1 = 29*2 end
	if gy1 > 14*2 then gy1 = 14*2 end
	self.sm_id = register_scope_monitor(gx0,gy0,gx1,gy1,function(event,obj)
		if event == "enter" then
			util.event_handle(self.on_enter_scope,obj)
		else
			util.event_handle(self.on_leave_scope,obj)
		end
	end)
end

function scene_booth_meta:leave_scene()
	release_scope_monitor(self.sm_id)
	self.sm_id = nil

	return scene_booth_index(self,"leave_scene")(self)
end
--}}}
function scene_booth_meta:start_attract()--{{{
	assert(self.scene)

	local bag_data,good_tbl = db.get("bag"),{}
	for _,bag_id in ipairs(self.item_data:get("container")) do
		local good = bag_data.items[bag_id]
		local idx = good:get("zhonglei") * 10 + good:get("quality")
		good_tbl[idx] = (good_tbl[idx] or 0) + 1
	end

	local inc_tbl,dec_tbl,eff_tbl = {[3] = 0.04, [4] = 0.08, [5] = 0.12},{[3] = 0.24, [4] = 0.18, [5] = 0.12},ej.load_table("zhanting","youhuo_effect")

	self.attract_data = {}
	self.attract_data[1] = util.event_register(self.on_enter_scope,function(obj)
		if obj:type() == "scene_npc" then self.attract_tbl[obj] = true end
	end)
	self.attract_data[2] = util.event_register(self.on_leave_scope,function(obj)
		if obj:type() == "scene_npc" then self.attract_tbl[obj] = nil end
	end)
	self.attract_data[3] = ej.timeout(100*100/self:get("sudu"),function()
		for npc,_ in pairs(self.attract_tbl) do
			local info_tbl = {youhuoli = self:get("youhuoli")}
			util.event_handle(self.on_attract_npc,npc,info_tbl)

			local youhuoli,inc_per,dec_per = info_tbl.youhuoli,0,0
			for _,idx in ipairs(npc.xihaoCP or {}) do
				if good_tbl[idx] then
					local quality = idx % 10
					inc_per = inc_per + inc_tbl[quality] * good_tbl[idx]
				end
			end
			for _,idx in ipairs(npc.yanwuCP or {}) do
				if good_tbl[idx] then
					local quality = idx % 10
					dec_per = dec_per + dec_tbl[quality] * good_tbl[idx]
				end
			end
			dec_per = math.min(dec_per,1)
			if info_tbl.resist_dec then dec_per = (1 - info_tbl.resist_dec) * dec_per end
			youhuoli = youhuoli * (1 + inc_per) * (1 - dec_per)

			local ps_name = "baiguang"
			for _,v in pairs(eff_tbl) do
				if youhuoli >= v.min and youhuoli <= v.max then
					ps_name = v.effectname
					break
				end
			end
			local bullet,x,y,speed = sprite.particle(ps_name),self.x,self.y,8
			local gx,gy = (x-hall_dx)/hall_ds,(y-hall_dy)/hall_ds
			local tx,ty = npc:fetch(npc:sj_anchor()):world_pos()
			tx,ty = (tx - npc.x)/hall_ds,(ty - npc.y)/hall_ds
			bullet:ps(x,y)
			sct_view:insert(bullet)
			bullet:particle_run()
			ej.timeout(ej.FRAME_TIME,function()
				if not self.scene or not npc.scene then
					bullet:particle_stop()
					sct_view:remove(bullet)
					return true
				end
				x,y = gx*hall_ds+hall_dx,gy*hall_ds+hall_dy
				local dx,dy = npc.x + tx*hall_ds - x,npc.y + ty*hall_ds - y
				local abs_dx,abs_dy = math.abs(dx),math.abs(dy)
				if abs_dx <= speed * 2 and abs_dy <= speed * 2 then
					bullet:particle_stop()
					sct_view:remove(bullet)
					npc:add_haoping(youhuoli)
					local drop_good = npc:drop_item()
					if drop_good then
						local item_obj = sprite.new("cangpin",drop_good:get("spritename"))
						item_obj:ps(1/3)
						local x0,y0,x1,y1 = item_obj:aabb()
--						local ps = sprite.particle("guangquan")
--						ps:ps(npc.x-(x1-x0),npc.y-(y1-y0))
--						sct_view:insert(ps)
--						ps:particle_run()
						local good_spr = sprite.new("common","translation")
						good_spr:ps(npc.x-(x1-x0)/2,npc.y-(y1-y0)/2)
						item_obj:ps((x0-x1)/2,(y0-y1)/2)
						good_spr:mount("maodian",item_obj)
						sct_view:insert(good_spr)

						local shake_act = action.sequence{
							action.loop(action.sequence{action.spr_rotTo(good_spr,10,6,-6),action.spr_rotTo(good_spr,10,-6,6)}),
						}
						good_spr:sr(6)
						shake_act:start()
						good_spr.message = true
						good_spr:register_touch_handle("release",function(touched)
							shake_act:stop()
--							ps:particle_stop()
--							sct_view:remove(ps)
							sct_view:remove(good_spr)
							insert_bag_items({drop_good})
							fresh_bag_view_items()
						end)
					end
					return true
				end
				local dir_x,dir_y = dx > 0 and 1 or -1,dy > 0 and 1 or -1
				if abs_dx > abs_dy then
					x,y = x + dir_x * speed,y + dir_y * speed * abs_dy / abs_dx
				else
					x,y = x + dir_x * speed * abs_dx / abs_dy,y + dir_y * speed
				end
				gx,gy = (x-hall_dx)/hall_ds,(y-hall_dy)/hall_ds
				bullet:ps(x,y)
			end)

		end
	end)
end

function scene_booth_meta:stop_attract()
	assert(self.attract_data)
	util.event_release(self.on_enter_scope,self.attract_data[1])
	util.event_release(self.on_leave_scope,self.attract_data[2])
	ej.remove_timeout(self.attract_data[3])
	self.attract_data = nil
end
--}}}
function scene_booth_meta:get(key)
	local prop1 = {fanrongdu = true, youhuoli = true, tansuoli = true, jingyingli = true, shenmeili = true, character = true}
	if prop1[key] then return self[key] + (self.buff_data[key] or 0) end

	local prop2 = {sudu = true, kongjian = true, zuoyongfw = true}
	if prop2[key] then return self.item_data:get(key) + (self.buff_data[key] or 0) end

	error("invalid key for scene booth:"..key)
end

function scene_booth_meta:add_good(good_spr)
	local good = good_spr.item_data
	if not self.item_data:add_good(good) then return end

	self.fanrongdu = self.fanrongdu + good:get("fanrongdu")
	self.youhuoli = self.youhuoli + good:get("youhuoli")
	self.tansuoli = self.tansuoli + good:get("tansuoli")
	self.jingyingli = self.jingyingli + good:get("jingyingli")
	self.shenmeili = self.shenmeili + good:get("shenmeili")

	for i = 1,self.kongjian do
		if not self.good_list[i] then
			self.good_list[i] = good_spr
			local anchor_name = "cpmaodian"
			if i ~= 1 then
				anchor_name = anchor_name..'#'..i
			end
			good_spr:ps(-75/4,-75/2)
			self:mount(anchor_name,good_spr)
			break
		end
	end

	return true
end

function scene_booth_meta:clear_good()
	for i = 1,self.kongjian do
		if self.good_list[i] then
			local good_spr = self.good_list[i]
			local good = good_spr.item_data
			self.item_data:remove_good(good)

			local anchor_name = "cpmaodian"
			if i ~= 1 then
				anchor_name = anchor_name..'#'..i
			end
			self:mount(anchor_name,nil)
		end
	end

	self.fanrongdu,self.youhuoli,self.tansuoli,self.jingyingli,self.shenmeili = 0,0,0,0,0
	self.good_list = {}
end

function scene_booth_meta:remove_good(good_spr)
	local good = good_spr.item_data
	if not self.item_data:remove_good(good) then return end

	self.fanrongdu = self.fanrongdu - good:get("fanrongdu")
	self.youhuoli = self.youhuoli - good:get("youhuoli")
	self.tansuoli = self.tansuoli - good:get("tansuoli")
	self.jingyingli = self.jingyingli - good:get("jingyingli")
	self.shenmeili = self.shenmeili - good:get("shenmeili")

	for i = 1,self.kongjian do
		if self.good_list[i] == good_spr then
			self.good_list[i] = nil
			local anchor_name = "cpmaodian"
			if i ~= 1 then
				anchor_name = anchor_name..'#'..i
			end
			self:mount(anchor_name,nil)
			break
		end
	end

	return true
end

function ui.scene_booth(tbl)
	local bag_data = db.get("bag")
	local booth = ui.scene_obj(tbl)

	local fanrongdu,youhuoli,tansuoli,jingyingli,shenmeili = 0,0,0,0,0
	for _,bag_id in ipairs(tbl.item_data:get("container")) do
		local good = bag_data.items[bag_id]
		fanrongdu = fanrongdu + good:get("fanrongdu")
		youhuoli = youhuoli + good:get("youhuoli")
		tansuoli = tansuoli + good:get("tansuoli")
		jingyingli = jingyingli + good:get("jingyingli")
		shenmeili = shenmeili + good:get("shenmeili")
	end

	booth.fanrongdu,booth.youhuoli,booth.tansuoli,booth.jingyingli,booth.shenmeili = fanrongdu,youhuoli,tansuoli,jingyingli,shenmeili
	booth.item_data,booth.attract_tbl,booth.buff_data,booth.good_list = tbl.item_data,{},{},{}
	booth.kongjian = tbl.item_data:get("kongjian")
	booth.on_enter_scope,booth.on_leave_scope,booth.on_attract_npc = {n=0},{n=0},{n=0}

	return debug.setmetatable(booth,scene_booth_meta)
end

local scene_carpet_meta = sprite.new_meta()--{{{

local scene_carpet_index = scene_obj_meta.__index

function scene_carpet_meta.__index(so,key)
	if scene_carpet_meta[key] then return scene_carpet_meta[key] end
	return scene_carpet_index(so,key)
end

function scene_carpet_meta:type()
	return "scene_carpet"
end
--}}}
function scene_carpet_meta:enter_scene(sc,gx,gy)
	scene_carpet_index(self,"enter_scene")(self,sc,gx,gy)

	local gx0,gy0,gx1,gy1 = gx-self._area_width+1,gy-self._area_len+1,gx,gy

	self.sm_id = {}
	local dec_speed = {}
	table.insert(self.sm_id,register_scope_monitor(gx0,gy0,gx1,gy1,function(event,obj)
		if obj:type() ~= "scene_npc" then return end
		if event == "enter" then
			dec_speed[obj] = obj.speed * self.item_data:get("jiansu") / 100
			obj.buff_data.speed = (obj.buff_data.speed or 0) - dec_speed[obj]
		else
			obj.buff_data.speed = (obj.buff_data.speed or 0) + dec_speed[obj]
			dec_speed[obj] = nil
		end
	end))
	for i = gx0,gx1 do
		for j = gy0,gy1 do
			table.insert(self.sm_id,register_scope_monitor(i,j,i,j,function(event,obj)
				if event == "enter" and obj:type() == "scene_npc" then
					obj:add_haoping(self.item_data:get("ditanHP"))
				end
			end))
		end
	end
end

function scene_carpet_meta:leave_scene()
	for _,sm_id in ipairs(self.sm_id) do
		release_scope_monitor(sm_id)
	end
	self.sm_id = nil

	return scene_carpet_index(self,"leave_scene")(self)
end

function ui.scene_carpet(tbl)
	local carpet = ui.scene_obj(tbl)
	carpet.item_data = tbl.item_data

	return debug.setmetatable(carpet,scene_carpet_meta)
end

function create_scene_item(good)
	if good:type() == "booth" then
		return ui.scene_booth{packname = "background", name = good:get("spritename"), item_data = good}
	elseif good:type() == "carpet" then
		return ui.scene_carpet{packname = "background", name = good:get("spritename"), item_data = good}
	end

	return ui.scene_obj{packname = "background", name = good:get("spritename")}
end

ej.start(function()
	sprite.loadpack{"background","cangpin","common","interface","npc","particle","zhanting"}

	-- base_goods,bag_data,bag_items_byIdx,insert_bag_items--{{{--{{{
	local base_goods = ej.load_table("tansuo","base_goods")
	local bag_data,bag_items_byIdx = db.get("bag"),{}
	for _,v in pairs(bag_data.items) do
		item.load(v)
		if not bag_items_byIdx[v.idx] then bag_items_byIdx[v.idx] = {} end
		table.insert(bag_items_byIdx[v.idx],v)
	end
--}}}
	insert_bag_items = function(tbl)--{{{
		for _,v in ipairs(tbl) do
			if not v:special() then
				local items = bag_items_byIdx[v.idx]
				if not items or not items[1] then
					bag_data.cur_id = bag_data.cur_id + 1
					v.bag_id = bag_data.cur_id
					bag_data.items[bag_data.cur_id] = v
					bag_items_byIdx[v.idx] = {v,}
				else
					items[1]:add_amount(v:get_amount())
				end
			else
				bag_data.cur_id = bag_data.cur_id + 1
				v.bag_id = bag_data.cur_id
				bag_data.items[bag_data.cur_id] = v
				if not bag_items_byIdx[v.idx] then bag_items_byIdx[v.idx] = {} end
				table.insert(bag_items_byIdx[v.idx],v)
			end
		end
	end
--}}}
	-- for test
	local test_item_tbl = {1006,1027,1006,1027,1006,1027,1006,1027,1601,1602,1603,1604,1609,1604,1609,1604,1609,}
	for k,v in ipairs(test_item_tbl) do
		local good = item.new(v)
		test_item_tbl[k] = good
	end
	insert_bag_items(test_item_tbl)
--}}}
	-- root_view--{{{
	root_view = ui.view{}
	ej.service_view(root_view,service_view_pos)

	-- hall_view,bg,bg_cover,bgc_view,sc_view,set_hall_mode--{{{
	local hall_view,hall_mode = ui.view{}
	local bg = sprite.new("background","background")
	local bg_cover = bg:fetch("zgc_baise")
	bg_cover.color = 0x00ffffff
	local scb_view = ui.scene_view{}
	local bgc_view = view.new{}
	local sc_view = ui.new("background","field_view")
	sct_view = view.new{}
	bg.message = true
	hall_view:view_srt{}

	for _,v in pairs(bag_data.items) do
		if v.scene_pos then
			local info,obj_gx,obj_gy = base_goods[v.idx],v.scene_pos[1],v.scene_pos[2]
			local item_obj = create_scene_item(v)
			local x,y = grid_ui_pos(obj_gx,obj_gy)
			item_obj:ps(x,y)
			item_obj:enter_scene(sc_view,obj_gx,obj_gy)
		end
	end

	bg:register_touch_handle("shift",function(touched,dx,dy)
			local width,height = ej.screen_size()
			local x,y = hall_dx+dx,hall_dy+dy
			if x>0 or x<width-hall_width*hall_ds then dx = 0 end
			if y>0 or y<height-hall_height*hall_ds then dy = 0 end

			if dx~=0 or dy~=0 then
				hall_dx,hall_dy = hall_dx + dx,hall_dy + dy
				hall_view:psBy(dx,dy)
			end
	end)

	local function set_hall_mode(mode)--{{{
		if mode == hall_mode then return end

		if hall_mode == "shift" then
		end

		if mode == "shift" then
		end

		hall_mode = mode
	end
--}}}
	hall_view:insert(bg)
	hall_view:insert(scb_view)
	hall_view:insert(bgc_view)
	hall_view:insert(sc_view)
	hall_view:insert(sct_view)
	root_view:insert(hall_view)

	local npc_idx,npc_tbl,visit_npc_amount = {},ej.load_table("zhanting","base_NPC"),0
	for idx,_ in pairs(npc_tbl) do
		table.insert(npc_idx,idx)
	end

	local function create_scene_npc(idx)--{{{
		if not idx then idx = npc_idx[math.random(#npc_idx)] end
		local info = npc_tbl[idx]

		local npc = ui.scene_npc(idx)
		local gx,gy = 1*2,9*2-math.random(0,1)
		local x,y = grid_ui_pos(gx,gy)
		npc:ps(x,y,hall_ds)
		npc:enter_scene(sc_view,gx,gy)

		local enter_stage,wait_stage,invite_stage,visit_stage,leave_stage

		enter_stage = function()--{{{
			npc.message = false
			gx,gy = 12*2+1,gy
			npc:walk(npc:cal_path(gx,gy,function(gx,gy)
				if gx > 0 and gx <= 12*2+1 and gy > 8*2 and gy <= 9*2 then return true end
			end),function()
				wait_stage()
			end)
		end
--}}}
		wait_stage = function()--{{{
			npc.message = true

			local npc_view = ui.new("zhanting","NPCinterface")
			npc_view:get_element("jianjie").text = info.introduction
			npc_view:get_element("shili").text = info.quality
			npc_view:get_element("haopingshangxian").text = info.haoping_max
			npc_view:get_element("xiaicangpin").text = info.XHmiaoshu
			npc_view:get_element("yanwucangpin").text = info.Ywmiaoshu
			local title = sprite.new("zhanting",info.spritename1)
			title:sprite_trans(npc_view:get_element("maodian"))
			npc_view:insert(title)
			local pic = sprite.new("npc",info.spritename1)
			pic:sprite_trans(npc_view:get_element("maodian2"))
			pic.ani = "dongzuo"
			npc_view:insert(pic)

			local carry_view = npc_view:get_element("xdw_list")
			for _,good in ipairs(npc.carry_goods) do
				local spr = sprite.new("zhanting","xiedaiwuJH")
				local pic = sprite.new("cangpin",base_goods[good.idx].spritename)
				pic:ps(0.5)
				spr:mount("maodian",pic)
				spr:fetch("shuliang").text = 'X' .. good:get_amount()
				carry_view:insert_item(spr)
			end

			local pay_view = npc_view:get_element("syxq_list")
			for _,good in ipairs(npc.pay_goods) do
				local spr = sprite.new("zhanting","syxqJH")
				local pic = sprite.new("cangpin",base_goods[good.idx].spritename)
				pic:ps(0.5)
				spr:mount("maodian",pic)
				spr:fetch("xqshuliang").text = 'X' .. good:get_amount()
				pay_view:insert_item(spr)
			end

			local close_bt = npc_view:get_element("guanbi2")
			close_bt.on_released = function()
				pic:stop_animation()
				root_view:remove(npc_view)
				npc.message = true
			end

			local invite_bt = npc_view:get_element("yaoqing")
			invite_bt.on_released = function()
				pic:stop_animation()
				root_view:remove(npc_view)
				npc:stop_walk()
				npc:release_touch_handle("release",click)
				invite_stage()
			end

			npc_view:touch_locked(true)
			root_view:insert(npc_view)
			root_view:remove(npc_view)
			local function click(touched)--{{{
				npc.message = false
				root_view:insert(npc_view)
				pic:run_animation{amount = -1,speed = 0.25}
			end--}}}
			npc:register_touch_handle("release",click)
			npc:random_walk(function(gx,gy)
				if gx > 12*2 and gx <= 17*2 and gy > 3*2 and gy <= 15*2 then return true end
			end)
		end
--}}}
		invite_stage = function()--{{{
			scb_view:touch_disabled(true)
			sc_view:touch_disabled(true)
			local x,y = grid_ui_pos(29*2,9*2)
			local jiantou = sprite.new("background","jiantou")
			jiantou:ps(x,y,hall_ds)
			bgc_view:insert(jiantou)
			jiantou:run_animation{amount = -1}

			local path_list,last_gx,last_gy,walk_over = {},18*2,9*2-1
			local act = action.loop(action.sequence{action.spr_opaqueBy(bg_cover,0x40,40),action.spr_opaqueBy(bg_cover,-0x40,40)})
			act:start()

			local function hall_click(touched,x,y)
				local gx,gy = ui_gridI_pos(x,y)
				local path = npc:cal_path(last_gx,last_gy,gx,gy,function(gx,gy)
					if gx > 18*2 and gx <= 29*2 and gy > 3*2 and gy <= 14*2 then return true end
				end)
				if not path then return end

				local function check_path(gx,gy)
					local overlap
					for _,path in ipairs(path_list) do
						for i = #path,1,-1 do
							if overlap then
								bgc_view:remove(path[i].spr)
								table.remove(path,i)
							elseif gx == path[i][1] and gy == path[i][2] then
								overlap = true
							end
						end
					end

					return overlap
				end

				for i = #path,1,-1 do
					local gx,gy = path[i][1],path[i][2]
					if check_path(gx,gy) then
						for j = i,#path do
							path[j] = nil
						end
					end
				end

				for i = #path,1,-1 do
					local gx,gy = path[i][1],path[i][2]
					local x,y = grid_ui_pos(gx,gy)
					local spr = sprite.new("background","zgc_lvse")
					spr:ps(x,y,hall_ds)
					bgc_view:insert(spr)
					path[i].spr = spr
				end

				last_gx,last_gy = gx,gy
				table.insert(path_list,path)
				if (gx == 29*2-1 or gx == 29*2) and (gy == 9*2-1 or gy == 9*2) then
					bg:release_touch_handle("sclick",hall_click)
					act:stop()
					bg_cover.color = 0x00ffffff
					bgc_view:clear()
					if walk_over then
						visit_stage(path_list)
					else
						walk_over = true
					end
				end
			end

			bg:register_touch_handle("sclick",hall_click)

			npc.message = false
			npc:walk(npc:cal_path(last_gx,last_gy,function(gx,gy)
				if gx > 12*2 and gx <= 18*2 and gy > 3*2 and gy <= 15*2 then return true end
			end),function()
				npc:stop_walk()
				if walk_over then
					visit_stage(path_list)
				else
					walk_over = true
				end
			end)
		end
--}}}
		visit_stage = function(path_list)--{{{
			local i,n = 1,#path_list
			npc.message = false
			npc:fetch(npc:sj_anchor()).visible = true
			sct_view:insert(npc.xuetiao)

			if visit_npc_amount < 1 then
				for _,sc_obj in ipairs(sc_view:elements()) do
					if sc_obj:type() == "scene_booth" then
						sc_obj:start_attract()
					end
				end
			end
			visit_npc_amount = visit_npc_amount + 1

			local function walk()
				npc:walk(path_list[i],function()
					if i < n then
						i = i + 1
						walk()
					elseif i == n then
						visit_npc_amount = visit_npc_amount - 1
						if visit_npc_amount < 1 then
							scb_view:touch_disabled(false)
							sc_view:touch_disabled(false)
							for _,sc_obj in ipairs(sc_view:elements()) do
								if sc_obj:type() == "scene_booth" then
									sc_obj:stop_attract()
								end
							end
						end
						npc:fetch(npc:sj_anchor()).visible = false
						sct_view:remove(npc.xuetiao)
						leave_stage()
					end
				end)
			end

			walk()
		end
--}}}
		leave_stage = function()--{{{
			npc.message = false
			npc:walk(npc:cal_path(36*2,9*2-math.random(0,1),function(gx,gy)
				if gx > 28*2 and gx <= 36*2 and gy > 8*2 and gy <= 9*2 then return true end
			end),function()
				npc:leave_scene()
				create_scene_npc()
			end)
		end
--}}}
		enter_stage()
	end
--}}}
	local npc_cnt = 0
	ej.timeout(300,function()
		npc_cnt = npc_cnt + 1
		if npc_cnt > 5 then return true end

		create_scene_npc()
	end)
--}}}
	-- main_view--{{{
	local main_view = ui.new("interface","interface")
	root_view:insert(main_view)

	local enlarge_bt,narrow_bt = main_view:get_element("fangda"),main_view:get_element("suoxiao")

	enlarge_bt.on_released = function(touched)
		if hall_ds > 2 then return end

		--与渲染那边的精度保持一致
--		hall_dx,hall_dy,hall_ds = math.ceil(hall_dx*5/4*16)/16,math.ceil(hall_dy*5/4*16)/16,math.floor(hall_ds*5/4*1024)/1024
		hall_dx = cskynet.intdivide(hall_dx*16*1024*5/4,1024)/16
		hall_dy = cskynet.intdivide(hall_dy*16*1024*5/4,1024)/16
		hall_ds = cskynet.intdivide(hall_ds*1024*1024*5/4,1024)/1024
		hall_view:psBy(5/4)
	end

	narrow_bt.on_released = function(touched)
		local width,height = ej.screen_size()
		if width-hall_ds*3/4*hall_width > 0 or height-hall_ds*3/4*hall_height > 0 then return end

		--与渲染那边的精度保持一致
--		hall_dx,hall_dy,hall_ds = math.ceil(hall_dx*3/4*16)/16,math.ceil(hall_dy*3/4*16)/16,math.floor(hall_ds*3/4*1024)/1024
		hall_dx = cskynet.intdivide(hall_dx*16*1024*3/4,1024)/16
		hall_dy = cskynet.intdivide(hall_dy*16*1024*3/4,1024)/16
		hall_ds = cskynet.intdivide(hall_ds*1024*1024*3/4,1024)/1024
		hall_view:psBy(3/4)

		local dx,dy = 0,0
		if hall_dx<width-hall_ds*hall_width then dx = width-hall_ds*hall_width-hall_dx end
		if hall_dy<height-hall_ds*hall_height then dy = height-hall_ds*hall_height-hall_dy end

		if dx~=0 or dy~=0 then
			hall_dx,hall_dy = hall_dx + dx,hall_dy + dy
			hall_view:psBy(dx,dy)
		end
	end

	-- bag_bt,bag_view,bag_status,bag_tab--{{{
	local bag_bt,bag_status,bag_tab_tbl,bag_tab = main_view:get_element("Shounaxiang"),"closed",ej.load_table("tansuo","bag_tab"),1

	local bag_view = ui.new("zhanting","SNXinterface")
	root_view:insert(bag_view)
	main_view:remove(bag_bt)
	root_view:insert(bag_bt)

	local x1,_,x2,_ = bag_bt:aabb()
	local x3,_,x4,_ = bag_view:aabb()
	local bag_bt_width,bag_view_width,bag_item_cache = x2-x1,x4-x3,{}

	fresh_bag_view_items = function()--{{{
		bag_view:clear_item()

		for name,idx in pairs(bag_tab_tbl) do
			local tab_bt = bag_view:get_element(name)
			if idx ~= bag_tab then
				tab_bt.frame = 0
			else
				tab_bt.frame = 1
			end
		end

		local function create_item(good)--{{{
			if bag_item_cache[good] then return bag_item_cache[good] end

			local info,special = base_goods[good.idx],good:special()
			local name = "CPgeshi2"
			if special then name = "CPgeshi1" end
			if info.zhonglei == 7 then name = "CPgeshi3" end
			local item_spr = sprite.new("zhanting",name)
			local pic_spr = sprite.new("cangpin",info.spritename)
			pic_spr:ps(0.5)
			item_spr:mount("CPmaodian",pic_spr)
			item_spr:fetch("CPmingcheng").text = good:get('name')
			if special then
				if good:type() == "exhibit" then
					local val = good:cal_value()
					item_spr:fetch("CPjiazhi").text = val
				end
				item_spr:register_touch_handle("sclick",function(touched)
					if good:type() == "exhibit" then--{{{
						local val = good:cal_value()
						local able_text = ""
						for _,char in ipairs(good:get("character")) do
							able_text = able_text .. char:get("miaoshu") .. "\n"
							able_text = string.gsub(able_text,"#shuxing",char:get("shuxing"))
						end
						local item_view = ui.new("zhanting","cangpininterface")
						item_view:get_element("jianjie").text = info.introduce
						item_view:get_element("jiazhi").text = val
						item_view:get_element("texing").text = able_text
						item_view:get_element("fanrongdu").text = good:get("fanrongdu")
						item_view:get_element("youhuoli").text = good:get("youhuoli")
						item_view:get_element("tansuonengli").text = good:get("tansuoli")
						item_view:get_element("jingyingnengli").text = good:get("jingyingli")
						item_view:get_element("shenmeinengli").text = good:get("shenmeili")
						item_view:get_element("guanbi").on_released = function() root_view:remove(item_view) end
						local pic_spr = sprite.new("cangpin",info.spritename)
						pic_spr:sprite_trans(item_view:get_element("maodian"))
						item_view:insert(pic_spr)
						item_view:touch_locked(true)
						root_view:insert(item_view)--}}}
					elseif good:type() == "booth" then--{{{
						local fanrongdu,youhuoli,able_list,good_list,kongjian = 0,0,{},{},good:get("kongjian")
						for _,bag_id in ipairs(good:get("container")) do
							kongjian = kongjian - 1
							local good = bag_data.items[bag_id]
							fanrongdu = fanrongdu + good:get("fanrongdu")
							youhuoli = youhuoli + good:get("youhuoli")
							local spr = sprite.new("zhanting","ztzg_kongjiane")
							local pic = sprite.new("cangpin",good:get("spritename"))
							pic:ps(0.5)
							spr:mount("maodian",pic)
							table.insert(good_list,spr)
							for _,char in ipairs(good:get("character")) do
								local able = sprite.new("zhanting","ztzg_texingt")
								able:fetch("texing"):set_text(char:get("miaoshu"),{["#shuxing"] = char:get("shuxing")})
								table.insert(able_list,able)
							end
						end

						for i = 1,kongjian do
							local spr = sprite.new("zhanting","ztzg_kongjiane")
							table.insert(good_list,spr)
						end

						local item_view = ui.new("zhanting","ZTZGinterface")
						item_view:get_element("mingcheng").text = good:get("name")
						item_view:get_element("fanrongdu").text = fanrongdu
						item_view:get_element("youhuoli").text = youhuoli
						item_view:get_element("youhuosudu").text = good:get("sudu")
						item_view:get_element("zuoyongfanwei").text = good:get("zuoyongfw")
						item_view:get_element("guanbi1").on_released = function() root_view:remove(item_view) end
						for _,able in ipairs(able_list) do
							item_view:get_element("ztzg_texing"):insert_item(able)
						end
						for _,good in ipairs(good_list) do
							item_view:get_element("ztzg_kongjian"):insert_item(good)
						end
						item_view:touch_locked(true)
						root_view:insert(item_view)
					end--}}}
				end)
			else
				item_spr:fetch("CPgeshu").text = "X"..good:get_amount()
			end

			local function exhibit_obj_config()--{{{
				local item_obj
				item_spr.touch_count = 1
				item_spr.message = true

				item_spr:register_touch_handle("choose",function(touched,x,y)--{{{
					if visit_npc_amount > 0 then  return end
					item_obj = sprite.new("cangpin",good:get("spritename"))
					item_obj.item_data = good
					item_obj:ps(x-75/4,y-75/4,1/4)
					root_view:insert(item_obj)
					bag_view:scroll_disable(true)
				end)--}}}
				item_spr:register_touch_handle("move",function(touched,x,y)--{{{
					if not item_obj then return end
					item_obj:ps(x-75/4,y-75/4)
				end)--}}}
				item_spr:register_touch_handle("end_bt",function(touched,spr_ptr)--{{{
					if not item_obj or visit_npc_amount > 0 then return end
					root_view:remove(item_obj)
					bag_view:scroll_disable(false)
					local booth = sprite.get(spr_ptr)
					if not booth or booth:type() ~= "scene_booth" then return end
					booth:add_good(item_obj)
					fresh_bag_view_items()
				end)--}}}
			end
--}}}
			local function scene_obj_config()--{{{
				local item_obj,sc,last_gx,last_gy
				if good:type() == "carpet" then sc = scb_view else sc = sc_view end
				item_spr.touch_count = 1
				item_spr.message = true

				item_spr:register_touch_handle("choose",function(touched,x,y)--{{{
					if visit_npc_amount > 0 then  return end
					item_obj = create_scene_item(good)
					item_obj:ps(x,y,hall_ds)
					root_view:insert(item_obj)
					bag_view:scroll_disable(true)
				end)--}}}

				local function touch_move(touched,x,y)--{{{
					if not item_obj then return end
					item_obj:ps(x,y)
					local obj_gx,obj_gy = item_obj:grid_pos(x,y,sc,2)
					if obj_gx and obj_gx > 18*2 and obj_gx <= 29*2 and obj_gy > 3*2 and obj_gy <= 14*2 then
						item_obj.additive = 0
					else
						item_obj.additive = 0xff0000
					end
				end

				local function touch_smove(touched,x,y)
					if not item_obj then return end
					local obj_gx,obj_gy = item_obj:grid_pos(x,y,sc,2)
					if obj_gx and obj_gx > 18*2 and obj_gx <= 29*2 and obj_gy > 3*2 and obj_gy <= 14*2 then
						item_obj.additive = 0
						x,y = grid_ui_pos(obj_gx,obj_gy)
						item_obj:ps(x,y)
					end
				end
--}}}
				item_spr:register_touch_handle("move",touch_move)
				item_spr:register_touch_handle("smove",touch_smove)
				item_spr:register_touch_handle("end",function(touched,x,y)--{{{
					if not item_obj or visit_npc_amount > 0 then return end
					root_view:remove(item_obj)
					bag_view:scroll_disable(false)
					local obj_gx,obj_gy = item_obj:grid_pos(x,y,sc,2)
					if obj_gx and obj_gx > 18*2 and obj_gx <= 29*2 and obj_gy > 3*2 and obj_gy <= 14*2 then
						item_obj.additive = 0
						last_gx,last_gy = obj_gx,obj_gy
						good.scene_pos = {obj_gx,obj_gy}
						fresh_bag_view_items()
						x,y = grid_ui_pos(obj_gx,obj_gy)
						item_obj:ps(x,y)
						item_obj:enter_scene(sc,obj_gx,obj_gy)
						item_obj.message = true

						local function open_booth_view(item_obj)--{{{
							local able_list,good_list,kongjian_list = {},{},{}
							for i = 1,item_obj.kongjian do
								local good_spr = item_obj.good_list[i]
								if good_spr then
									local good = good_spr.item_data
									local spr = sprite.new("zhanting","ztzg_kongjiane")
									local pic = sprite.new("cangpin",good:get("spritename"))
									pic:ps(0.5)
									spr:mount("maodian",pic)
									spr.good_spr = good_spr
									table.insert(good_list,spr)
									table.insert(kongjian_list,spr)
									for _,char in ipairs(good:get("character")) do
										local able = sprite.new("zhanting","ztzg_texingt")
										able:fetch("texing"):set_text(char:get("miaoshu"),{["#shuxing"] = char:get("shuxing")})
										table.insert(able_list,able)
									end
								else
									local spr = sprite.new("zhanting","ztzg_kongjiane")
									table.insert(kongjian_list,spr)
								end
							end

							local item_view = ui.new("zhanting","ZTZGinterface")
							local kongjian_view = item_view:get_element("ztzg_kongjian")
							item_view:get_element("mingcheng").text = good:get("name")
							item_view:get_element("fanrongdu").text = item_obj:get("fanrongdu")
							item_view:get_element("youhuoli").text = item_obj:get("youhuoli")
							item_view:get_element("youhuosudu").text = item_obj:get("sudu")
							item_view:get_element("zuoyongfanwei").text = item_obj:get("zuoyongfw")
							item_view:get_element("guanbi1").on_released = function() root_view:remove(item_view) end
							for _,able in ipairs(able_list) do
								item_view:get_element("ztzg_texing"):insert_item(able)
							end

							for _,spr in ipairs(kongjian_list) do
								kongjian_view:insert_item(spr)
							end


							for _,item_spr in ipairs(good_list) do

								local good_spr,good,good_obj = item_spr.good_spr,item_spr.good_spr.item_data
								item_spr.touch_count = 1
								item_spr.message = true

								item_spr:register_touch_handle("choose",function(touched,x,y)--{{{
									good_obj = sprite.new("cangpin",good:get("spritename"))
									good_obj.item_data = good
									good_obj:ps(x-75/4,y-75/4,1/4)
									root_view:insert(good_obj)
									kongjian_view:scroll_disable(true)
								end)--}}}
								item_spr:register_touch_handle("move",function(touched,x,y)--{{{
									if not good_obj then return end
									good_obj:ps(x-75/4,y-75/4)
								end)--}}}
								item_spr:register_touch_handle("end",function(touched,x,y)--{{{
									if not good_obj then return end

									root_view:remove(good_obj)
									if bag_view:in_panel(x,y) then
										item_obj:remove_good(good_spr)
										fresh_bag_view_items()
										root_view:remove(item_view)
										open_booth_view(item_obj)
									end

									kongjian_view:scroll_disable(false)
									good_obj = nil
								end)--}}}
							end
							item_view:touch_locked(true)
							root_view:insert(item_view)
						end
--}}}
						local function choose_obj(touched,x,y)
							item_obj = touched
							item_obj:leave_scene()
							root_view:insert(item_obj)
							item_obj:ps(x,y)
						end

						local function touch_end(touched,x,y)
							if not item_obj then return end

							root_view:remove(item_obj)
							if bag_view:in_panel(x,y) then
								good.scene_pos = nil
								if item_obj:type() == "scene_booth" then
									item_obj:clear_good()
								end
								fresh_bag_view_items()
							else
								local obj_gx,obj_gy = item_obj:grid_pos(x,y,sc,2)
								if obj_gx and obj_gx > 18*2 and obj_gx <= 29*2 and obj_gy > 3*2 and obj_gy <= 14*2 then
									last_gx,last_gy = obj_gx,obj_gy
								end
								x,y = grid_ui_pos(last_gx,last_gy)
								item_obj:ps(x,y)
								item_obj:enter_scene(sc,obj_gx,obj_gy)
								item_obj.additive = 0
							end

							item_obj = nil
						end

						if item_obj:type() == "scene_booth" then
							item_obj:register_touch_handle("sclick",open_booth_view)
						end
						item_obj:register_touch_handle("choose",choose_obj)
						item_obj:register_touch_handle("move",touch_move)
						item_obj:register_touch_handle("smove",touch_smove)
						item_obj:register_touch_handle("end",touch_end)
					end
					item_obj = nil
				end)--}}}
			end
--}}}
			if special and good:type() == "exhibit" then
				exhibit_obj_config()
			elseif info.zhonglei == 7 then
				scene_obj_config()
			end

			bag_item_cache[good] = item_spr
			return item_spr
		end
--}}}
		for k,v in pairs(bag_items_byIdx) do
			local info = base_goods[k]
			if info.zhonglei == bag_tab then
				for _,good in ipairs(v) do
					if not good.scene_pos and not good.in_booth then
						bag_view:insert_item(create_item(good))
					end
				end
			end
		end
	end
--}}}
	-- bag tab button init--{{{
	for name,idx in pairs(bag_tab_tbl) do
		local tab_bt = bag_view:get_element(name)
		tab_bt.on_released = function()
			bag_tab = idx
			fresh_bag_view_items()
		end
	end
--}}}
	bag_bt.on_released = function(touched)--{{{
		local function open_bag_view()--{{{
			if bag_status == "opened" then return end

			bag_status = "opened"
			bag_bt:set_disabled(true)

			local act1 = action.sequence{action.ui_psBy(bag_view,{bag_bt_width,0},10),action.instant(function()
				local act2 = action.sequence{action.ui_psBy(bag_view,{bag_view_width-bag_bt_width,0},20),action.instant(function()
					bag_bt:set_disabled(false)
				end)}
				local act3 = action.ui_psBy(bag_bt,{bag_view_width-bag_bt_width,0},20)
				act2:start()
				act3:start()
			end)}
			act1:start()
		end
--}}}
		local function close_bag_view()--{{{
			if bag_status == "closed" then return end

			bag_status = "closed"
			bag_bt:set_disabled(true)

			local act1 = action.sequence{action.ui_psBy(bag_view,{bag_bt_width-bag_view_width,0},10),action.instant(function()
				local act2 = action.sequence{action.ui_psBy(bag_view,{-bag_bt_width,0},10),action.instant(function()
					bag_bt:set_disabled(false)
				end)}
				act2:start()
			end)}
			local act3 = action.ui_psBy(bag_bt,{bag_bt_width-bag_view_width,0},20)
			act1:start()
			act3:start()
		end
--}}}
		if bag_status == "closed" then
			open_bag_view()
		else
			close_bag_view()
		end
	end
--}}}
	fresh_bag_view_items()
--}}}
	local explore_bt,explore_service = main_view:get_element("Tansuo"),skynet.newservice("design_explore","2")--{{{
	skynet.name(".EXPLORE", explore_service)
	explore_bt.on_released = function(touched)
		root_view:touch_disabled(true)
		ej.send(".EXPLORE","open_explore_view")
	end
--}}}--}}}--}}}
	ej.register_command("insert_bag_items",function(tbl)
		for _,v in ipairs(tbl) do
			item.load(v)
		end
		insert_bag_items(tbl)
		fresh_bag_view_items()
	end)
end)
