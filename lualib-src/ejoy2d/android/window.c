#include <jni.h>
#include <EGL/egl.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <android_native_app_glue.h>

/* include some silly stuff */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "ejoy2d/ejoy2dgame.h"
#include "ejoy2d/screen.h"
#include "ejoy2d/shader.h"
#include "ejoy2d/label.h"
#include "ejoy2d/platform_print.h"

#define UPDATE_INTERVAL 1       /* 10ms */

#define WIDTH 1280
#define HEIGHT 720

#define TOUCH_BEGIN 0
#define TOUCH_END 1
#define TOUCH_MOVE 2
#define TOUCH_CANCEL 3


/**
 * Our saved state data.
 */
struct saved_state {
    float angle;
    int32_t x;
    int32_t y;
};

/**
 * Shared state for our app.
 */
struct engine {
    struct android_app* app;

    int animating;
    EGLDisplay display;
    EGLSurface surface;
    EGLContext context;
    EGLint format;
    EGLConfig config;
    int32_t width;
    int32_t height;
    int32_t real_width;
    int32_t real_height;
    struct saved_state state;
};

static struct engine g_engine;

void font_init();

/**
 * Initialize an EGL context for the current display.
 */
static int engine_init_display(struct engine* engine) {
    // initialize OpenGL ES and EGL

    /*
     * Here specify the attributes of the desired configuration.
     * Below, we select an EGLConfig with at least 8 bits per color
     * component compatible with on-screen windows
     */
    const EGLint attribs[] = {
            EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
			EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
			EGL_ALPHA_SIZE, 8,
            EGL_BLUE_SIZE, 8,
            EGL_GREEN_SIZE, 8,
            EGL_RED_SIZE, 8,
			EGL_DEPTH_SIZE, 1,
			EGL_STENCIL_SIZE, 1,
            EGL_NONE
    };
    EGLint w, h, dummy, format;
    EGLint numConfigs;
    EGLConfig config;
	EGLDisplay display;
    EGLSurface surface;
    EGLContext context;

	if (!engine->display) {
		display = eglGetDisplay(EGL_DEFAULT_DISPLAY);

		eglInitialize(display, 0, 0);

		/* Here, the application chooses the configuration it desires. In this
		 * sample, we have a very simplified selection process, where we pick
		 * the first EGLConfig that matches our criteria */
		if (eglChooseConfig(display, attribs, &config, 1, &numConfigs) == EGL_FALSE) {
			pf_log( "eglChooseConfig failed:%i \n",numConfigs);
			return -1;
		}

		/* EGL_NATIVE_VISUAL_ID is an attribute of the EGLConfig that is
		 * guaranteed to be accepted by ANativeWindow_setBuffersGeometry().
		 * As soon as we picked a EGLConfig, we can safely reconfigure the
		 * ANativeWindow buffers to match, using EGL_NATIVE_VISUAL_ID. */
		eglGetConfigAttrib(display, config, EGL_NATIVE_VISUAL_ID, &format);

		engine->display = display;
		engine->config = config;
		engine->format = format;
	} else {
		display = engine->display;
		config = engine->config;
		format = engine->format;
	}

	w = ANativeWindow_getWidth(engine->app->window);
	h = ANativeWindow_getHeight(engine->app->window);

	if (engine->real_width)
		ANativeWindow_setBuffersGeometry(engine->app->window, 0, 0, format);
	else
		ANativeWindow_setBuffersGeometry(engine->app->window, w, h, format);
	engine->real_width = w;
	engine->real_height = h;

	double dw = (double)w/WIDTH;
	double dh = (double)h/HEIGHT;
	if (dw < dh) {
		engine->width = w;
		engine->height = (int32_t)(HEIGHT*dw);
	} else if (dw > dh) {
		engine->height = h;
		engine->width = (int32_t)(WIDTH*dh);
	} else {
		engine->width = w;
		engine->height = h;
	}

	pf_log( "egl width:%i,height:%i,format:%i\n",engine->width,engine->height,format);

    surface = eglCreateWindowSurface(display, config, engine->app->window, NULL);

	if (!engine->context) {
		const EGLint eglContextAttrs[] =
		{
			EGL_CONTEXT_CLIENT_VERSION, 2,
			EGL_NONE
		};

		context = eglCreateContext(display, config, NULL, eglContextAttrs);
	} else {
		context = engine->context;
	}

    if (eglMakeCurrent(display, surface, surface, context) == EGL_FALSE) {
		pf_log( "eglMakeCurrent failed \n");
        return -1;
    }

	screen_init(engine->width,engine->height,1.0f);
	pf_log( "screen init finished \n");
	if (!engine->context) {
		font_init();
		pf_log( "font init finished \n");

		shader_init();
		pf_log( "shader init finished \n");
		label_load();
		pf_log( "label load finished \n");
		ejoy2d_game_wininit();
		pf_log( "ejoy2d game wininit finished \n");

		engine->context = context;
	}

    engine->surface = surface;
    engine->state.angle = 0;

    return 0;
}

