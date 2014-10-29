#include "spritepack.h"
#include "sprite.h"
#include "label.h"
#include "shader.h"
#include "particle.h"
#include "scissor.h"
#include "texture.h"
#include "screen.h"

#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <assert.h>

#define SRT_X 1
#define SRT_Y 2
#define SRT_SX 3
#define SRT_SY 4
#define SRT_ROT 5
#define SRT_SCALE 6

static struct sprite *
newlabel(lua_State *L, struct pack_label *label) {
	int sz = sizeof(struct sprite) + sizeof(struct pack_label);
	struct sprite *s = (struct sprite *)lua_newuserdata(L, sz);
	s->parent = NULL;
	// label never has a child
	struct pack_label * pl = (struct pack_label *)(s+1);
	*pl = *label;
	s->s.label = pl;
	s->t.mat = NULL;
	s->t.color = 0xffffffff;
	s->t.additive = 0;
	s->t.program = PROGRAM_DEFAULT;
	s->message = false;
	s->visible = true;
	s->name = NULL;
	s->id = 0;
	s->type = TYPE_LABEL;
	s->start_frame = 0;
	s->total_frame = 0;
	s->frame = 0;
	s->data.rich_text = NULL;
	return s;
}

/*
	integer width
	integer height
	integer size
	uinteger color
	string l/r/c

	ret: userdata
 */
static int
lnewlabel(lua_State *L) {
	struct pack_label label;
	label.width = (int)luaL_checkinteger(L,1);
	label.height = (int)luaL_checkinteger(L,2);
	label.size = (int)luaL_checkinteger(L,3);
	label.color = (uint32_t)luaL_optunsigned(L,4,0xffffffff);
    label.space_w = 0;
    label.space_h = 0;
    label.auto_scale = 1;
    label.edge = 1;
	const char * align = lua_tostring(L,5);
	if (align == NULL) {
		label.align = LABEL_ALIGN_LEFT;
	} else {
		switch(align[0]) {
		case 'l':
		case 'L':
			label.align = LABEL_ALIGN_LEFT;
			break;
		case 'r':
		case 'R':
			label.align = LABEL_ALIGN_RIGHT;
			break;
		case 'c':
		case 'C':
			label.align = LABEL_ALIGN_CENTER;
			break;
		default:
			return luaL_error(L, "Align must be left/right/center");
		}
	}
	newlabel(L, &label);
	return 1;
}

static double
readkey(lua_State *L, int idx, int key, double def) {
	lua_pushvalue(L, lua_upvalueindex(key));
	lua_rawget(L, idx);
	double ret = luaL_optnumber(L, -1, def);
	lua_pop(L,1);
	return ret;
}

static void
fill_srt(lua_State *L, struct srt *srt, int idx) {
	if (lua_isnoneornil(L, idx)) {
		srt->offx = 0;
		srt->offy = 0;
		srt->rot = 0;
		srt->scalex = 1024;
		srt->scaley = 1024;
		return;
	}
	luaL_checktype(L,idx,LUA_TTABLE);
	double x = readkey(L, idx, SRT_X, 0);
	double y = readkey(L, idx, SRT_Y, 0);
	double scale = readkey(L, idx, SRT_SCALE, 0);
	double sx;
	double sy;
	double rot = readkey(L, idx, SRT_ROT, 0);
	if (scale > 0) {
		sx = sy = scale;
	} else {
		sx = readkey(L, idx, SRT_SX, 1);
		sy = readkey(L, idx, SRT_SY, 1);
	}
	srt->offx = x*SCREEN_SCALE;
	srt->offy = y*SCREEN_SCALE;
	srt->scalex = sx*1024;
	srt->scaley = sy*1024;
	srt->rot = rot * (1024.0 / 360.0);
}

static int
lgenoutline(lua_State *L) {
  label_gen_outline(lua_toboolean(L, 1));
  return 0;
}

static int
lscissor_pop(lua_State *L) {
	int scissor = (int)luaL_checkinteger(L,1);
	int i;
	for (i=0;i<scissor;i++) {
		scissor_pop();
	}
	return 0;
}

static const char * srt_key[] = {
	"x",
	"y",
	"sx",
	"sy",
	"rot",
	"scale",
};


static void
update_message(struct sprite * s, struct sprite_pack * pack, int parentid, int componentid, int frame) {
	struct pack_animation * ani = (struct pack_animation *)pack->data[parentid];
	if (frame < 0 || frame >= ani->frame_number) {
		return;
	}
	struct pack_frame pframe = ani->frame[frame];
	int i = 0;
	for (; i < pframe.n; i++) {
		if (pframe.part[i].component_id == componentid && pframe.part[i].touchable) {
			s->message = true;
			return;
		}
	}
}

static struct sprite *
newanchor(lua_State *L) {
	int sz = sizeof(struct sprite) + sizeof(struct matrix);
	struct sprite * s = (struct sprite *)lua_newuserdata(L, sz);
	s->parent = NULL;
	s->t.mat = NULL;
	s->t.color = 0xffffffff;
	s->t.additive = 0;
	s->t.program = PROGRAM_DEFAULT;
	s->message = false;
	s->visible = false;	// anchor is invisible by default
	s->name = NULL;
	s->id = ANCHOR_ID;
	s->type = TYPE_ANCHOR;
	s->ps = NULL;
	s->s.mat = (struct matrix *)(s+1);
	matrix_identity(s->s.mat);

	return s;
}

