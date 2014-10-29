local skynet = require "skynet"
local ej = require "ejoy2dx"
local ui = require "ui"
local sprite = require "sprite"
local db = require "database"
local action = require "action"
local util = require "util"
local item = require "item"
local label = require "extlabel"

local service_view_pos = tonumber(...)

local venue_size = {6,8,8,10,10,12,12,14,14,16}

local function generate_venue_pos(size)
	local total_num = (size/2)*(size/2)-1
	local big_num = math.random(0,total_num)
	local small_num = math.random(0,total_num-big_num)
	local big_tbl,small_tbl = {},{}
	print("big small good num:",big_num,small_num)
	local index_tbl = util.randomN(big_num+small_num,0,total_num-1)
	local indexBig_tbl = util.randomN(big_num,1,big_num+small_num)

	for _,i in ipairs(indexBig_tbl) do
		local index = index_tbl[i]
		local x,y = index % (size / 2), math.floor(index / (size / 2))
		table.insert(big_tbl,2 * y * size + x * 2)
		index_tbl[i] = -1
	end

	for _,index in ipairs(index_tbl) do
		if index >= 0 then
			local x,y = index % (size / 2), math.floor(index / (size / 2))
			table.insert(small_tbl,2 * y * size + x * 2)
		end
	end

	return big_tbl,small_tbl
end

local cover_meta = sprite.new_meta()
local cover_erase_interval = 10

local cover_index = cover_meta.__index

function cover_meta.__index(cv,key)
	if cover_meta[key] then return cover_meta[key] end
	return cover_index(cv,key)
end

function cover_meta:type()
	return "cover"
end

function cover_meta:add_erase_vol(vol)
	ej.win_call("cover_vol",self._spr_ptr,vol)
end

function cover_meta:erase_disabled(disabled)
	ej.win_call("cover_disabled",self._spr_ptr,disabled)
end

function cover_meta:add_good(good,gx,gy,scale)
	ej.win_call("cover_addGood",self._spr_ptr,good._spr_ptr,gx,gy,scale)
end

function cover_meta:cover_init(widthGrid,heightGrid,grid_pixels,vol)
	local tbl = self._init_data
	tbl._widthGrid = widthGrid
	tbl._heightGrid = heightGrid
	tbl._grid_pixels = grid_pixels
	tbl.vol = vol
	ej.win_call("new_cover",self._spr_ptr,tbl)
end

ej.register_command("cover_discoveredGood",function(spr_ptr,good_ptr)
	local spr = sprite.get(spr_ptr)
	local good = sprite.get(good_ptr)
	if not spr or not good then return ej.NORET end
	if spr.on_good_discovered then spr.on_good_discovered(good) end
	return ej.NORET
end)

ej.register_command("cover_curVol",function(spr_ptr,vol)
	local spr = sprite.get(spr_ptr)
	if not spr then return ej.NORET end
	if spr.on_vol_changed then spr.on_vol_changed(vol) end
	return ej.NORET
end)

function ui.cover(tbl)
	local spr = sprite.new(tbl.packname,tbl.id)
	if spr:sprite_type() ~= "PICTURE" then error("sprite should be a picture!!!") end
	spr.touch_count = 1
	spr.message = true
	spr._init_data = {_dynamic_tex = tbl.dynamic_tex or {true}, _init_radius = tbl.init_radius, _expand_radius = tbl.expand_radius, _max_radius = tbl.max_radius,}

	return debug.setmetatable(spr,cover_meta)
end

