#include <lua.h>
#include <lauxlib.h>
#include <stdio.h>

#ifdef __ANDROID__
#include "ejoy2d/android/window.h"
#else
#include "ejoy2d/posix/window.h"
#endif

#include "ejoy2d/ejoy2dgame.h"

static int
linit(lua_State *L) {
	fprintf(stdout, "linit \n");
	ejoy2d_game(L);

	return 0;
}

static int
lwin_init(lua_State *L) {
	fprintf(stdout, "lwin_init \n");
	window_init();

	return 0;
}

static int
linject(lua_State *L) {
	fprintf(stdout, "linject \n");
	static const char * ejoy_callback[] = {
		EJOY_DRAWFRAME,
		EJOY_TOUCH,
		EJOY_GESTURE,
		EJOY_MESSAGE,
		EJOY_HANDLE_ERROR,
		EJOY_RESUME,
		EJOY_WIN_INIT,
	};
	int i;
	for (i=0;i<sizeof(ejoy_callback)/sizeof(ejoy_callback[0]);i++) {
		lua_getfield(L, lua_upvalueindex(1), ejoy_callback[i]);
		if (!lua_isfunction(L,-1)) {
			return luaL_error(L, "%s is not found", ejoy_callback[i]);
		}
		lua_setfield(L, LUA_REGISTRYINDEX, ejoy_callback[i]);
	}

	return 0;
}

static int
lupdate_frame(lua_State *L) {
	window_update_frame();

	return 0;
}

static int
levent_handle(lua_State *L) {
	window_event_handle();

	return 0;
}

static int
lwindow_width(lua_State *L) {
	int w = get_window_width();
	lua_pushinteger(L,w);

	return 1;
}

static int
lwindow_height(lua_State *L) {
	int h = get_window_height();
	lua_pushinteger(L,h);

	return 1;
}

int
luaopen_window_c(lua_State *L) {
	luaL_Reg l[] = {
		{ "init", linit },
		{ "win_init", lwin_init },
		{ "inject", linject },
		{ "update_frame", lupdate_frame },
		{ "event_handle", levent_handle },
		{ "window_width", lwindow_width },
		{ "window_height", lwindow_height },
		{ NULL, NULL },
	};
	luaL_checkversion(L);
	luaL_newlib(L,l);
	lua_pushvalue(L,-1);
	luaL_setfuncs(L,l,1);

	return 1;
}