static struct sprite *
newsprite(lua_State *L, struct sprite_pack *pack, int id) {
	if (id == ANCHOR_ID) {
		return newanchor(L);
	}
	int sz = sprite_size(pack, id);
	if (sz == 0) {
		return NULL;
	}
	struct sprite * s = (struct sprite *)lua_newuserdata(L, sz);
	sprite_init(s, pack, id, sz);
	int i;
	for (i=0;;i++) {
		int childid = sprite_component(s, i);
		if (childid < 0)
			break;
		if (i==0) {
			lua_newtable(L);
			lua_pushvalue(L,-1);
			lua_setuservalue(L, -3);	// set uservalue for sprite
		}
		struct sprite *c = newsprite(L, pack, childid);
		c->name = sprite_childname(s, i);
		sprite_mount(s, i, c);
		update_message(c, pack, id, i, s->frame);
		if (c) {
			lua_rawseti(L, -2, i+1);
		}
	}
	if (i>0) {
		lua_pop(L,1);
	}
	return s;
}

/*
	userdata sprite_pack
	integer id

	ret: userdata sprite
 */
static int
lnew(lua_State *L) {
	struct sprite_pack * pack = (struct sprite_pack *)lua_touserdata(L, 1);
	if (pack == NULL) {
		return luaL_error(L, "Need a sprite pack");
	}
	int id = (int)luaL_checkinteger(L, 2);
	struct sprite * s = newsprite(L, pack, id);
	if (s) {
		return 1;
	}
	return 0;
}

static struct sprite *
self(lua_State *L) {
	struct sprite * s = (struct sprite *)lua_touserdata(L, 1);
	if (s == NULL) {
		luaL_error(L, "Need sprite");
	}
	return s;
}

static int
lgetframe(lua_State *L) {
	struct sprite * s = self(L);
	lua_pushinteger(L, s->frame);
	return 1;
}

static int
lsetframe(lua_State *L) {
	struct sprite * s = self(L);
	int frame = (int)luaL_checkinteger(L,2);
	sprite_setframe(s, frame, false);
	return 0;
}

static int
lsetaction(lua_State *L) {
	struct sprite * s = self(L);
	const char * name = lua_tostring(L,2);
	sprite_action(s, name);
	return 0;
}

static int
lgettotalframe(lua_State *L) {
	struct sprite *s = self(L);
	int f = s->total_frame;
	if (f<=0) {
		f = 0;
	}
	lua_pushinteger(L, f);
	return 1;
}

static int
lgetvisible(lua_State *L) {
	struct sprite *s = self(L);
	lua_pushboolean(L, s->visible);
	return 1;
}

static int
lsetvisible(lua_State *L) {
	struct sprite *s = self(L);
	s->visible = lua_toboolean(L, 2);
	return 0;
}

static int
lgetmessage(lua_State *L) {
	struct sprite *s = self(L);
	lua_pushboolean(L, s->message);
	return 1;
}

static int
lsetmessage(lua_State *L) {
	struct sprite *s = self(L);
	s->message = lua_toboolean(L, 2);
	return 0;
}

static int
lsetmat(lua_State *L) {
	struct sprite *s = self(L);
	struct matrix *m = (struct matrix *)lua_touserdata(L, 2);
	if (m == NULL)
		return luaL_error(L, "Need a matrix");
	s->t.mat = &s->mat;
	s->mat = *m;

	return 0;
}

static int
lgetmat(lua_State *L) {
	struct sprite *s = self(L);
	if (s->t.mat == NULL) {
		s->t.mat = &s->mat;
		matrix_identity(&s->mat);
	}
	lua_pushlightuserdata(L, s->t.mat);
	return 1;
}

static int
lgetwmat(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type == TYPE_ANCHOR) {
		lua_pushlightuserdata(L, s->s.mat);
		return 1;
	}
	return luaL_error(L, "Only anchor can get world matrix");
}

static int
lgetwpos(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type == TYPE_ANCHOR) {
		struct matrix* mat = s->s.mat;
		lua_pushnumber(L,mat->m[4] /(float)SCREEN_SCALE);
		lua_pushnumber(L,mat->m[5] /(float)SCREEN_SCALE);
		return 2;
	} else {
		struct srt srt;
		fill_srt(L,&srt,2);
		struct sprite *t = (struct sprite *)lua_touserdata(L, 3);
		if (t == NULL) {
			luaL_error(L, "Need target sprite");
	}

		int pos[2];
		if (sprite_pos(s, &srt, t, pos) == 0) {
			lua_pushinteger(L, pos[0]);
			lua_pushinteger(L, pos[1]);
			return 2;
		} else {
			return 0;
		}
	}
	return luaL_error(L, "Only anchor can get world matrix");
}

static int
lsetprogram(lua_State *L) {
	struct sprite *s = self(L);
	if (lua_isnoneornil(L,2)) {
		s->t.program = PROGRAM_DEFAULT;
	} else {
		s->t.program = (int)luaL_checkinteger(L,2);
	}
	return 0;
}

static int
lsetscissor(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type != TYPE_PANNEL) {
		return luaL_error(L, "Only pannel can set scissor");
	}
	s->data.scissor = lua_toboolean(L,2);
	return 0;
}

static int
lgetscissor(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type == TYPE_PANNEL) {
		lua_pushboolean(L, s->data.scissor);
		return 1;
	}
	return luaL_error(L, "Only pannel can get scissor");
}

static int
lgetname(lua_State *L) {
	struct sprite *s = self(L);
	if (s->name == NULL)
		return 0;
	lua_pushstring(L, s->name);
	return 1;
}

static int
lgettype(lua_State *L) {
	struct sprite *s = self(L);
	lua_pushinteger(L, s->type);
	return 1;
}

static int
lgetparentname(lua_State *L) {
	struct sprite *s = self(L);
	if (s->parent == NULL)
		return 0;
	lua_pushstring(L, s->parent->name);
	return 1;
}

