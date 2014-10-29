local debug = debug
local c = require "ejoy2d.sprite.c"
local pack = require "ejoy2d.spritepack"
local shader = require "ejoy2d.shader"
local richtext = require "ejoy2d.richtext"

local method = c.method
local method_fetch = method.fetch
local method_test = method.test
local method_fetch_by_index = method.fetch_by_index
local method_children = method.children
local fetch
local test
local children

local get = c.get
local set = c.set

local set_program = set.program
function set:program(prog)
	if prog == nil then
		set_program(self)
	else
		set_program(self, shader.id(prog))
	end
end

local set_text = set.text
function set:text(txt)
	if type(txt) == "string" then
		set_text(self, richtext:format(txt))
	else
		set_text(self, txt)
	end
end

function get:ui_type()
	return "sprite"
end

function method:is_ui_type(v)
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

local sprite_meta = {}

function sprite_meta.__index(spr, key)
	if method[key] then
		return method[key]
	end
	local getter = get[key]
	if getter then
		return getter(spr)
	end
	local child = fetch(spr, key)

	if child then
		return child
	else
		print("Unsupport get " ..  key)
		return nil
	end
end

function sprite_meta.__newindex(spr, key, v)
	local setter = set[key]
	if setter then
		setter(spr, v)
		return
	end
	assert(debug.getmetatable(v) == sprite_meta, "Need a sprite")
	method.mount(spr, key, v)
end

-- local function
function fetch(spr, child)
	local cobj = method_fetch(spr, child)
	if cobj then
		return debug.setmetatable(cobj, sprite_meta)
	end
end

-- local function
function test(...)
	local cobj = method_test(...)
	if cobj then
		return debug.setmetatable(cobj, sprite_meta)
	end
end

function fetch_by_index(spr, index)
	local cobj = method_fetch_by_index(spr, index)
	if cobj then
		return debug.setmetatable(cobj, sprite_meta)
	end
end

function children(spr)
	local ret = method_children(spr)
	for _,child in ipairs(ret) do
		debug.setmetatable(child, sprite_meta)
	end
	return ret
end

method.fetch = fetch
method.fetch_by_index = fetch_by_index
method.test = test
method.children = children

local sprite = {}

function sprite.new(packname, name)
	local pack, id = pack.query(packname, name)
	local cobj = c.new(pack,id)
	if cobj then
		return debug.setmetatable(cobj, sprite_meta)
	end
end

function sprite.label(tbl)
	local size = tbl.size or tbl.height - 2
	local l = (c.label(tbl.width, tbl.height, size, tbl.color, tbl.align))
	if l then
		l = debug.setmetatable(l, sprite_meta)
		if tbl.text then
			l.text = tbl.text
		end
		return l
	end
end

return sprite
