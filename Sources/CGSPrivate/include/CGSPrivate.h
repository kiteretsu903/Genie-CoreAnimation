//
//  CGSPrivate.h
//
//  Private Core Graphics Services API declarations.
//

#ifndef CGSPrivate_h
#define CGSPrivate_h

#include <stdbool.h>
#import <CoreGraphics/CoreGraphics.h>

typedef int CGSConnectionID;
typedef int CGSWindowID;

/// A 2D point using float (32-bit) precision.
/// GWMSetWindowWarp expects float-based coordinates, NOT CGPoint (which uses CGFloat/double on 64-bit).
typedef struct {
	float x;
	float y;
} CGSMeshPoint;

/// A mesh point for GWMSetWindowWarp.
/// `local` is the pixel coordinate within the window (left-top origin).
/// `global` is the screen coordinate where that point should appear (CG coordinate system, left-top origin).
typedef struct {
	CGSMeshPoint local;
	CGSMeshPoint global;
} CGSWarpPoint;

/// Get the default connection to the window server.
extern CGSConnectionID GWMMainConnectionID(void);

// MARK: - Window Bounds API

/// Get the bounds of a window directly from the window server.
/// Unlike NSWindow.frame, this returns real-time bounds even during a title bar drag.
/// @param cid    Connection ID from GWMMainConnectionID().
/// @param wid    The window number (NSWindow.windowNumber).
/// @param bounds Pointer to a CGRect to receive the window bounds (CG coordinate system, top-left origin).
extern bool GWMAvailable(void);

// MARK: - Mesh Warp API

/// Apply a mesh warp to a window.
/// @param cid  Connection ID from GWMMainConnectionID().
/// @param wid  The window number (NSWindow.windowNumber).
/// @param w    Number of columns in the mesh grid.
/// @param h    Number of rows in the mesh grid.
/// @param mesh Pointer to a w*h array of CGSWarpPoint. Pass NULL with w=0,h=0 to reset.
extern CGError GWMSetWindowWarp(CGSConnectionID cid, CGSWindowID wid, int w, int h, const CGSWarpPoint *mesh);

#endif /* CGSPrivate_h */

#ifdef __OBJC__
#import "GWMLayerMesh.h"
#endif
