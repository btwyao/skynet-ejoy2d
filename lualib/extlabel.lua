local ej = require "ejoy2dx"
local action = require "action"

local label = {}

local timer_meta = {}

function timer_meta.__index(timer,key)
	if timer_meta[key] then return timer_meta[key] end
	return timer.component[key]
end

--60 * 60 * 24
local timer_conversion = {60,60,24}
local timer_measure = {1,60,60*60,24*60*60}
local timer_format = {
	cn = {"秒","分","时","天",},
	en = {"s","m","h","d",},
	colon = {"",":",":",":",},
}

local function format_time(time, format)
	local format,text = timer_format[format],''
	for i = 4,1,-1 do
		local num = math.floor(time / timer_measure[i])
		time = time % timer_measure[i]
		if num > 0 then
			text = text .. num .. format[i]
		end
	end
	return text
end

function timer_meta:reset_timer(id)
	if id then
		self._timer[id] = nil
	else
		self._timer = {}
	end
end

function timer_meta:_parse_text(txt)
	local i = 0
	txt = string.gsub(txt,'$time%((%w+),(%w+)%)',function(time,format)
		i,time = i + 1,time / 1
		if not self._timer[i] then
			self._timer[i] = time
		end

		return format_time(self._timer[i],format)
	end)

	txt = self.component:_parse_text(txt)
	return txt
end

function action.text_timerTo(target,id,toValue)
	local act = action.linear(100)
	local forward = 1

	function act:total_cnt()
		local val = target._timer[id]
		if toValue < val then
			forward = -1
			return val-toValue
		end
		return toValue-val
	end

	function act:step()
		local cur_time = target._timer[id]
		cur_time = cur_time + 1*forward

		target._timer[id] = cur_time
		target:fresh_text()
	end

	return act
end

function label.timer(lb)
	local timer = {component = lb,_timer = {}}

	return debug.setmetatable(timer,timer_meta)
end

return label
