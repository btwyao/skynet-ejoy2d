include platform.mk

LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice

SKYNET_BUILD_PATH ?= .

CFLAGS = -g -O0 -Wall -I$(LUA_INC) $(MYCFLAGS)
CFLAGS += -I/usr/include $(shell freetype-config --cflags)

# lua

LUA_STATICLIB := 3rd/lua/liblua.a
LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= 3rd/lua

$(LUA_STATICLIB) :
	cd 3rd/lua && $(MAKE) CC=$(CC) $(PLAT)

# jemalloc 

JEMALLOC_STATICLIB := 3rd/jemalloc/lib/libjemalloc_pic.a
JEMALLOC_INC := 3rd/jemalloc/include/jemalloc

all : jemalloc
	
.PHONY : jemalloc

MALLOC_STATICLIB := $(JEMALLOC_STATICLIB)

$(JEMALLOC_STATICLIB) : 3rd/jemalloc/Makefile
	cd 3rd/jemalloc && $(MAKE) CC=$(CC) 

3rd/jemalloc/autogen.sh :
	git submodule update --init

3rd/jemalloc/Makefile : | 3rd/jemalloc/autogen.sh
	cd 3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --disable-valgrind

jemalloc : $(MALLOC_STATICLIB)

# skynet

CSERVICE = snlua logger gate harbor
LUA_CLIB = skynet socketdriver int64 bson mongo md5 netpack \
  cjson clientsocket memory profile multicast \
  cluster crypt sharedata stm window

SKYNET_SRC = skynet_main.c skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c

WINDOW_SRC = lua-window.c \
  ejoy2d/shader.c ejoy2d/lshader.c ejoy2d/ejoy2dgame.c ejoy2d/fault.c ejoy2d/screen.c \
  ejoy2d/texture.c ejoy2d/ppm.c ejoy2d/spritepack.c ejoy2d/sprite.c ejoy2d/lsprite.c \
  ejoy2d/matrix.c ejoy2d/lmatrix.c ejoy2d/dfont.c ejoy2d/label.c ejoy2d/particle.c \
  ejoy2d/lparticle.c ejoy2d/scissor.c \
  ejoy2d/posix/window.c ejoy2d/posix/winfont.c

all : \
  $(SKYNET_BUILD_PATH)/shoucangjia \
  $(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so) 

$(SKYNET_BUILD_PATH)/shoucangjia : $(foreach v, $(SKYNET_SRC), skynet-src/$(v)) $(LUA_LIB) $(MALLOC_STATICLIB)
	$(CC) $(CFLAGS) -o $@ $^ -Iskynet-src -I$(JEMALLOC_INC) $(LDFLAGS) $(EXPORT) $(SKYNET_LIBS) $(SKYNET_DEFINES)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

$(LUA_CLIB_PATH)/window.so : $(foreach v, $(WINDOW_SRC), lualib-src/$(v)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Ilualib-src

$(LUA_CLIB_PATH)/skynet.so : lualib-src/lua-skynet.c lualib-src/lua-seri.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src -Ilualib-src

$(LUA_CLIB_PATH)/socketdriver.so : lualib-src/lua-socket.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src

$(LUA_CLIB_PATH)/int64.so : 3rd/lua-int64/int64.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ 

$(LUA_CLIB_PATH)/bson.so : lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

$(LUA_CLIB_PATH)/mongo.so : lualib-src/lua-mongo.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src

$(LUA_CLIB_PATH)/md5.so : 3rd/lua-md5/md5.c 3rd/lua-md5/md5lib.c 3rd/lua-md5/compat-5.2.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-md5 $^ -o $@ 

$(LUA_CLIB_PATH)/netpack.so : lualib-src/lua-netpack.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -Iskynet-src -o $@ 

$(LUA_CLIB_PATH)/cjson.so : | $(LUA_CLIB_PATH)
	cd 3rd/lua-cjson && $(MAKE) LUA_INCLUDE_DIR=../../$(LUA_INC) CC=$(CC) CJSON_LDFLAGS="$(SHARED)" && cd ../.. && cp 3rd/lua-cjson/cjson.so $@

$(LUA_CLIB_PATH)/clientsocket.so : lualib-src/lua-clientsocket.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -lpthread

$(LUA_CLIB_PATH)/memory.so : lualib-src/lua-memory.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ 

$(LUA_CLIB_PATH)/profile.so : lualib-src/lua-profile.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ 

$(LUA_CLIB_PATH)/multicast.so : lualib-src/lua-multicast.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ 

$(LUA_CLIB_PATH)/cluster.so : lualib-src/lua-cluster.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ 

$(LUA_CLIB_PATH)/crypt.so : lualib-src/lua-crypt.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ 

$(LUA_CLIB_PATH)/sharedata.so : lualib-src/lua-sharedata.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ 

$(LUA_CLIB_PATH)/stm.so : lualib-src/lua-stm.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ 

clean :
	rm -f $(SKYNET_BUILD_PATH)/shoucangjia $(CSERVICE_PATH)/*.so $(LUA_CLIB_PATH)/*.so

cleanall: clean
	cd 3rd/lua-cjson && $(MAKE) clean
	cd 3rd/jemalloc && $(MAKE) clean
	rm -f $(LUA_STATICLIB)
