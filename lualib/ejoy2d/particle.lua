local debug = debug
local ej = require "ejoy2d"
local c = require "ejoy2d.particle.c"
local shader = require "ejoy2d.shader"
local pack = require "ejoy2d.spritepack.c"
local fw = require "window.c"
local matrix = require "ejoy2d.matrix"
local math = require "math"
local sprite = require "ejoy2d.sprite"

local particle_configs = dofile(fw.WorkDir..[[asset/interface/particle_particle_config.lua]])
local particle_group_configs = {}

local particle = {}

local particle_meta = {__index = {mat = {}, col = {}}}

function particle_meta.__index:update(dt)
	if not self.is_active then return end

	self.is_active = false
	loop_active = false
	for _, v in ipairs(self.particles) do
		local visible = self:is_particle_visible(v)
		if visible then
			if not v.is_visible then
				v.is_visible = true
				c.reset(v.particle)
			end
			local active = c.update(v.particle, dt, matrix(v.anchor.world_matrix), v.edge)

			self.is_active = active or self.is_active
			loop_active = loop_active or (self.is_active and v.is_loop or false)
		else
			if v.is_visible then
				v.is_visible = false
			end
		end
	end

	if self.group.type == pack.TYPE_ANIMATION and self.group.frame_count > 1 then
		local stay_last = false
		local last_frame = self.group.frame >= self.group.frame_count - 1
		if self.is_active then
			if last_frame then
				if loop_active then
					stay_last = true
					self.group.frame = self.group.frame_count - 1
				else
					self.is_active = false
				end
			end
		else
			if not last_frame then
				self.is_active = true
			end
		end

		--print(self.group.frame, self.group.frame_count, stay_last, last_frame, loop_active)
		if not stay_last and not last_frame then
			self.float_frame = self.float_frame + fw.AnimationFramePerFrame
			self.group.frame = self.float_frame
		end
	end
end

function particle_meta.__index:reset()
	self.is_active = true
	if self.group.type == pack.TYPE_ANIMATION then
		self.group.frame = 0
	end
	self.float_frame = 0
	for _, v in ipairs(self.particles) do
		v.is_visible = false
	end
end

function particle_meta.__index:is_particle_visible(particle)
	if self.group.type == pack.TYPE_ANIMATION then
		return self.group:child_visible(particle.anchor.name)
	else
		return true
	end
end

function particle.preload(config_path)
	particle_configs = dofile(config_path.."_particle_config.lua")
end

local function new_single(name, anchor)
	local config = rawget(particle_configs, name)
	assert(config ~= nil, "particle not exists:"..name)
	local texName = config.texName
	local cobj = c.new(config)
	anchor.visible = true

	if cobj then
		local sprite = ej.sprite("particle", texName)
		local x, y, w, h = sprite:aabb()
		local edge = 2 * math.min(w, h)
		anchor:anchor_particle(cobj, sprite)
		return {particle = cobj,
			sprite = sprite,
			edge = edge,
			src_blend = config.blendFuncSource,
			dst_blend = config.blendFuncDestination,
			anchor = anchor,
			is_loop = config.duration < 0,
			emit_in_world = config.positionType == 2,
			name = name
		}
	end
end

function particle.new(name, callback)
	local config,particles,loop,group = rawget(particle_configs, name),{},false
	if config then
		group = ej.sprite("particle", 0xffff)
		local spr = new_single(name, group)
		rawset(particles, #particles+1, spr)
		loop = loop or spr.is_loop
	else
		group = ej.sprite("particle", name)
		local config = table.pack(group:children_name())
		for _, v in ipairs(config) do
			local anchor = group:fetch(v)
			local spr = new_single(v, anchor)
			rawset(particles, #particles+1, spr)
			-- group:mount(v, spr.sprite)
			loop = loop or spr.is_loop
		end
	end

	return debug.setmetatable({group=group,
		is_active = true,
		is_visible = false,
		particles = particles,
		end_callback = callback,
		is_loop = loop,
		float_frame = 0,
		}, particle_meta)
end

return particle
