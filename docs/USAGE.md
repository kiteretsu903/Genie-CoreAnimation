# Integration guide

## Add the package

For a local checkout:

```swift
.package(path: "../Genie-CoreAnimation")
```

Add the library to your target:

```swift
.target(name: "YourApp", dependencies: ["GenieWarpMesh"])
```

## Play a transition

Keep the effect alive for the duration of the animation, and call it on the main actor.

```swift
import AppKit
import GenieWarpMesh

@MainActor
final class SurfaceTransition {
    private let effect = GenieLayerEffect()

    func open(layer: CALayer, window: NSWindow,
              source: CGRect, viewport: CGRect, mouth: CGRect) {
        effect.failureHandler = {
            // Restore a normal visible surface if submission fails.
        }

        let started = effect.play(
            layer: layer,
            source: source,
            viewport: viewport,
            target: mouth,
            direction: .bottom,
            opening: true,
            duration: 0.5,
            backingScale: window.backingScaleFactor,
            screen: window.screen
        ) {
            // Opening has completed and the layer mesh is restored.
        }

        if !started {
            // Show the surface normally, or use a fallback transition.
        }
    }
}
```

`source`, `viewport` and `target` must share a **Cocoa bottom-left coordinate space**. The viewport maps the full animated layer bounds; source identifies the surface inside it. Both local coordinates and global screen coordinates work when used consistently. The [demo source](../Examples/GenieCADemo/main.swift) shows a local setup.

For closing, pass `opening: false`. Hide the surface in the completion before cancelling/resetting the collapsed mesh. The library does not order out or close the host window.

```swift
// Retarget an in-flight transition; the newest completion replaces the old one.
effect.reverse(opening: false) {
    // Hide the surface here.
}

// Remove the mesh and suppress pending completion callbacks.
effect.cancel()
```

Check both the return value of `play` and `failureHandler`. Respect the user’s Reduce Motion preference in the host application.

## Content, shadows and live blur

Ordinary content and its shadow can be rasterized together during motion. Use the display’s backing scale, then turn rasterization off after landing so text and controls return to normal live rendering.

For an `NSVisualEffectView`, keep the blur live in a sibling view behind the animated content layer. The demo uses `.withinWindow` blending to blur its wallpaper. Attach a `CAShapeLayer` mask and pass it as `backdropMask`, along with `materialInset` and `materialRadius`. Its outline follows the same sampled mesh and timing. Rasterizing native blur into the content mesh can produce incorrect results. Keep the backdrop out of the rasterized mesh.

The host owns appearance, materials, interaction and SDR/HDR policy. The demo keeps the blur live while the mesh deforms the icons and labels. The video is a window recording, not a compositor benchmark or HDR certification.

## Private APIs

This implementation uses runtime-resolved private Core Animation mesh facilities, including `CAMeshTransform`. The original backend uses the private `CGSSetWindowWarp` API. Availability is checked at runtime, but future macOS compatibility and App Store acceptance are not guaranteed.

This is an open-source approximation of the Genie effect. Apple does not provide this library or a public Genie animation preset.
