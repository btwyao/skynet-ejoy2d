#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xos.h>
#include <GL/glxew.h>
#include <GL/glew.h>

/* include some silly stuff */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "ejoy2d/ejoy2dgame.h"
#include "ejoy2d/screen.h"
#include "ejoy2d/shader.h"
#include "ejoy2d/label.h"

#define UPDATE_INTERVAL 1       /* 10ms */

#define WIDTH 1280
#define HEIGHT 720

#define TOUCH_BEGIN 0
#define TOUCH_END 1
#define TOUCH_MOVE 2



void font_init();

struct X_context {
    Display *display;
    int screen_num;
    Window  wnd;
};

static GC gc;
static GLXContext g_context = 0;
struct X_context g_X;
/* Used to intercept window closing requests. */
static Atom wm_delete_window;

static int	
glx_init(struct X_context *X)
{
	XVisualInfo *vi;

	int attrib[]={
		GLX_RGBA, 
		GLX_DOUBLEBUFFER, 
		GLX_DEPTH_SIZE, 1,
		GLX_STENCIL_SIZE, 1,
		None
	};

	if (g_context)
		return 0;

	vi = glXChooseVisual( X->display, X->screen_num, attrib);
	
	if (vi==0) {
		return 1;
	}

	g_context = glXCreateContext( X->display, vi ,  NULL , True);

	if (g_context == 0) {
		return 1;
	}

	if (!glXMakeCurrent(X->display, X->wnd, g_context )) {
		g_context=NULL;
		return 1;
	}

	return 0;
}

static void
init_x() {
    unsigned long black,white;
    Display *dis;
    int screen;
    static Window win;

    dis=XOpenDisplay(NULL);
    screen=DefaultScreen(dis);
    black=BlackPixel(dis,screen);
    white=WhitePixel(dis, screen);

    
    win=XCreateSimpleWindow(dis,DefaultRootWindow(dis),0,0,
                            WIDTH, HEIGHT, 5,white, black);

    XMapWindow(dis, win);
    wm_delete_window = XInternAtom(dis, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(dis, win, &wm_delete_window, 1);

    XSetStandardProperties(dis,win,"ejoy2d",NULL,None,NULL,0,NULL);
    XSelectInput(dis, win,
                 ExposureMask|KeyPressMask|KeyReleaseMask
                 |ButtonPressMask|ButtonReleaseMask|ButtonMotionMask);
    gc=XCreateGC(dis, win, 0,0);        
    XSetBackground(dis,gc,white);
    XSetForeground(dis,gc,black);
    XClearWindow(dis, win);
    XMapRaised(dis, win);

    g_X.display = dis;
    g_X.screen_num = screen;
    g_X.wnd = win;
    
    if (glx_init(&g_X)){
        printf("glx init failed\n");
        exit(1);
    }
    if ( glewInit() != GLEW_OK ) {
        printf("glew init failed");
		exit(1);
	}
};

static void
close_x() {
    Display *dis = g_X.display;
    XFreeGC(dis, gc);
    XDestroyWindow(dis, g_X.wnd);
    XCloseDisplay(dis);
    exit(1);
}

void
window_init() {
    init_x();
    font_init();

	screen_init(WIDTH,HEIGHT,1.0f);
	shader_init();
	label_load();

	ejoy2d_game_wininit();
}

void
window_update_frame() {
	ejoy2d_game_drawframe();
    glXSwapBuffers(g_X.display, g_X.wnd);
}

int get_window_width() {
	return WIDTH;
}

int get_window_height() {
	return HEIGHT;
}

static XEvent event;
static KeySym keysym;
static char keychar[255];

void
window_event_handle() {

    while(XPending(g_X.display) > 0) {  
        XNextEvent(g_X.display, &event);
        if (XFilterEvent(&event,None))
            continue;
        switch (event.type) {
        case Expose:
            if (event.xexpose.count==0)
                window_update_frame();
            break;
        case KeyPress:
            XLookupString(&event.xkey, keychar, 255, &keysym, 0);
            if (keychar[0] == 'q' || keychar[0] == 'Q') {
                close_x();
            }
            break;
        case ButtonPress: 
            ejoy2d_game_touch(0,event.xbutton.x, event.xbutton.y, TOUCH_BEGIN); 
            break;
        case ButtonRelease:
            ejoy2d_game_touch(0,event.xbutton.x,event.xbutton.y,TOUCH_END);
            break;
        case MotionNotify:
            ejoy2d_game_touch(0,event.xbutton.x,event.xbutton.y,TOUCH_MOVE);
            break; 
        case ClientMessage:
            if ((Atom)event.xclient.data.l[0] == wm_delete_window) {
                close_x();
            }
            break;
        }
    }
}

