local ej = require "ejoy2dx"
local sprite = require "sprite"
local view = require "view"
local skynet = require "skynet"
local action = require "action"

local ui = {}
local ui_config_list = {}

local button_meta = sprite.new_meta()

local button_index = button_meta.__index

function button_meta.__index(bt,key)
	if button_meta[key] then return button_meta[key] end
	return button_index(bt,key)
end

function button_meta:set_disabled(disabled)
	self._disabled = disabled
	if disabled then
		self:stop_animation()
		self.ani = self._disabled_ani
	else
		self.ani = 0
	end
end

function button_meta:type()
	return "button"
end

function ui.button(tbl)
	local spr = sprite.new(tbl.packname,tbl.id or tbl.name)
	spr.touch_count = 1
	spr.message = true
	spr._disabled_ani = tbl.disabled_ani
	spr:register_touch_handle("press",function(touched)
		if spr._disabled then return end
		local ani = tbl.press_animation or {}
		ani.end_func = function()
			if spr.on_pressed then spr.on_pressed() end
		end
		spr:run_animation(ani)
	end)
	spr:register_touch_handle("release",function(touched)
		if spr._disabled then return end
		local ani = tbl.release_animation or {reversed = true}
		ani.end_func = function()
			if spr.on_released then spr.on_released() end
		end
		spr:run_animation(ani)
	end)
	spr:register_touch_handle("cancel",function(touched)
		if spr._disabled then return end
		local ani = tbl.cancel_animation or {reversed = true}
		ani.end_func = function()
			if spr.on_canceled then spr.on_canceled() end
		end
		spr:run_animation(ani)
	end)

	return debug.setmetatable(spr,button_meta)
end

function ui.view(tbl)
	local v = view.new(tbl)

	local element
	for index,etbl in ipairs(tbl) do
		if etbl.id then
			element = sprite.new(tbl.packname,etbl.id,etbl.mat)
		else
			local name = etbl.name
			local i,j = string.find(name,"#")
			if i then name = string.sub(name,1,i-1) end
			local config = ui_config_list[tbl.packname][name]
			if not config then error("no ui config for this name") end
			config.packname = tbl.packname
			element = ui[config.type](config)
			element:matrixBy(etbl.mat)
		end

		if etbl.name then v._elements_byName[etbl.name] = element end
		v:insert(element,index)
	end

	return v
end

local list_view_meta = view.new_meta()

local list_view_index = list_view_meta.__index

function list_view_meta.__index(lv,key)
	if list_view_meta[key] then return list_view_meta[key] end
	return list_view_index(lv,key)
end

function list_view_meta:type()
	return "list_view"
end

function list_view_meta:get_item(index)
	return self._items[index]
end

function list_view_meta:clear_item()
	for _,item in ipairs(self._items) do
		self._item_view:remove(item)
		item:release_touch_handle("shift",self._scroll_handle)
	end

	self._item_height,self._item_width,self._item_view.x,self._item_view.y,self._items = 0,0,0,0,{}
end

function list_view_meta:insert_item(index,item)
	if not item then
		item = index
		index = #self._items + 1
	end
	table.insert(self._items,index,item)
	local x1,y1,x2,y2 = self._item_panel:aabb()
	local item_panel = {x1,y1,x2-x1,y2-y1}
	for i = index,#self._items do
		local x1,y1,width,height = table.unpack(item_panel)
		local x2,y2,x3,y3 = self._items[i]:aabb()
		if self._orient == "vertical" then
			if i ~= 1 then
				_,_,_,y1 = self._items[i-1]:aabb()
			end
			if self._align == "right" then
				x1 = x1 + width - (x3 - x2)
			elseif self._align == "center" then
				x1 = x1 + width/2 - (x3 - x2)/2
			end
			self._items[i]:psBy(x1-x2,y1-y2)
			if i == #self._items then
				self._item_height = y1 + y3 - y2 - item_panel[2]
			end
		else
			if i ~= 1 then
				_,_,x1,_ = self._items[i-1]:aabb()
			end
			if self._align == "bottom" then
				y1 = y1 + height - (y3 - y2)
			elseif self._align == "center" then
				y1 = y1 + height/2 - (y3 - y2)/2
			end
			self._items[i]:psBy(x1-x2,y1-y2)
			if i == #self._items then
				self._item_width = x1 + x3 - x2 - item_panel[1]
			end
		end
	end
	self._item_view:insert(item)
	item.message = true
	item:register_touch_handle("shift",self._scroll_handle)
