local s = require "ejoy2d.shader.c"

local PRECISION = ""

if s.version() == 2 then
	-- Opengl ES 2.0 need float precision specifiers
	PRECISION = "precision lowp float;\n"
end

local sprite_fs = [[
varying vec2 v_texcoord;
varying vec4 v_color;
uniform sampler2D texture0;
uniform vec3 additive;

void main() {
	vec4 tmp = texture2D(texture0, v_texcoord);
	gl_FragColor.xyz = tmp.xyz * v_color.xyz;
	gl_FragColor.w = tmp.w;
	gl_FragColor *= v_color.w;
	gl_FragColor.xyz += additive.xyz * tmp.w;
}
]]

local sprite_vs = [[
attribute vec4 position;
attribute vec2 texcoord;
attribute vec4 color;

varying vec2 v_texcoord;
varying vec4 v_color;

void main() {
	gl_Position = position + vec4(-1,1,0,0);
	v_texcoord = texcoord;
	v_color = color;
}
]]

local text_fs = [[
varying vec2 v_texcoord;
varying vec4 v_color;

uniform sampler2D texture0;
uniform vec3 additive;

void main() {
	float c = texture2D(texture0, v_texcoord).w;
	float alpha = clamp(c, 0.0, 0.5) * 2.0;

	gl_FragColor.xyz = (v_color.xyz + additive) * alpha;
	gl_FragColor.w = alpha;
	gl_FragColor *= v_color.w;
}
]]

local text_edge_fs = [[
varying vec2 v_texcoord;
varying vec4 v_color;

uniform sampler2D texture0;
uniform vec3 additive;

void main() {
	float c = texture2D(texture0, v_texcoord).w;
	float alpha = clamp(c, 0.0, 0.5) * 2.0;
	float color = (clamp(c, 0.5, 1.0) - 0.5) * 2.0;

	gl_FragColor.xyz = (v_color.xyz + additive) * color;
	gl_FragColor.w = alpha;
	gl_FragColor *= v_color.w;
}
]]

local gray_fs = [[
varying vec2 v_texcoord;
varying vec4 v_color;
uniform sampler2D texture0;
uniform vec3 additive;

void main()
{
	vec4 tmp = texture2D(texture0, v_texcoord);
	vec4 c;
	c.xyz = tmp.xyz * v_color.xyz;
	c.w = tmp.w;
	c *= v_color.w;
	c.xyz += additive.xyz * tmp.w;
	float g = dot(c.rgb , vec3(0.299, 0.587, 0.114));
	gl_FragColor = vec4(g,g,g,c.a);
}
]]

local color_fs = [[
varying vec2 v_texcoord;
varying vec4 v_color;
uniform sampler2D texture0;
uniform vec3 additive;

void main()
{
	vec4 tmp = texture2D(texture0, v_texcoord);
	gl_FragColor.xyz = v_color.xyz * tmp.w;
	gl_FragColor.w = tmp.w;
}
]]

local sketch_fs = [[
uniform vec4 color;

void main()
{
	gl_FragColor = color;
}
]]

local sketch_vs = [[
attribute vec4 position;

uniform vec2 size;

void main() {
	gl_Position = vec4(2.0*position.x/size.x-1.0,-2.0*position.y/size.y+1.0,position.z,position.w);
}
]]

local blend_fs = [[
varying vec2 v_texcoord;
varying vec2 v_mask_texcoord;
varying vec4 v_color;

uniform sampler2D texture0;
uniform vec3 additive;

void main() {
	vec4 tmp = texture2D(texture0, v_texcoord);
	gl_FragColor.xyz = tmp.xyz * v_color.xyz;
	gl_FragColor.w = tmp.w;
	gl_FragColor *= v_color.w;
	gl_FragColor.xyz += additive.xyz * tmp.w;

	vec4 m = texture2D(texture0, v_mask_texcoord);
	gl_FragColor.xyz *= m.xyz;
//	gl_FragColor *= m.w;
}
]]


local blend_vs = [[
attribute vec4 position;
attribute vec2 texcoord;
attribute vec4 color;

varying vec2 v_texcoord;
varying vec2 v_mask_texcoord;
varying vec4 v_color;

uniform vec2 mask;

void main() {
	gl_Position = position + vec4(-1,1,0,0);
	v_texcoord = texcoord;
	v_mask_texcoord = texcoord + mask;
	v_color = color;
}
]]

local shader = {}

local shader_name = {
	NORMAL = 0,
	TEXT = 1,
	EDGE = 2,
	GRAY = 3,
	COLOR = 4,
	BLEND = 5,
	SKETCH = 6,
}

function shader.init()
	s.load(shader_name.NORMAL, PRECISION .. sprite_fs, PRECISION .. sprite_vs)
	s.load(shader_name.TEXT, PRECISION .. text_fs, PRECISION .. sprite_vs)
	s.load(shader_name.EDGE, PRECISION .. text_edge_fs, PRECISION .. sprite_vs)
	s.load(shader_name.GRAY, PRECISION .. gray_fs, PRECISION .. sprite_vs)
	s.load(shader_name.COLOR, PRECISION .. color_fs, PRECISION .. sprite_vs)
	s.load(shader_name.BLEND, PRECISION .. blend_fs, PRECISION .. blend_vs)
	s.load(shader_name.SKETCH, PRECISION .. sketch_fs, PRECISION .. sketch_vs)
end

shader.draw = s.draw
shader.blend = s.blend
shader.clear = s.clear

function shader.id(name)
	local id = assert(shader_name[name] , "Invalid shader name " .. name)
	return id
end

return shader
