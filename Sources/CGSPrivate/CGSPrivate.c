// Local runtime lookup: an unavailable private API must not prevent app launch.
#include "CGSPrivate.h"
#include <dlfcn.h>
#include <pthread.h>
static pthread_once_t once = PTHREAD_ONCE_INIT;
static CGSConnectionID (*connection)(void);
static CGError (*warp)(CGSConnectionID,CGSWindowID,int,int,const CGSWarpPoint *);
static void resolve(void) {
    connection = dlsym(RTLD_DEFAULT,"CGSMainConnectionID");
    warp = dlsym(RTLD_DEFAULT,"CGSSetWindowWarp");
}
bool GWMAvailable(void) { pthread_once(&once,resolve); return connection && warp; }
CGSConnectionID GWMMainConnectionID(void) { return GWMAvailable() ? connection() : 0; }
CGError GWMSetWindowWarp(CGSConnectionID cid,CGSWindowID wid,int w,int h,const CGSWarpPoint *mesh) {
    return GWMAvailable() ? warp(cid,wid,w,h,mesh) : kCGErrorNotImplemented;
}
