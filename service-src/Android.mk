LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := snlua

LOCAL_MODULE_FILENAME := snlua

LOCAL_SRC_FILES := service_snlua.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../skynet-src $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := logger

LOCAL_MODULE_FILENAME := logger

LOCAL_SRC_FILES := service_logger.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../skynet-src $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := gate

LOCAL_MODULE_FILENAME := gate

LOCAL_SRC_FILES := service_gate.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../skynet-src $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)

include $(CLEAR_VARS)

LOCAL_MODULE := harbor

LOCAL_MODULE_FILENAME := harbor

LOCAL_SRC_FILES := service_harbor.c

LOCAL_C_INCLUDES := $(LOCAL_PATH)/../skynet-src $(LOCAL_PATH)/../3rd/lua

LOCAL_SHARED_LIBRARIES := cskynet

LOCAL_ALLOW_UNDEFINED_SYMBOLS := true

include $(BUILD_SHARED_LIBRARY)
