#ifndef EJOY_2D_LUASTATE_H
#define EJOY_2D_LUASTATE_H

#include <lua.h>

#define EJOY_DRAWFRAME "EJOY2D_DRAWFRAME"
#define EJOY_TOUCH "EJOY2D_TOUCH"
#define EJOY_GESTURE "EJOY2D_GESTURE"
#define EJOY_MESSAGE "EJOY2D_MESSAGE"
#define EJOY_HANDLE_ERROR "EJOY2D_HANDLE_ERROR"
#define EJOY_RESUME "EJOY2D_RESUME"
#define EJOY_PAUSE "EJOY2D_PAUSE"
#define EJOY_WIN_INIT "EJOY2D_WIN_INIT"

void ejoy2d_game(lua_State *L);
void ejoy2d_game_exit();
lua_State *  ejoy2d_game_lua();
void ejoy2d_handle_error(lua_State *L, const char *err_type, const char *msg);
void ejoy2d_game_start();
void ejoy2d_game_drawframe();
int ejoy2d_game_touch(int id, float x, float y, int status);
void ejoy2d_game_gesture(int type,
                         double x1, double y1, double x2, double y2, int s);
void
ejoy2d_game_message(int id_, const char* state, const char* data, lua_Number n);
void ejoy2d_game_pause();
void ejoy2d_game_resume();
void ejoy2d_game_wininit();


#endif