static int
lhasparent(lua_State *L) {
	struct sprite *s = self(L);
	lua_pushboolean(L, s->parent != NULL);
	return 1;
}

static int
lsettext(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type != TYPE_LABEL) {
		return luaL_error(L, "Only label can set rich text");
	}
	if (lua_isnoneornil(L, 2)) {
		s->data.rich_text = NULL;
		lua_pushnil(L);
		lua_setuservalue(L,1);
		return 0;
	}
  if (lua_isstring(L, 2)) {
    s->data.rich_text = (struct rich_text*)lua_newuserdata(L, sizeof(struct rich_text));
    s->data.rich_text->text = lua_tostring(L, 2);
    s->data.rich_text->count = 0;
		s->data.rich_text->fields = NULL;

		lua_createtable(L, 2, 0);
		lua_pushvalue(L, 2);
	lua_rawseti(L, -2, 1);
		lua_pushvalue(L, 3);
		lua_rawseti(L, -2, 2);
	lua_setuservalue(L, 1);
	return 0;
}

  s->data.rich_text = NULL;
  if (!lua_istable(L, 2) || lua_rawlen(L, 2) != 2) {
    return luaL_error(L, "rich text must has a table with two items");
  }
  
  lua_rawgeti(L, 2, 1);
  const char *txt = luaL_checkstring(L, -1);
  lua_pop(L, 1);
  
  lua_rawgeti(L, 2, 2);
	int cnt = lua_rawlen(L, -1);
  lua_pop(L, 1);
  
	struct rich_text *rich = (struct rich_text*)lua_newuserdata(L, sizeof(struct rich_text));
	
	rich->text = txt;
  rich->count = cnt;
	int size = cnt * sizeof(struct label_field);
	rich->fields = (struct label_field*)lua_newuserdata(L, size);

	struct label_field *fields = rich->fields;
	int i;
  lua_rawgeti(L, 2, 2);
	for (i=0; i<cnt; i++) {
		lua_rawgeti(L, -1, i+1);
		if (!lua_istable(L,-1)) {
			return luaL_error(L, "rich text unit must be table");
		}

		lua_rawgeti(L, -1, 1);  //start
		((struct label_field*)(fields+i))->start = luaL_checkinteger(L, -1);
		lua_pop(L, 1);
    
    lua_rawgeti(L, -1, 2);  //end
		((struct label_field*)(fields+i))->end = luaL_checkinteger(L, -1);
    lua_pop(L, 1);

		lua_rawgeti(L, -1, 3);  //color
		((struct label_field*)(fields+i))->color = luaL_checkunsigned(L, -1); 
		lua_pop(L, 1);

		//extend here

		lua_pop(L, 1);
	}
  lua_pop(L, 1);

	lua_createtable(L,3,0);
	lua_pushvalue(L, 3);
	lua_rawseti(L, -2, 1);
	lua_pushvalue(L, 4);
	lua_rawseti(L, -2, 2);
	lua_rawgeti(L, 2, 1);
	lua_rawseti(L, -2, 3);
	lua_setuservalue(L, 1);

	s->data.rich_text = rich;
	return 0;
}

static int
lgettext(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type != TYPE_LABEL) {
		return luaL_error(L, "Only label can get text");
	}
  if (s->data.rich_text) {
    lua_pushstring(L, s->data.rich_text->text);
    return 1;
  }
		return 0;
	}

static int
lgetcolor(lua_State *L) {
	struct sprite *s = self(L);
    if (s->type != TYPE_LABEL)
    {
	lua_pushunsigned(L, s->t.color);
    }
    else
    {
        lua_pushunsigned(L, label_get_color(s->s.label, &s->t));
    }
	return 1;
}

static int
lsetcolor(lua_State *L) {
	struct sprite *s = self(L);
	uint32_t color = luaL_checkunsigned(L,2);
	s->t.color = color;
	return 0;
}

static int
lsetalpha(lua_State *L) {
	struct sprite *s = self(L);
	uint8_t alpha = luaL_checkunsigned(L, 2);
	s->t.color = (s->t.color >> 8) | (alpha << 24);
	return 0;
}

static int
lgetalpha(lua_State *L) {
	struct sprite *s = self(L);
	lua_pushunsigned(L, s->t.color >> 24);
	return 1;
}

static int
lgetadditive(lua_State *L) {
	struct sprite *s = self(L);
	lua_pushunsigned(L, s->t.additive);
	return 1;
}

static int
lsetadditive(lua_State *L) {
	struct sprite *s = self(L);
	uint32_t additive = luaL_checkunsigned(L,2);
	s->t.additive = additive;
	return 0;
}

static void
lgetter(lua_State *L) {
	luaL_Reg l[] = {
		{"frame", lgetframe},
		{"frame_count", lgettotalframe },
		{"visible", lgetvisible },
		{"name", lgetname },
		{"type", lgettype },
		{"text", lgettext},
		{"color", lgetcolor },
		{"alpha", lgetalpha },
		{"additive", lgetadditive },
		{"message", lgetmessage },
		{"matrix", lgetmat },
		{"world_matrix", lgetwmat },
		{"parent_name", lgetparentname },
		{"has_parent", lhasparent },
		{"scissor", lgetscissor },
		{NULL, NULL},
	};
	luaL_newlib(L,l);
}

static void
lsetter(lua_State *L) {
	luaL_Reg l[] = {
		{"frame", lsetframe},
		{"action", lsetaction},
		{"ani", lsetaction},
		{"visible", lsetvisible},
		{"matrix" , lsetmat},
		{"text", lsettext},
		{"color", lsetcolor},
		{"alpha", lsetalpha},
		{"additive", lsetadditive },
		{"message", lsetmessage },
		{"program", lsetprogram },
		{"scissor", lsetscissor },
		{NULL, NULL},
	};
	luaL_newlib(L,l);
}

