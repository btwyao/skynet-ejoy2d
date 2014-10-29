local ej = require "ejoy2dx"
local util = require "util"

local item_tbl = ej.load_table("tansuo","base_goods")
local char_tbl = ej.load_table("tansuo","character")
local item = {}

local item_meta = {}
item_meta.__index = item_meta

function item_meta:load()
end

local quality_color = {'w','g1','b1','p','o'}

function item_meta:get(key)
	if key == "name" then
		local name = item_tbl[self.idx][key]
		name = '#['..quality_color[item_tbl[self.idx]["quality"]]..']'..name..'#[stop]'
		return name
	end
	return item_tbl[self.idx][key]
end

function item_meta:special()
	local info = item_tbl[self.idx]
	if info.leixing == 1 and info.quality < 3 then
		return false
	end

	return true
end

function item_meta:get_amount()
	return self.amount or 1
end

function item_meta:set_amount(amount)
	self.amount = amount
end

function item_meta:add_amount(amount)
	self.amount = (self.amount or 1) + amount
	if self.amount < 0 then self.amount = 0 end
end

local exhibit_meta = {}
exhibit_meta.__index = exhibit_meta
debug.setmetatable(exhibit_meta,item_meta)

function exhibit_meta:type()
	return "exhibit"
end

local exhibit_prop = {fanrongdu = true, youhuoli = true, tansuoli = true, jingyingli = true, shenmeili = true, character = true}

local exhibit_get = exhibit_meta.get

function exhibit_meta:get(key)
	if not exhibit_prop[key] then return exhibit_get(self,key) end

	if key ~= "character" then
		local value = item_tbl[self.idx][key] or 0
		if self[key] then value = value + self[key] end
		return value
	else
		return self[key] or {}
	end
end

function exhibit_meta:cal_value()
	local value = self:get("fanrongdu")+self:get("youhuoli")*6+(self:get("tansuoli")+self:get("jingyingli")+self:get("shenmeili"))*4
	if not self.character then return value end

	for _,data in ipairs(self.character) do
		local info = char_tbl[data.idx]
		value = value + (info.shuxing + data.shuxing) * info.dwjiazhi
	end

	return value
end

local char_tbl = ej.load_table("tansuo","character")

local function start_char1(char,obj,prop_tbl)
	char.enter_event = util.event_register(obj.on_enter_scene,function(obj)
		for key,val in pairs(prop_tbl) do
			obj.buff_data[key] = (obj.buff_data[key] or 0) + val
		end
	end)
	char.leave_event = util.event_register(obj.on_leave_scene,function(obj)
		for key,val in pairs(prop_tbl) do
			obj.buff_data[key] = (obj.buff_data[key] or 0) - val
		end
	end)
end

local function stop_char1(char,obj)
	util.event_release(obj.on_enter_scene,char.enter_event)
	util.event_release(obj.on_leave_scene,char.leave_event)
	char.enter_event,char.leave_event = nil
end

local function start_char2(char,obj,func)
	char.attract_event = util.event_register(obj.on_attract_npc,func)
end

local function stop_char2(char,obj)
	util.event_release(obj.on_attract_npc,char.attract_event)
	char.attract_event = nil
end

local function start_char3(char,obj,kind,prop_func)
	char.enter_event = util.event_register(obj.on_enter_scope,function(obj)
		if obj:type() ~= kind then return end
		for key,val in pairs(prop_func(obj)) do
			obj.buff_data[key] = (obj.buff_data[key] or 0) + val
		end
	end)
	char.leave_event = util.event_register(obj.on_leave_scope,function(obj)
		if obj:type() ~= kind then return end
		for key,val in pairs(prop_func(obj)) do
			obj.buff_data[key] = (obj.buff_data[key] or 0) - val
		end
	end)
end

local function stop_char3(char,obj)
	util.event_release(obj.on_enter_scope,char.enter_event)
	util.event_release(obj.on_leave_scope,char.leave_event)
	char.enter_event,char.leave_event = nil
end

char_tbl[1000].start_char = function(char,obj)
	start_char1(char,obj,{fanrongdu = obj.fanrongdu * char:get("shuxing") / 100})
end

char_tbl[1000].stop_char = stop_char1

char_tbl[1001].start_char = function(char,obj)
	start_char1(char,obj,{
		tansuoli = char:get("shuxing"),
		jingyingli = char:get("shuxing"),
		shenmeili = char:get("shuxing")
	})
