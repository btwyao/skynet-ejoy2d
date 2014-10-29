LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := cskynet

LOCAL_SRC_FILES := skynet_main.c skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c

LOCAL_CFLAGS    := -Wl,-E

LOCAL_LDLIBS    := -lGLESv2 \
                -lEGL \
                -llog \
                -landroid \
		-ldl
				
LOCAL_WHOLE_STATIC_LIBRARIES := android_native_app_glue lua

include $(BUILD_SHARED_LIBRARY)

$(call import-module,android/native_app_glue)
$(call import-module,3rd/lua)