static int
lfetch(lua_State *L) {
	struct sprite *s = self(L);
	const char * name = luaL_checkstring(L,2);
	int index = sprite_child(s, name);
	if (index < 0)
		return 0;
	lua_getuservalue(L, 1);
	lua_rawgeti(L, -1, index+1);

	return 1;
}

static int
lfetch_by_index(lua_State *L) {
  struct sprite *s = self(L);
  if (s->type != TYPE_ANIMATION) {
    return luaL_error(L, "Only animation can fetch by index");
  }
  int index = (int)luaL_checkinteger(L, 2);
  struct pack_animation *ani = s->s.ani;
  if (index < 0 || index >= ani->component_number) {
    return luaL_error(L, "Component index out of range:%d", index);
  }
  
  lua_getuservalue(L, 1);
  lua_rawgeti(L, -1, index+1);
  
  return 1;
}

static int
ldetach(lua_State *L) {
	struct sprite *s = self(L);
	struct sprite * child = (struct sprite *)lua_touserdata(L, 2);
	if (child->parent != s) {
		return luaL_error(L, "Only child can be detached");
	}

	struct sprite_trans temp;
	struct matrix temp_matrix;
	struct sprite_trans *trans = sprite_complete_trans(child, &temp, &temp_matrix);

	if (trans) {
		child->t = *trans;
		child->t.mat = &child->mat;
		child->mat = *trans->mat;
	}

	int index = sprite_child_index(s, child);
	sprite_mount(s, index, NULL);
	lua_getuservalue(L, 1);
	lua_pushnil(L);
	lua_rawseti(L, -2, index+1);
	return 0;
}

static int
lmount(lua_State *L) {
	struct sprite *s = self(L);
	const char * name = luaL_checkstring(L,2);
	int index = sprite_child(s, name);
	if (index < 0) {
		return luaL_error(L, "No child name %s", name);
	}
	lua_getuservalue(L, 1);
	struct sprite * child = (struct sprite *)lua_touserdata(L, 3);
	if (child == NULL) {
		sprite_mount(s, index, NULL);
		lua_pushnil(L);
		lua_rawseti(L, -2, index+1);
	} else {
		if (child->parent) {
			struct sprite* p = child->parent;
			sprite_mount(p, index, NULL);
			//return luaL_error(L, "Can't mount sprite %p twice,pre parent:%p: %s", child,child->parent,child->name);
		}
		sprite_mount(s, index, child);
		lua_pushvalue(L, 3);
		lua_rawseti(L, -2, index+1);
	}
	return 0;
}

static int
lsprite_ptr(lua_State *L) {
	struct sprite *s = self(L);
	lua_pushlightuserdata(L, s);

	return 1;
}

/*
	userdata sprite
	table { .x .y .sx .sy .rot }
 */
static int
ldraw(lua_State *L) {
	struct sprite *s = self(L);
	struct srt srt;

	fill_srt(L,&srt,2);
	sprite_draw(s, &srt);
	return 0;
}

static int
laabb(lua_State *L) {
	struct sprite *s = self(L);
	struct srt srt;
	fill_srt(L,&srt,2);
	int aabb[4];
	sprite_aabb(s, &srt, aabb);
	int i;
	for (i=0;i<4;i++) {
		lua_pushinteger(L, aabb[i]);
	}
	return 4;
}

static int
ltext_size(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type != TYPE_LABEL) {
		return luaL_error(L, "Ony label can get label_size");
	}
	int width = 0, height = 0;
  if (s->data.rich_text != NULL)
      label_size(s->data.rich_text->text, s->s.label, &width, &height);
	lua_pushinteger(L, width);
	lua_pushinteger(L, height);
    lua_pushinteger(L, s->s.label->size);
	return 3;
}

static int
lchild_visible(lua_State *L) {
	struct sprite *s = self(L);
	const char * name = luaL_checkstring(L,2);
	lua_pushboolean(L, sprite_child_visible(s, name));
	return 1;
}

static int
lchildren_name(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type != TYPE_ANIMATION)
		return 0;
	int i;
	int cnt=0;
	struct pack_animation * ani = s->s.ani;
	for (i=0;i<ani->component_number;i++) {
		if (ani->component[i].name != NULL) {
			lua_pushstring(L, ani->component[i].name);
			cnt++;
		}
	}
	return cnt;
}

static int
lchildren(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type != TYPE_ANIMATION)
		return 0;
	int i;
	lua_getuservalue(L, 1);
	lua_newtable(L);
	struct pack_animation * ani = s->s.ani;
	for (i=0;i<ani->component_number;i++) {
		lua_rawgeti(L, -2, i+1);
		lua_rawseti(L, -2, i+1);
	}
	return 1;
}

static int
lset_anchor_particle(lua_State *L) {
	struct sprite *s = self(L);
	if (s->type != TYPE_ANCHOR)
		return luaL_error(L, "need a anchor");
	s->ps = (struct particle_system*)lua_touserdata(L, 2);
	struct sprite *p = (struct sprite *)lua_touserdata(L, 3);
	if (p==NULL)
		return luaL_error(L, "need a sprite");
	s->data.mask = p->s.pic;

	return 0;
}