ej.start(function()
	sprite.loadpack{"explore"}

	local root_view = ui.view{}
	ej.service_view(root_view,service_view_pos)

	local explore_tbl = ej.load_table("tansuo","explore_tbl")
	local venue_goods = ej.load_table("tansuo","venue_goods")
	local base_goods = ej.load_table("tansuo","base_goods")

	local explore_view = ui.new("explore","exploreinterface")
	local close_bt = explore_view:get_element("guanbi")
	close_bt.on_released = function(touched)
		root_view:remove(explore_view)
		ej.send("HALL","service_touch_disabled",false)
	end

	local explore_data = db.get("explore")

	for _,info in ipairs(explore_tbl) do
		local name = info.name
		local explore_item = ui.new("explore","exploredilanjh")
		explore_view:insert_item(explore_item)

		local pic_anchor = explore_item:get_element("maodian")
		local pic_spr = sprite.new("explore",name)
		pic_spr:sprite_trans(pic_anchor)
		explore_item:insert(pic_spr)

		local tip_text = explore_item:get_element("changguanxinxi")
		tip_text:set_text(info.tip_id)

		--场景次数
		explore_data[name] = explore_data[name] or {}
		local cur_time = skynet.now()
		local last_time = explore_data[name].last_time or cur_time
		local amount = explore_data[name].amount or 0
		local interval = cur_time - last_time
		if amount < info.max_mount and interval >= info.fresh_interval then
			local cnt = math.floor(interval/info.fresh_interval)
			interval = interval%info.fresh_interval
			amount = amount + cnt
			amount = amount > info.max_mount and info.max_mount or amount
		end
		explore_data[name].amount = amount
		explore_data[name].last_time = cur_time - interval

		local enter_bt,timer_label,timer_act = explore_item:get_element("jinru"),explore_item:get_element("jishiqi")
		timer_label = label.timer(timer_label)
		local function reset_timer()
			if timer_act then timer_act:stop() end
			timer_label:reset_timer()
			timer_label:set_text(8,{['#amount'] = amount, ['#time'] = info.fresh_interval-interval})
			timer_act = action.loop(action.sequence{action.text_timerTo(timer_label,1,0),action.instant(function()
				if amount <1 then enter_bt:set_disabled(false) end
				amount = amount + 1
				if amount < info.max_mount then
					timer_label:reset_timer()
					timer_label:set_text(8,{['#amount'] = amount, ['#time'] = info.fresh_interval})
				else
					timer_label:reset_timer()
					timer_label:set_text(9,{['#amount'] = amount})
				end
			end)},info.max_mount-amount)
			timer_act:start()
		end
		reset_timer()

		local function open_venue_view()--{{{
			local level = explore_data[name].level or 9
			local size = venue_size[level+1]

			local venue_top = ui.new("explore","venuetop")
			local venue_tan = venue_top:get_element("tan")
			local venue_quit = venue_top:get_element("LiKai")
			local tansuo_view,max_tansuo = venue_top:get_element("tansuozhi"),7500 * 64

			local venue_base = ui.new("explore","venuebase")
			local panel_venue = venue_base:get_element("panel_venue")
			local zhegaiceng = ui.new("explore","zhegaiceng")
			zhegaiceng:cover_init(size,size,75,max_tansuo)
			local x0,y0,x1,y1 = panel_venue:aabb()
			panel_venue:ps(x0,y0,size/16)
			local big_tbl,small_tbl = generate_venue_pos(size)
			local goods = venue_goods[name]
			local good_list = {}

			for _,pos in ipairs(big_tbl) do
				local good_idx = util.random_tblR(goods)
				local good_name = base_goods[good_idx].spritename
				local good = sprite.new("cangpin",good_name)
				good.item_idx = good_idx
				local x,y = pos%size,math.floor(pos/size)
				good:psBy(x0+x*75,y0+y*75)
				venue_base:insert(good)
				zhegaiceng:add_good(good,x,y,2)
			end

			for _,pos in ipairs(small_tbl) do
				local good_idx = util.random_tblR(goods)
				local good_name = base_goods[good_idx].spritename
				local good = sprite.new("cangpin",good_name)
				good.item_idx = good_idx
				local x,y = pos%size,math.floor(pos/size)
				good:psBy(x0+x*75,y0+y*75,0.5)
				venue_base:insert(good)
				zhegaiceng:add_good(good,x,y,1)
			end

			local good_bag,good_bag_data = venue_top:get_element("Shounahe"),{}
			local good_bag_x,good_bag_y = good_bag:aabb()
			zhegaiceng.on_good_discovered = function(good)
				venue_base:remove(good)

				local good_spr = sprite.new("common","translation")
				local x0,y0,x1,y1 = good:aabb()
--				local ps = sprite.particle("guanghuan")
--				ps:ps(x0+(x1-x0)/2,y0+(y1-y0)/2)
--				venue_base:insert(ps)
--				ps:particle_run()
				good_spr:ps(x0+(x1-x0)/2,y0+(y1-y0)/2)
				good:psBy((x0-x1)/2-x0,(y0-y1)/2-y0)
				good_spr:mount("maodian",good)
				venue_base:insert(good_spr)

				local shake_act = action.sequence{
					action.loop(action.sequence{action.spr_rotTo(good_spr,10,6,-6),action.spr_rotTo(good_spr,10,-6,6)}),
				}
				good_spr:sr(6)
				shake_act:start()

				good_spr.message = true
				good_spr:register_touch_handle("release",function(touched)
					shake_act:stop()
--					ps:particle_stop()
--					venue_base:remove(ps)
					venue_base:remove(good_spr)
					venue_top:insert(good_spr)

					local x,y = good_spr:aabb()
					local act = action.sequence{action.ui_psBy(good_spr,{good_bag_x-x,good_bag_y-y},100),action.instant(function()
						venue_top:remove(good_spr)
						local good = item.new(good.item_idx)
						table.insert(good_bag_data,good)
					end)}
					act:start()
				end)
			end

			zhegaiceng.on_vol_changed = function(vol)
				tansuo_view:set_percent(-vol/max_tansuo)
			end

			zhegaiceng:psBy(x0,y0)
			venue_base:insert(zhegaiceng)
			root_view:insert(venue_base)
			root_view:insert(venue_top)
			zhegaiceng:erase_disabled(true)
			local tan_state = false
			venue_tan.message = true
			venue_tan:register_touch_handle("release",function(touched)
				tan_state = not tan_state
				if tan_state then
					touched.frame = 1
					zhegaiceng:erase_disabled(false)
				else
					touched.frame = 0
					zhegaiceng:erase_disabled(true)
				end
			end)
			venue_quit.on_released = function(touched)
				ej.call("HALL","insert_bag_items",good_bag_data)
				root_view:remove(venue_top)
				root_view:remove(venue_base)
			end

			local venue_base_dx,venue_base_dy = 0,0
			venue_base:register_touch_handle("shift",function(touched,dx,dy)
				if tan_state then return end
				local width,height = ej.screen_size()
				local x,y = venue_base_dx+dx,venue_base_dy+dy
				if x>0 or x<width-x1 then dx = 0 end
				if y>0 or y<height-y1 then dy = 0 end
				if dx~=0 or dy~=0 then
					venue_base_dx,venue_base_dy = venue_base_dx+dx,venue_base_dy+dy
					venue_base:psBy(dx,dy)
				end
			end)
		end
--}}}
		if amount <1 then enter_bt:set_disabled(true) end
		enter_bt.on_released = function(touched)
			interval = 0
			amount = amount - 1
			explore_data[name].amount = amount
			explore_data[name].last_time = skynet.now()
			if amount <1 then enter_bt:set_disabled(true) end
			reset_timer()
			open_venue_view()
		end

	end

	ej.register_command("open_explore_view",function()
		root_view:insert(explore_view)
		return ej.NORET
	end)
end)
