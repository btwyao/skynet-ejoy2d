#ifndef ejoy2d_windows_h
#define ejoy2d_windows_h

void window_init();
void window_update_frame();
void window_event_handle();
void start_egl_current();
void stop_egl_current();
int get_window_width();
int get_window_height();

#endif