static int
lmatrix_multi_draw(lua_State *L) {
	struct sprite *s = self(L);
	int cnt = (int)luaL_checkinteger(L,3);
	if (cnt == 0)
		return 0;
	luaL_checktype(L,4,LUA_TTABLE);
	luaL_checktype(L,5,LUA_TTABLE);
	if (lua_rawlen(L, 4) < cnt) {
		return luaL_error(L, "matrix length must less then particle count");
	}
	if (lua_rawlen(L, 5) < cnt) {
		return luaL_error(L, "color length must less then particle count");
	}

	struct matrix *mat = (struct matrix *)lua_touserdata(L, 2);

	if (s->t.mat == NULL) {
		s->t.mat = &s->mat;
		matrix_identity(&s->mat);
	}
	struct matrix *parent_mat = s->t.mat;
	uint32_t parent_color = s->t.color;

	int i;
	if (mat) {
		struct matrix tmp;
		for (i = 0; i < cnt; i++) {
			lua_rawgeti(L, 4, i+1);
			lua_rawgeti(L, 5, i+1);
			struct matrix *m = (struct matrix *)lua_touserdata(L, -2);
			matrix_mul(&tmp, m, mat);
			s->t.mat = &tmp;
			s->t.color = (uint32_t)lua_tounsigned(L, -1);
			lua_pop(L, 2);

			sprite_draw(s, NULL);
		}
	} else {
		for (i = 0; i < cnt; i++) {
			lua_rawgeti(L, 4, i+1);
			lua_rawgeti(L, 5, i+1);
			struct matrix *m = (struct matrix *)lua_touserdata(L, -2);
			s->t.mat = m;
			s->t.color = (uint32_t)lua_tounsigned(L, -1);
			lua_pop(L, 2);

			sprite_draw(s, NULL);
		}
	}
	
	s->t.mat = parent_mat;
	s->t.color = parent_color;

	return 0;
}

static int
lmulti_draw(lua_State *L) {
	struct sprite *s = self(L);
	int cnt = (int)luaL_checkinteger(L,3);
	if (cnt == 0)
		return 0;
    int n = lua_gettop(L);
	luaL_checktype(L,4,LUA_TTABLE);
	luaL_checktype(L,5,LUA_TTABLE);
	if (lua_rawlen(L, 4) < cnt) {
		return luaL_error(L, "matrix length less then particle count");
	}
    if (n == 6) {
        luaL_checktype(L,6,LUA_TTABLE);
        if (lua_rawlen(L, 6) < cnt) {
            return luaL_error(L, "additive length less then particle count");
        }
    }
	struct srt srt;
	fill_srt(L, &srt, 2);

	if (s->t.mat == NULL) {
		s->t.mat = &s->mat;
		matrix_identity(&s->mat);
	}
	struct matrix *parent_mat = s->t.mat;
	uint32_t parent_color = s->t.color;

	int i;
    if (n == 5) {
        for (i = 0; i < cnt; i++) {
            lua_rawgeti(L, 4, i+1);
            lua_rawgeti(L, 5, i+1);
            s->t.mat = (struct matrix *)lua_touserdata(L, -2);
            s->t.color = (uint32_t)lua_tounsigned(L, -1);
            lua_pop(L, 2);
            
            sprite_draw_as_child(s, &srt, parent_mat, parent_color);
        }
    }else {
        for (i = 0; i < cnt; i++) {
            lua_rawgeti(L, 4, i+1);
            lua_rawgeti(L, 5, i+1);
            lua_rawgeti(L, 6, i+1);
            s->t.mat = (struct matrix *)lua_touserdata(L, -3);
            s->t.color = (uint32_t)lua_tounsigned(L, -2);
            s->t.additive = (uint32_t)lua_tounsigned(L, -1);
            lua_pop(L, 3);
            
            sprite_draw_as_child(s, &srt, parent_mat, parent_color);
        }
    }

	s->t.mat = parent_mat;
	s->t.color = parent_color;

	return 0;
}

static struct sprite *
lookup(lua_State *L, struct sprite * spr) {
	int i;
	struct sprite * root = (struct sprite *)lua_touserdata(L, -1);
	lua_getuservalue(L,-1);
	for (i=0;sprite_component(root, i)>=0;i++) {
		struct sprite * child = root->data.children[i];
		if (child) {
			lua_rawgeti(L, -1, i+1);
			if (child == spr) {
				lua_replace(L,-2);
				return child;
			} else {
				lua_pop(L,1);
			}
		}
	}
	lua_pop(L,1);
	return NULL;
}

static int
unwind(lua_State *L, struct sprite *root, struct sprite *spr) {
	int n = 0;
	while (spr) {
		if (spr == root) {
			return n;
		}
		++n;
		lua_checkstack(L,3);
		lua_pushlightuserdata(L, spr);
		spr = spr->parent;
	}
	return -1;
}

static int
ltest(lua_State *L) {
	struct sprite *s = self(L);
	struct srt srt;
	fill_srt(L,&srt,4);
	float x = luaL_checknumber(L, 2);
	float y = luaL_checknumber(L, 3);
	struct sprite * m = sprite_test(s, &srt, x*SCREEN_SCALE, y*SCREEN_SCALE);
	if (m == NULL)
		return 0;
	if (m==s) {
		lua_settop(L,1);
		return 1;
	}
	lua_settop(L,1);
	int depth = unwind(L, s , m);
	if (depth < 0) {
		return luaL_error(L, "Unwind an invalid sprite");
	}
	int i;
	lua_pushvalue(L,1);
	for (i=depth+1;i>1;i--) {
		struct sprite * tmp = (struct sprite *)lua_touserdata(L, i);
		tmp = lookup(L, tmp);
		if (tmp == NULL) {
			return luaL_error(L, "find an invalid sprite");
		}
		lua_replace(L, -2);
	}

	return 1;
}

