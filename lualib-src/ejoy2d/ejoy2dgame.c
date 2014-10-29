#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <assert.h>
#include <stdlib.h>

#include "ejoy2dgame.h"
#include "fault.h"
#include "shader.h"
#include "texture.h"
#include "ppm.h"
#include "spritepack.h"
#include "sprite.h"
#include "lmatrix.h"
#include "label.h"
#include "particle.h"

struct game {
	lua_State *L;
};

static struct game *G;


static int
_panic(lua_State *L) {
	const char * err = lua_tostring(L,-1);
	fault("%s", err);
	return 0;
}

#if __ANDROID__
#define OS_STRING "ANDROID"
#else
#define STR_VALUE(arg)	#arg
#define _OS_STRING(name) STR_VALUE(name)
#define OS_STRING _OS_STRING(EJOY2D_OS)
#endif

static int
call(lua_State *L, int n, int r) {
	int err = lua_pcall(L, n, r, 0);
	switch(err) {
	case LUA_OK:
		break;
	case LUA_ERRRUN:
		ejoy2d_handle_error(L, "LUA_ERRRUN", lua_tostring(L,-1));
		fault("!LUA_ERRRUN : %s\n", lua_tostring(L,-1));
		break;
	case LUA_ERRMEM:
		ejoy2d_handle_error(L, "LUA_ERRMEM", lua_tostring(L,-1));
		fault("!LUA_ERRMEM : %s\n", lua_tostring(L,-1));
		break;
	case LUA_ERRERR:
		ejoy2d_handle_error(L, "LUA_ERRERR", lua_tostring(L,-1));
		fault("!LUA_ERRERR : %s\n", lua_tostring(L,-1));
		break;
	case LUA_ERRGCMM:
		ejoy2d_handle_error(L, "LUA_ERRGCMM", lua_tostring(L,-1));
		fault("!LUA_ERRGCMM : %s\n", lua_tostring(L,-1));
		break;
	default:
		ejoy2d_handle_error(L, "UnknownError", "Unknown");
		fault("!Unknown Lua error: %d\n", err);
		break;
	}
	return err;
}

void
ejoy2d_game(lua_State *L) {
	if (G) return;
	G = (struct game *)malloc(sizeof(*G));
	G->L = L;

	lua_pushliteral(L, OS_STRING);
	lua_setglobal(L , "OS");

	lua_atpanic(L, _panic);

	luaL_requiref(L, "ejoy2d.shader.c", ejoy2d_shader, 0);
	luaL_requiref(L, "ejoy2d.ppm", ejoy2d_ppm, 0);
	luaL_requiref(L, "ejoy2d.spritepack.c", ejoy2d_spritepack, 0);
	luaL_requiref(L, "ejoy2d.sprite.c", ejoy2d_sprite, 0);
	luaL_requiref(L, "ejoy2d.matrix.c", ejoy2d_matrix, 0);
	luaL_requiref(L, "ejoy2d.particle.c", ejoy2d_particle, 0);
}

void
ejoy2d_game_exit() {
	label_unload();
	texture_exit();
	shader_unload();
}

lua_State *
ejoy2d_game_lua() {
	return G->L;
}

void 
ejoy2d_handle_error(lua_State *L, const char *err_type, const char *msg) {
	lua_getfield(L, LUA_REGISTRYINDEX, EJOY_HANDLE_ERROR);
	lua_pushstring(L, err_type);
	lua_pushstring(L, msg);
	int err = lua_pcall(L, 2, 0, 0);
	switch(err) {
	case LUA_OK:
		break;
	case LUA_ERRRUN:
		fault("!LUA_ERRRUN : %s\n", lua_tostring(L,-1));
		break;
	case LUA_ERRMEM:
		fault("!LUA_ERRMEM : %s\n", lua_tostring(L,-1));
		break;
	case LUA_ERRERR:
		fault("!LUA_ERRERR : %s\n", lua_tostring(L,-1));
		break;
	case LUA_ERRGCMM:
		fault("!LUA_ERRGCMM : %s\n", lua_tostring(L,-1));
		break;
	default:
		fault("!Unknown Lua error: %d\n", err);
		break;
	}
}

void
ejoy2d_game_drawframe() {
	lua_getfield(G->L, LUA_REGISTRYINDEX, EJOY_DRAWFRAME);
	call(G->L, 0, 0);
	shader_flush();
	label_flush();
	//int cnt = drawcall_count();
	//printf("-> %d\n", cnt);
}

int
ejoy2d_game_touch(int id, float x, float y, int status) {
    int disable_gesture = 0;
	lua_getfield(G->L, LUA_REGISTRYINDEX, EJOY_TOUCH);
	lua_pushnumber(G->L, x);
	lua_pushnumber(G->L, y);
	lua_pushinteger(G->L, status+1);
	lua_pushinteger(G->L, id);
	int err = call(G->L, 4, 1);
  if (err == LUA_OK) {
      disable_gesture = lua_toboolean(G->L, -1);
  }
  return disable_gesture;
}

void
ejoy2d_game_gesture(int type,
                    double x1, double y1,double x2,double y2, int s) {
    lua_getfield(G->L, LUA_REGISTRYINDEX, EJOY_GESTURE);
    lua_pushnumber(G->L, type);
    lua_pushnumber(G->L, x1);
    lua_pushnumber(G->L, y1);
    lua_pushnumber(G->L, x2);
    lua_pushnumber(G->L, y2);
    lua_pushinteger(G->L, s);
    call(G->L, 6, 0);
}

void
ejoy2d_game_message(int id_, const char* state, const char* data, lua_Number n) {
  lua_State *L = G->L;
  lua_getfield(L, LUA_REGISTRYINDEX, EJOY_MESSAGE);
  lua_pushnumber(L, id_);
  lua_pushstring(L, state);
  lua_pushstring(L, data);
	lua_pushnumber(L, n);
  call(L, 4, 0);
}

void
ejoy2d_game_resume(){
    lua_State *L = G->L;
    lua_getfield(L, LUA_REGISTRYINDEX, EJOY_RESUME);
    call(L, 0, 0);
}

void
ejoy2d_game_pause() {
	lua_State *L = G->L;
	lua_getfield(L, LUA_REGISTRYINDEX, EJOY_PAUSE);
	call(L, 0, 0);
}

void
ejoy2d_game_wininit() {
	lua_getfield(G->L, LUA_REGISTRYINDEX, EJOY_WIN_INIT);
	call(G->L, 0, 0);
}