end

char_tbl[1001].stop_char = stop_char1

char_tbl[1002].start_char = function(char,obj)
	start_char1(char,obj,{youhuoli = obj.youhuoli * char:get("shuxing") / 100})
end

char_tbl[1002].stop_char = stop_char1

char_tbl[1003].start_char = function(char,obj)
	local function func(npc,info_tbl)
		if util.random(100) > 10 then return end
		info_tbl.youhuoli = info_tbl.youhuoli * (1 + char:get("shuxing") / 10)
	end

	start_char2(char,obj,func)
end

char_tbl[1003].stop_char = stop_char2

char_tbl[1004].start_char = function(char,obj)
	start_char3(char,obj,"scene_booth",function(obj)
		return {fanrongdu = obj.fanrongdu * char:get("shuxing") / 100}
	end)
end

char_tbl[1004].stop_char = stop_char3

char_tbl[1005].start_char = function(char,obj)
	start_char3(char,obj,"scene_booth",function(obj)
		return {
			fanrongdu = char:get("shuxing"),
			youhuoli = char:get("shuxing"),
			tansuoli = char:get("shuxing"),
			jingyingli = char:get("shuxing"),
			shenmeili = char:get("shuxing")
		}
	end)
end

char_tbl[1005].stop_char = stop_char3

char_tbl[1006].start_char = function(char,obj)
	start_char3(char,obj,"scene_booth",function(obj)
		return {youhuoli = obj.youhuoli * char:get("shuxing") / 100}
	end)
end

char_tbl[1006].stop_char = stop_char3

char_tbl[1007].start_char = function(char,obj)
	start_char3(char,obj,"scene_booth",function(obj)
		return {sudu = obj.item_data:get("sudu") * char:get("shuxing") / 100}
	end)
end

char_tbl[1007].stop_char = stop_char3

char_tbl[1008].start_char = function(char,obj)
	start_char3(char,obj,"scene_npc",function(obj)
		return {speed = -obj.speed * char:get("shuxing") / 100}
	end)
end

char_tbl[1008].stop_char = stop_char3

char_tbl[1009].start_char = function(char,obj)
	local function func(npc,info_tbl)
		info_tbl.resist_dec = char:get("shuxing") / 100
		if info_tbl.resist_dec > 1 then info_tbl.resist_dec = 1 end
	end

	start_char2(char,obj,func)
end

char_tbl[1009].stop_char = stop_char2

char_tbl[1010].start_char = function(char,obj)
	local function func(npc,info_tbl)
		if util.random(100) > 5 then return end
	end

	start_char2(char,obj,func)
end

char_tbl[1010].stop_char = stop_char2

char_tbl[1011].start_char = function(char,obj)
	local function func(npc,info_tbl)
		if util.random(100) > 10 then return end
		info_tbl.youhuoli = info_tbl.youhuoli * (1 + char:get("shuxing") / 10)
	end

	start_char2(char,obj,func)
end

char_tbl[1011].stop_char = stop_char2

char_tbl[1012].start_char = function(char,obj)
	start_char3(char,obj,"scene_booth",function(obj)
		return {fanrongdu = obj.fanrongdu * char:get("shuxing") / 100}
	end)
end

char_tbl[1012].stop_char = stop_char3

char_tbl[1013].start_char = char_tbl[1005].start_char
char_tbl[1013].stop_char = stop_char3

char_tbl[1014].start_char = char_tbl[1006].start_char
char_tbl[1014].stop_char = stop_char3

char_tbl[1015].start_char = char_tbl[1007].start_char
char_tbl[1015].stop_char = stop_char3

char_tbl[1016].start_char = char_tbl[1008].start_char
char_tbl[1016].stop_char = stop_char3

char_tbl[1017].start_char = char_tbl[1009].start_char
char_tbl[1017].stop_char = stop_char2

local character_meta = {}

function character_meta.__index(char,key)
	if character_meta[key] then return character_meta[key] end

	return char_tbl[char.idx][key]
end

function character_meta:get(key)
	local val = char_tbl[self.idx][key]
	if key == "shuxing" and self.shuxing then
		val = val + self.shuxing
	elseif key == "miaoshu" then
		local miaoshu = char_tbl[self.idx]["name"] .. ":" .. char_tbl[self.idx]["introduction"]
		miaoshu = '#['..quality_color[char_tbl[self.idx]["quality"]]..']'..miaoshu..'#[stop]'
		return miaoshu
	end
	return val