static int
lps(lua_State *L) {
	struct sprite *s = self(L);
	struct matrix *m = &s->mat;
	if (s->t.mat == NULL) {
		matrix_identity(m);
		s->t.mat = m;
	}
	int *mat = m->m;
	int n = lua_gettop(L);
	int x,y,scale;
	switch (n) {
	case 4:
		// x,y,scale
		x = luaL_checknumber(L,2) * SCREEN_SCALE;
		y = luaL_checknumber(L,3) * SCREEN_SCALE;
		scale = luaL_checknumber(L,4) * 1024;
		mat[0] = scale;
		mat[1] = 0;
		mat[2] = 0;
		mat[3] = scale;
		mat[4] = x;
		mat[5] = y;
		break;
	case 3:
		// x,y
		x = luaL_checknumber(L,2) * SCREEN_SCALE;
		y = luaL_checknumber(L,3) * SCREEN_SCALE;
		mat[4] = x;
		mat[5] = y;
		break;
	case 2:
		// scale
		scale = luaL_checknumber(L,2) * 1024;
		mat[0] = scale;
		mat[1] = 0;
		mat[2] = 0;
		mat[3] = scale;
		break;
	default:
		return luaL_error(L, "Invalid parm");
	}
	return 0;
}

static int
lsr(lua_State *L) {
	struct sprite *s = self(L);
	struct matrix *m = &s->mat;
	if (s->t.mat == NULL) {
		matrix_identity(m);
		s->t.mat = m;
	}
	int sx=1024,sy=1024,r=0;
	int n = lua_gettop(L);
	switch (n) {
	case 4:
		// sx,sy,rot
		r = luaL_checknumber(L,4) * (1024.0 / 360.0);
		// go through
	case 3:
		// sx, sy
		sx = luaL_checknumber(L,2) * 1024;
		sy = luaL_checknumber(L,3) * 1024;
		break;
	case 2:
		// rot
		r = luaL_checknumber(L,2) * (1024.0 / 360.0);
		break;
	}
	matrix_sr(m, sx, sy, r);

	return 0;
}

static int
ltrans_pos(lua_State *L) {
	struct sprite * s = self(L);
	struct sprite * ts = (struct sprite *)lua_touserdata(L, 2);
	struct matrix *m = &s->mat;
	if (s->t.mat == NULL) {
		matrix_identity(m);
		s->t.mat = m;
	}
	int *mat1 = m->m;
	m = &ts->mat;
	if (ts->t.mat == NULL) {
		matrix_identity(m);
		ts->t.mat = m;
	}
	int *mat2 = m->m;
	mat1[4] = mat2[4];
	mat1[5] = mat2[5];

	return 0;
}

static int
lrecursion_frame(lua_State *L) {
	struct sprite * s = self(L);
	int frame = (int)luaL_checkinteger(L,2);
	int f = sprite_setframe(s, frame, true);
	lua_pushinteger(L, f);
	return 1;
}

static int
lenable_visible_test(lua_State *L) {
    bool enable = lua_toboolean(L, 1);
    enable_screen_visible_test(enable);
    return 0;
}

static int
ldynamic_tex(lua_State *L) {
	struct sprite * s = self(L);
	if (s->type != TYPE_PICTURE) {
		return luaL_error(L, "Only picture can set dynamic");
	}
	struct pack_picture *pic = s->s.pic;
	int i;
	int n = lua_gettop(L) - 1;
	for (i=0;i<pic->n && i<n;i++) {
		s->data.dynamic_tex[i] = luaL_checkinteger(L,i+2);
	}
	const char *err = sprite_dynamic_tex(s);
	if (err)
		return luaL_error(L, err);
	return 0;
}

struct cover_good {
	int dx;
	int dy;
	int vol;
	int width;
	int height;
	int scale;
	GLubyte rgba[4];
};

struct cover {
	int widthGrid;
	int heightGrid;
	int grid_pixels;
	int cache_tex;
	char * eb;
	int eb_sz;
	struct cover_good * goods[1];
};

static int
lnew_cover(lua_State *L) {
	int widthGrid = lua_tointeger(L,1);
	int heightGrid = lua_tointeger(L,2);
	int grid_pixels = lua_tointeger(L,3);
	int cache_tex = lua_tointeger(L,4);
	int width = 2 * grid_pixels;
	int height = 2 * grid_pixels;

	const char *err = texture_new_rt(cache_tex,width,height);
	if (err)
		return luaL_error(L, err);

	int sz = sizeof(struct cover) + sizeof(struct cover_good *) * (widthGrid * heightGrid - 1);
	struct cover *c = (struct cover *)lua_newuserdata(L, sz);
	c->widthGrid = widthGrid;
	c->heightGrid = heightGrid;
	c->grid_pixels = grid_pixels;
	c->cache_tex = cache_tex;
	c->eb_sz = sizeof(char)*widthGrid*grid_pixels*heightGrid*grid_pixels;
	c->eb = malloc(c->eb_sz);
	memset(c->eb,0,c->eb_sz);
	int i;
	for (i=0;i<widthGrid * heightGrid;i++) {
		c->goods[i] = NULL;
	}
	return 1;
}

static int
ldel_cover(lua_State *L) {
	struct cover * c = (struct cover *)lua_touserdata(L,1);
	if (c->cache_tex != 0)
		texture_unload(c->cache_tex);
	if (c->eb != 0)
		free(c->eb);

	return 0;
}

