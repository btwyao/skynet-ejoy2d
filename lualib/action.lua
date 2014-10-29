local ej = require "ejoy2dx"

local action = {}

local linear_meta = {}
linear_meta.__index = linear_meta

function linear_meta:start()
	local cnt,total_cnt = 0,self:total_cnt()

	local function update()
		cnt = cnt + 1
		self:step()

		if cnt >= total_cnt then
			self._timeout_id = nil
			if self.on_end then self:on_end() end
			return true
		end
	end

	self._timeout_id = ej.timeout(self._interval,update)
end

function linear_meta:stop()
	self.on_end = nil
	if self._timeout_id then
		ej.remove_timeout(self._timeout_id)
		self._timeout_id = nil
	end
end

function action.linear(interval)
	local linear = {_interval = interval}

	return debug.setmetatable(linear,linear_meta)
end

local sequence_meta = {}
sequence_meta.__index = sequence_meta

function sequence_meta:start()
	local index = 0

	local function on_end()
		index = index + 1
		local action = self[index]
		self._cur_index = index
		if action then
			action.on_end = on_end
			action:start()
		elseif self.on_end then
			self:on_end()
		end
	end

	on_end()
end

function sequence_meta:stop()
	self.on_end = nil
	local index = self._cur_index
	if index and self[index] then
		self[index]:stop()
		self._cur_index = nil
	end
end

function action.sequence(tbl)
	local sequence = tbl

	return debug.setmetatable(sequence,sequence_meta)
end

local loop_meta = {}
loop_meta.__index = loop_meta

function loop_meta:start()
	local action = self._action
	local cnt = 0

	local function on_end()
		if not self._total_cnt then
			action.on_end = on_end
			action:start()
		elseif cnt < self._total_cnt then
			cnt = cnt + 1
			action.on_end = on_end
			action:start()
		elseif self.on_end then
			self:on_end()
		end
	end

	on_end()
end

function loop_meta:stop()
	self.on_end = nil
	return self._action:stop()
end

function action.loop(act,total_cnt)
	local loop = {_action = act, _total_cnt = total_cnt}

	return debug.setmetatable(loop,loop_meta)
end

local instant_meta = {}
instant_meta.__index = instant_meta

function instant_meta:start()
	self._func()
	if self.on_end then self:on_end() end
end

function instant_meta:stop()
	self.on_end = nil
end

function action.instant(func)
	local instant = {_func = func}

	return debug.setmetatable(instant,instant_meta)
end

return action