end

function exhibit_meta:load()
	if not self.character then return end
	for _,char in ipairs(self.character) do
		debug.setmetatable(char,character_meta)
	end
end

function item.exhibit(idx,tbl)
	local exhibit = {idx = idx}
	if tbl.frdjp_probalility and math.random(100) <= tbl.frdjp_probalility then
		exhibit.fanrongdu = math.random(tbl.frdjp_max)
	end
	if tbl.yhljp_probalility and math.random(100) <= tbl.yhljp_probalility then
		exhibit.youhuoli = math.random(tbl.yhljp_max)
	end
	if tbl.jpitem_probalility and math.random(100) <= tbl.jpitem_probalility then
		local able = {"tansuoli","jingyingli","shenmeili"}
		exhibit[able[math.random(3)]] = math.random(tbl.jp_max)
	end
	if tbl.ctitem_probability and math.random(100) <= tbl.ctitem_probability then
		local character = util.random_tblN(tbl.character,math.random(tbl.Cractr_items))
		exhibit.character = {}
		for _,idx in ipairs(character) do
			local info,data = char_tbl[idx],{idx = idx}
			if math.random(100) <= info.jp_probalility then
				data.shuxing = math.random(info.jp_max)
			end
			debug.setmetatable(data,character_meta)
			table.insert(exhibit.character,data)
		end
	end

	return debug.setmetatable(exhibit,exhibit_meta)
end

local booth_meta = {}
booth_meta.__index = booth_meta
debug.setmetatable(booth_meta,item_meta)

function booth_meta:type()
	return "booth"
end

local booth_prop = {sudu = true, kongjian = true, zuoyongfw = true, container = true}
local booth_get = booth_meta.get

function booth_meta:get(key)
	if not booth_prop[key] then return booth_get(self,key) end

	if key == "sudu" then
		local value = item_tbl[self.idx]["sudubenzhi"]
		if self[key] then value = value + self[key] end
		return value
	else
		return self[key]
	end
end

function booth_meta:add_good(obj)
	assert(obj:type() == "exhibit" and not obj.in_booth)
	if not obj.bag_id then error("invalid good") end
	if #self.container >= self.kongjian then return false end
	table.insert(self.container,obj.bag_id)
	obj.in_booth = true
	return true
end

function booth_meta:remove_good(obj)
	assert(obj:type() == "exhibit")
	if not obj.bag_id then error("invalid good") end
	for i,bag_id in ipairs(self.container) do
		if obj.bag_id == bag_id then
			obj.in_booth = nil
			table.remove(self.container,i)
			return true
		end
	end
end

function item.booth(idx,tbl)
	local booth = {idx = idx,container = {}}
	booth.kongjian = math.random(tbl.kongjian_min,tbl.kongjian_max)
	booth.zuoyongfw = math.random(tbl.zuoyongfw_min,tbl.zuoyongfw_max)
	if math.random(100) <= tbl.suduJPJL then
		booth.sudu = math.random(tbl.suduJP)
	end

	return debug.setmetatable(booth,booth_meta)
end

local carpet_meta = {}
carpet_meta.__index = carpet_meta
debug.setmetatable(carpet_meta,item_meta)

function carpet_meta:type()
	return "carpet"
end

function item.carpet(idx,tbl)
	local carpet = {idx = idx}

	return debug.setmetatable(carpet,carpet_meta)
end

local virtual_meta = {}
virtual_meta.__index = virtual_meta
debug.setmetatable(virtual_meta,item_meta)

function virtual_meta:type()
	return "virtual"
end

function item.virtual(idx,tbl)
	local virtual = {idx = idx}

	return debug.setmetatable(virtual,virtual_meta)
end

local meta_tbl = {exhibit_meta,booth_meta,carpet_meta,virtual_meta,booth_meta}

function item.load(obj)
	local kind = item_tbl[obj.idx].leixing
	debug.setmetatable(obj,meta_tbl[kind])
	obj:load()

	return obj
end

local item_type = {"exhibit","booth","carpet","virtual","booth"}

function item.new(idx)
	local tbl = item_tbl[idx]
	if not tbl then error("invalid item idx: "..idx) end

	return item[item_type[tbl.leixing]](idx,tbl)
end

return item