static int
lcover_addGood(lua_State *L) {
	struct cover * c = (struct cover *)lua_touserdata(L,1);
	struct sprite * good = (struct sprite *)lua_touserdata(L, 2);
	if (good->type != TYPE_PICTURE) {
		return luaL_error(L, "good should be picture");
	}
	int gx = lua_tointeger(L,3);
	int gy = lua_tointeger(L,4);
	int scale = lua_tointeger(L,5);
	int width = scale * c->grid_pixels;
	int height = scale * c->grid_pixels;

	texture_active_rt(c->cache_tex);
	glClearColor(0,0,0,0);
	glClear(GL_COLOR_BUFFER_BIT);

	int i,j;
	float vb[16];
	struct matrix *m = &good->mat;
	if (good->t.mat == NULL) {
		matrix_identity(m);
		good->t.mat = m;
	}
	int *mat = m->m;
	struct pack_picture *pic = good->s.pic;
	shader_program(PROGRAM_PICTURE, good->t.additive);
	for (i=0;i<pic->n;i++) {
		struct pack_quad *q = &pic->rect[i];

		int glid = texture_glid(q->texid);
		if (glid == 0)
			continue;
		shader_texture(glid);
		for (j=0;j<4;j++) {
			int xx = q->screen_coord[j*2+0];
			int yy = q->screen_coord[j*2+1];
			float vx = (xx * mat[0] + yy * mat[2]) / 1024;
			float vy = (xx * mat[1] + yy * mat[3]) / 1024;
			vx = vx / (float)SCREEN_SCALE / (float)c->grid_pixels;
			vy = -vy / (float)SCREEN_SCALE / (float)c->grid_pixels;

			float tx = q->texture_coord[j*2+0];
			float ty = q->texture_coord[j*2+1];
			texture_coord(q->texid, &tx, &ty);

			vb[j*4+0] = vx;
			vb[j*4+1] = vy;
			vb[j*4+2] = tx;
			vb[j*4+3] = ty;
		}
		shader_draw(vb, good->t.color);
	}
	shader_flush();
	int sz = sizeof(struct cover_good) + 4 * sizeof(GLubyte) * (width * height - 1);
	struct cover_good *cg = (struct cover_good *)lua_newuserdata(L, sz);
	memset(cg,0,sz);
	glPixelStorei(GL_PACK_ALIGNMENT,1);
	glReadPixels(0,2*c->grid_pixels-height,width,height,GL_RGBA,GL_UNSIGNED_BYTE,cg->rgba);

	texture_inactive_rt();

	cg->width = width;
	cg->height = height;
	cg->dx = gx * c->grid_pixels;
	cg->dy = gy * c->grid_pixels;
	cg->scale = scale;
	cg->vol = 0;
	for (i=0;i<width * height;i++) {
		if (cg->rgba[4*i+3] != 0)
			cg->vol++;
	}
	for (i=0;i<scale;i++) {
		for (j=0;j<scale;j++) {
			if ((gx+i) < c->widthGrid && (gy+j) < c->heightGrid) {
				int index = (gy+j)*c->widthGrid+(gx+i);
				assert(c->goods[index] == NULL);
				c->goods[index] = cg;
			}
		}
	}

	return 1;
}

static int
lcover_rmGood(lua_State *L) {
	struct cover * c = (struct cover *)lua_touserdata(L,1);
	struct cover_good * cg = (struct cover_good *)lua_touserdata(L, 2);
	int gx = cg->dx / c->grid_pixels;
	int gy = cg->dy / c->grid_pixels;
	int scale = cg->scale;
	int i,j;
	for (i=0;i<scale;i++) {
		for (j=0;j<scale;j++) {
			if ((gx+i) < c->widthGrid && (gy+j) < c->heightGrid)
				c->goods[(gy+j)*c->widthGrid+(gx+i)] = NULL;
		}
	}
	return 0;
}

static int
_draw_point(int x, int y, int height, struct cover * c) {
	if (x < 0 || y < 0)
		return 0;
	int index = x * height + y;
	if (index >= c->eb_sz || c->eb[index]) {
		return 0;
	}
	c->eb[index] = 1;
	float pb[2] = {(float)x,(float)y};
	shader_sketch(pb);
	struct cover_good *cg = NULL;
	int gx = x / c->grid_pixels, gy = y / c->grid_pixels;
	if (gx < c->widthGrid && gy < c->heightGrid)
		cg = c->goods[gy * c->widthGrid + gx];
	if (cg) {
		x -= cg->dx;
		y -= cg->dy;
		int index = (cg->height - y - 1) * cg->width + x;
		assert(index<cg->width*cg->height);
		if (x < cg->width && y < cg->height && cg->rgba[index * 4 + 3] != 0) {
			cg->rgba[index * 4 + 3] = 0;
			cg->vol--;
		}
	}
	return 1;
}

static int
_circle_points(int xc, int yc, int x, int y, int height, struct cover * c) {
	int i,j,cnt = 0;
	int pos[16] = {
	xc+x,yc+y,
    xc-x,yc+y,
    xc+x,yc-y,
    xc-x,yc-y,
    xc+y,yc+x,
    xc-y,yc+x,
    xc+y,yc-x,
    xc-y,yc-x,
	};

	for (i=0;i<8;i++) {
		cnt += _draw_point(pos[2*i+0],pos[2*i+1],height,c);
	}
	return cnt;
}

static int
_draw_circle(int xc, int yc, int min_radius, int max_radius, int height, struct cover * c, int vol_left) {
	int i;
	for (i=min_radius;i<=max_radius;i++) {
		int x = 0;
		int y = i;
		int p = 3-2*y;
		while (x < y) {
			vol_left -= _circle_points(xc,yc,x,y-1,height,c);
			vol_left -= _circle_points(xc,yc,x,y,height,c);
			if (p < 0) {
				p += 4*x+6;
			} else {
				p += 4*(x-y)+10;
				y--;
			}
			x++;
		}
		if (x==y) {
			vol_left -= _circle_points(xc,yc,x,y,height,c);
		}
		if (vol_left <= 0)
			break;
	}
	return vol_left;
}

