LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := window

LOCAL_MODULE_FILENAME := window

LOCAL_SRC_FILES := lua-window.c \
  ejoy2d/shader.c ejoy2d/lshader.c ejoy2d/ejoy2dgame.c ejoy2d/fault.c ejoy2d/screen.c \
  ejoy2d/texture.c ejoy2d/ppm.c ejoy2d/spritepack.c ejoy2d/sprite.c ejoy2d/lsprite.c \
  ejoy2d/matrix.c ejoy2d/lmatrix.c ejoy2d/dfont.c ejoy2d/label.c ejoy2d/particle.c \
  ejoy2d/lparticle.c ejoy2d/scissor.c \
  ejoy2d/android/window.c ejoy2d/android/winfont.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua /home/wyao/android-ndk-r9d/sources/android/native_app_glue

LOCAL_LDLIBS    := -lGLESv2 \
                -lEGL \
                -llog \
                -lz \
                -landroid
				
LOCAL_STATIC_LIBRARIES := freetype2 png

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := skynet

LOCAL_MODULE_FILENAME := skynet

LOCAL_SRC_FILES := lua-skynet.c lua-seri.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src $(LOCAL_PATH)/../service-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := socketdriver

LOCAL_MODULE_FILENAME := socketdriver

LOCAL_SRC_FILES := lua-socket.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src $(LOCAL_PATH)/../service-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := int64

LOCAL_MODULE_FILENAME := int64

LOCAL_SRC_FILES := ../3rd/lua-int64/int64.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := bson

LOCAL_MODULE_FILENAME := bson

LOCAL_SRC_FILES := lua-bson.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := mongo

LOCAL_MODULE_FILENAME := mongo

LOCAL_SRC_FILES := lua-mongo.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := md5

LOCAL_MODULE_FILENAME := md5

LOCAL_SRC_FILES := ../3rd/lua-md5/md5.c ../3rd/lua-md5/md5lib.c ../3rd/lua-md5/compat-5.2.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := netpack

LOCAL_MODULE_FILENAME := netpack

LOCAL_SRC_FILES := lua-netpack.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := clientsocket

LOCAL_MODULE_FILENAME := clientsocket

LOCAL_SRC_FILES := lua-clientsocket.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := memory

LOCAL_MODULE_FILENAME := memory

LOCAL_SRC_FILES := lua-memory.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := profile

LOCAL_MODULE_FILENAME := profile

LOCAL_SRC_FILES := lua-profile.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := multicast

LOCAL_MODULE_FILENAME := multicast

LOCAL_SRC_FILES := lua-multicast.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := cluster

LOCAL_MODULE_FILENAME := cluster

LOCAL_SRC_FILES := lua-cluster.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := crypt

LOCAL_MODULE_FILENAME := crypt

LOCAL_SRC_FILES := lua-crypt.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := sharedata

LOCAL_MODULE_FILENAME := sharedata

LOCAL_SRC_FILES := lua-sharedata.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := stm

LOCAL_MODULE_FILENAME := stm

LOCAL_SRC_FILES := lua-stm.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../3rd/lua $(LOCAL_PATH)/../skynet-src

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

$(call import-module,3rd/lua)
$(call import-module,3rd/freetype2/prebuilt/android)
$(call import-module,3rd/png/prebuilt/android)