end

function list_view_meta:scroll(dd)
	if self._scroll_disabled then return end

	local x1,y1,x2,y2 = self._item_panel:aabb()
	local item_panel = {x1,y1,x2-x1,y2-y1}
	if self._orient == "vertical" then
		local y = self._item_view.y + dd
		if y < item_panel[4] - self._item_height then
			y = item_panel[4] - self._item_height
		end
		if y > 0 then
			y = 0
		end
		dd = y - self._item_view.y
		if dd ~= 0 then
			self._item_view.y = y
			self._item_view:psBy(0,dd)
		end
	else
		local x = self._item_view.x + dd
		if x < item_panel[3] - self._item_width then
			x = item_panel[3] - self._item_width
		end
		if x > 0 then
			x = 0
		end
		dd = x - self._item_view.x
		if dd ~= 0 then
			self._item_view.x = x
			self._item_view:psBy(dd,0)
		end
	end
end

function list_view_meta:scroll_disable(disabled)
	self._scroll_disabled = disabled
end

function list_view_meta:in_panel(x,y)
	local x1,y1,x2,y2 = self._item_panel:aabb()
	if x>x1 and x<x2 and y>y1 and y<y2 then return true end
end

function list_view_meta.type()
	return "list_view"
end

function ui.list_view(tbl)
	local v = ui.view(tbl)
	local iv = ui.view{}
	iv.x,iv.y = 0,0
	v:insert(iv)
	v._item_view = iv
	v._items = {}
	v._orient = tbl.orient or "vertical"
	v._align = tbl.align or "left"
	v._item_height = 0
	v._item_width = 0
	v._item_panel = v:get_element(tbl.item_panel or "panel")
	v._scroll_handle = function(touched,dx,dy)
		if v._orient == "vertical" then v:scroll(dy) else v:scroll(dx) end
	end

	v._item_panel.message = true
	v._item_panel:register_touch_handle("shift",v._scroll_handle)

	return debug.setmetatable(v,list_view_meta)
end

local progress_bar_meta = view.new_meta()

local progress_bar_index = progress_bar_meta.__index

function progress_bar_meta.__index(pb,key)
	if progress_bar_meta[key] then return progress_bar_meta[key] end
	return progress_bar_index(pb,key)
end

function progress_bar_meta:type()
	return "progress_bar"
end

function progress_bar_meta:get_percent(percent)
	return self._percent
end

function progress_bar_meta:set_percent(percent)
	if self._orient == "horizontal" then
		self._prog_panel:sr(percent,1)
	else
		self._prog_panel:sr(1,percent)
	end
	self._percent = percent
end

function ui.progress_bar(tbl)
	local v = ui.view(tbl)
	v._percent = tbl.percent/100 or 1
	v._orient = tbl.orient or "horizontal"
	v._prog_panel = v:get_element(tbl.progress_panel or "panel")
	debug.setmetatable(v,progress_bar_meta)
	v:set_percent(v._percent)

	return v
end

function action.ui_psBy(target,byValue,time)
	local act = action.linear(ej.FRAME_TIME)
	local cnt,perValue = math.ceil(time/ej.FRAME_TIME),{}

	for _,v in ipairs(byValue) do
		table.insert(perValue,v/cnt)
	end

	function act:total_cnt()
		return cnt
	end

	function act:step()
		target:psBy(table.unpack(perValue))
	end

	return act
end

function ui.new(packname,name)
	if not ui_config_list[packname] then
		local filename = ej.package_name(packname).."_ui_config.lua"
		ui_config_list[packname] = dofile(filename)
	end
	local config = ui_config_list[packname][name]
	if not config then error("no ui config for this name") end
	config.packname = packname
	return ui[config.type](config)
end

return ui