static int
_cover_erase(int n, float * vb, float radius, int height, struct cover * c, int vol_left) {
	if (vol_left <= 0)
		return vol_left;
	if (n == 2) {
		vol_left = _draw_circle(vb[0],vb[1],0,radius,height,c,vol_left);
	} else {
		float delta_x,delta_y,x,y;
		int dx,dy,steps,dir;
		dx = vb[2] - vb[0];
		dy = vb[3] - vb[1];
		if (abs(dx)>abs(dy)) {
			steps = abs(dx);
			dir = 1;
		}
		else {
			steps = abs(dy);
			dir = -1;
		}
		delta_x = (float)dx/(float)steps;
		delta_y = (float)dy/(float)steps;
		x = vb[0];
		y = vb[1];
		int k,j;
		vol_left = _draw_circle(x,y,0,radius,height,c,vol_left);
		if (vol_left <= 0)
			return vol_left;
		for (k=1;k<=steps;k++) {
			x+=delta_x;
			y+=delta_y;
			if (dir == 1) {
				for (j=radius;j>=(-1)*radius;j--) {
					vol_left -= _draw_point(x,y+j,height,c);
				}
			} else {
				for (j=radius;j>=(-1)*radius;j--) {
					vol_left -= _draw_point(x+j,y,height,c);
				}
			}
			if (vol_left <= 0)
				break;
		}
		if (steps >= 1)
			vol_left = _draw_circle(x,y,0,radius,height,c,vol_left);
	}
	return vol_left;
}

static int
lcover_erase(lua_State *L) {
	int i;
	float vb[4];
	int n = lua_gettop(L) - 4;
	if (n!=2 && n!=4) {
		return luaL_error(L, "Invalid param amount");
	}
	struct sprite * s = self(L);
	if (s->type != TYPE_PICTURE) {
		return luaL_error(L, "Only picture can erase");
	}
	struct cover * c = (struct cover *)lua_touserdata(L,2);
	int vol_left = luaL_checkinteger(L,3);
	float radius = luaL_checknumber(L,4);
	for (i=0;i<n;i++) {
		vb[i] = luaL_checknumber(L,i+5);
	}
	struct pack_picture *pic = s->s.pic;
	int * texid = s->data.dynamic_tex;

	shader_blend(GL_ONE,GL_ZERO);
	for (i=0;i<pic->n;i++) {
		if (texid[i] == -1)
			continue;
		struct pack_quad *q = &pic->rect[i];
		int minx = q->screen_coord[0] / SCREEN_SCALE;
		int miny = q->screen_coord[1] / SCREEN_SCALE;
		int maxx = q->screen_coord[4] / SCREEN_SCALE;
		int maxy = q->screen_coord[5] / SCREEN_SCALE;
		int width = maxx - minx;
		int height = maxy - miny;
		const char *err = texture_active_rt(texid[i]);
		if (err)
			return luaL_error(L, err);
		float screen_size[2] = {(float)width, (float)height};
		shader_program_sketch(0x00000000,screen_size);
		vol_left = _cover_erase(n,vb,radius,height,c,vol_left);
		texture_inactive_rt();
	}
	shader_defaultblend();

	lua_pushinteger(L, vol_left);
	return 1;
}

static int
lcover_checkGood(lua_State *L) {
	struct cover_good * cg = (struct cover_good *)lua_touserdata(L, 1);
	if (cg->vol > 0) {
		lua_pushboolean(L,false);
	} else {
		lua_pushboolean(L,true);
	}

	return 1;
}

static void
lmethod(lua_State *L) {
	luaL_Reg l[] = {
		{ "fetch", lfetch },
    { "fetch_by_index", lfetch_by_index },
		{ "mount", lmount },
		{ "detach", ldetach },
		{ "sprite_ptr", lsprite_ptr },
		{ "children", lchildren },
		{ "dynamic_tex", ldynamic_tex },
		{ "trans_pos", ltrans_pos },
		{ NULL, NULL },
	};
	luaL_newlib(L,l);

	int i;
	int nk = sizeof(srt_key)/sizeof(srt_key[0]);
	for (i=0;i<nk;i++) {
		lua_pushstring(L, srt_key[i]);
	}
	luaL_Reg l2[] = {
		{ "ps", lps },
		{ "sr", lsr },
		{ "draw", ldraw },
		{ "recursion_frame", lrecursion_frame },
		{ "multi_draw", lmulti_draw },
		{ "matrix_multi_draw", lmatrix_multi_draw },
		{ "test", ltest },
		{ "aabb", laabb },
		{ "text_size", ltext_size},
		{ "child_visible", lchild_visible },
		{ "children_name", lchildren_name },
		{ "world_pos", lgetwpos },
		{ "anchor_particle", lset_anchor_particle },
		{ NULL, NULL, },
	};
	luaL_setfuncs(L,l2,nk);
}

int
ejoy2d_sprite(lua_State *L) {
	luaL_Reg l[] ={
		{ "new", lnew },
		{ "label", lnewlabel },
		{ "label_gen_outline", lgenoutline },
        { "enable_visible_test", lenable_visible_test },
		{ "scissor_pop", lscissor_pop },
		{ "cover", lnew_cover },
		{ "del_cover", ldel_cover },
		{ "cover_addGood", lcover_addGood },
		{ "cover_rmGood", lcover_rmGood },
		{ "cover_checkGood", lcover_checkGood },
		{ "cover_erase", lcover_erase },
		{ NULL, NULL },
	};
	luaL_newlib(L,l);

	lmethod(L);
	lua_setfield(L, -2, "method");
	lgetter(L);
	lua_setfield(L, -2, "get");
	lsetter(L);
	lua_setfield(L, -2, "set");

	return 1;
}