int get_window_width() {
	return g_engine.width;
}

int get_window_height() {
	return g_engine.height;
}

void start_egl_current() {
	if (g_engine.display && g_engine.animating)
		eglMakeCurrent(g_engine.display, g_engine.surface, g_engine.surface, g_engine.context);
}

void stop_egl_current() {
	if (g_engine.display && g_engine.animating)
		eglMakeCurrent(g_engine.display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
}

/**
 * Tear down the EGL context currently associated with the display.
 */
static void engine_term_display(struct engine* engine) {
    if (engine->display != EGL_NO_DISPLAY) {
        eglMakeCurrent(engine->display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
//        if (engine->context != EGL_NO_CONTEXT) {
//            eglDestroyContext(engine->display, engine->context);
//        }
        if (engine->surface != EGL_NO_SURFACE) {
            eglDestroySurface(engine->display, engine->surface);
        }
//        eglTerminate(engine->display);
    }
    engine->animating = 0;
//    engine->display = EGL_NO_DISPLAY;
//    engine->context = EGL_NO_CONTEXT;
    engine->surface = EGL_NO_SURFACE;
}

void
window_update_frame() {
	if (g_engine.animating) {
		ejoy2d_game_drawframe();
		eglSwapBuffers(g_engine.display, g_engine.surface);
	}
}

/**
 * Process the next main command.
 */
static void engine_handle_cmd(struct android_app* app, int32_t cmd) {
    struct engine* engine = (struct engine*)app->userData;
    switch (cmd) {
        case APP_CMD_SAVE_STATE:
            // The system has asked us to save our current state.  Do so.
            engine->app->savedState = malloc(sizeof(struct saved_state));
            *((struct saved_state*)engine->app->savedState) = engine->state;
            engine->app->savedStateSize = sizeof(struct saved_state);
            break;
        case APP_CMD_INIT_WINDOW:
            // The window is being shown, get it ready.
            if (engine->app->window != NULL) {
                engine_init_display(engine);
				pf_log( "engine init display finished \n");
                engine->animating = 1;

//				window_update_frame();
            }
            break;
        case APP_CMD_TERM_WINDOW:
            // The window is being hidden or closed, clean it up.
			engine_term_display(engine);
			pf_log( "app cmd term window \n");
            break;
        case APP_CMD_GAINED_FOCUS:
            // When our app gains focus, we start monitoring the accelerometer.
			engine->animating = 1;
			pf_log( "app cmd gained focus \n");
            break;
        case APP_CMD_LOST_FOCUS:
            // When our app loses focus, we stop monitoring the accelerometer.
            // This is to avoid consuming battery while not being used.
            // Also stop animating.
            engine->animating = 0;
			pf_log( "app cmd lost focus \n");
            break;
    }
}

static inline void
window_touch(int id, float x, float y, int status) {
    ejoy2d_game_touch(id,x, y - g_engine.real_height + g_engine.height,status);
}

/*
 * Get X, Y positions and ID's for all pointers
 */
static void handle_multi_touch(AInputEvent *event, int eventType) {
    int pointerCount = AMotionEvent_getPointerCount(event);
	int i;
    for(i = 0; i < pointerCount; ++i) {
        int pointerId = AMotionEvent_getPointerId(event, i);
        float xP = AMotionEvent_getX(event, i);
        float yP = AMotionEvent_getY(event, i);
        window_touch(pointerId,xP, yP,eventType);
    }
}

/*
 * Handle Touch Inputs
 */
static int32_t handle_touch_input(AInputEvent *event) {
    switch(AMotionEvent_getAction(event) &
           AMOTION_EVENT_ACTION_MASK) {

    case AMOTION_EVENT_ACTION_DOWN:
        {
            int pointerId = AMotionEvent_getPointerId(event, 0);
            float xP = AMotionEvent_getX(event,0);
            float yP = AMotionEvent_getY(event,0);

            window_touch(pointerId,xP, yP, TOUCH_BEGIN);
            return 1;
        }
        break;

    case AMOTION_EVENT_ACTION_POINTER_DOWN:
        {
            int pointerIndex = AMotionEvent_getAction(event) >> AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT;
            int pointerId = AMotionEvent_getPointerId(event, pointerIndex);
            float xP = AMotionEvent_getX(event,pointerIndex);
            float yP = AMotionEvent_getY(event,pointerIndex);


            window_touch(pointerId,xP, yP, TOUCH_BEGIN);
            return 1;
        }
        break;

    case AMOTION_EVENT_ACTION_MOVE:
        {
			handle_multi_touch(event,TOUCH_MOVE);
            return 1;
        }
        break;

    case AMOTION_EVENT_ACTION_UP:
        {
            int pointerId = AMotionEvent_getPointerId(event, 0);
            float xP = AMotionEvent_getX(event,0);
            float yP = AMotionEvent_getY(event,0);

            window_touch(pointerId,xP, yP, TOUCH_END);
            return 1;
        }
        break;

    case AMOTION_EVENT_ACTION_POINTER_UP:
        {
            int pointerIndex = AMotionEvent_getAction(event) >> AMOTION_EVENT_ACTION_POINTER_INDEX_SHIFT;
            int pointerId = AMotionEvent_getPointerId(event, pointerIndex);
            float xP = AMotionEvent_getX(event,pointerIndex);
            float yP = AMotionEvent_getY(event,pointerIndex);

            window_touch(pointerId,xP, yP, TOUCH_END);
            return 1;
        }
        break;

    case AMOTION_EVENT_ACTION_CANCEL:
        {
			handle_multi_touch(event,TOUCH_CANCEL);
            return 1;
        }
        break;

    default:
        return 0;
        break;
    }
}

/**
 * Process the next input event.
 */
static int32_t engine_handle_input(struct android_app* app, AInputEvent* event) {
    struct engine* engine = (struct engine*)app->userData;
    if (AInputEvent_getType(event) == AINPUT_EVENT_TYPE_MOTION) {
        engine->animating = 1;
        engine->state.x = AMotionEvent_getX(event, 0);
        engine->state.y = AMotionEvent_getY(event, 0);
        return handle_touch_input(event);
    }
    return 0;
}

void
window_event_handle() {
	if(g_engine.app->destroyRequested != 0) {
		return;
	}

	int ident;
	int events;
	struct android_poll_source* source;

	// If not animating, we will block forever waiting for events.
	// If animating, we loop until all events are read, then continue
	// to draw the next frame of animation.
	while ((ident=ALooper_pollAll(g_engine.animating ? 0 : -1, NULL, &events,
			(void**)&source)) >= 0) {

		// Process this event.
		if (source != NULL) {
			source->process(g_engine.app, source);
		}

		// Check if we are exiting.
		if (g_engine.app->destroyRequested != 0) {
//			label_unload();
//			shader_unload();
//			texture_exit();
//			memset(&g_engine, 0, sizeof(g_engine));
			pf_log( "app destroy\n");
			return;
		}
	}

	if (g_engine.animating) {
		// Done with events; draw next animation frame.
		g_engine.state.angle += .01f;
		if (g_engine.state.angle > 1) {
			g_engine.state.angle = 0;
		}
	}
}

void
window_init() {
	struct android_app* state = android_win_create();

    memset(&g_engine, 0, sizeof(g_engine));
    state->userData = &g_engine;
    state->onAppCmd = engine_handle_cmd;
    state->onInputEvent = engine_handle_input;
    g_engine.app = state;

    if (state->savedState != NULL) {
        // We are starting with a previous saved state; restore from it.
        g_engine.state = *(struct saved_state*)state->savedState;
    }
	window_event_handle();
}

