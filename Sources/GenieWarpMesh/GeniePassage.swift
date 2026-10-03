import CoreGraphics

/// Reference-fitted passage through a fixed entry, in global top-left coordinates.
/// The texture grid never changes. Rows beyond the entry occupy a subpixel strip,
/// rather than accumulating a complete miniature at the destination.
struct GeniePassage {
    let frame: CGRect
    let entry: CGRect
    let direction: GenieDirection
    let time: CGFloat
    let pixel: CGFloat

    private var vertical: Bool { direction == .bottom || direction == .top || direction == .auto }
    private var forward: Bool { direction == .bottom || direction == .right || direction == .auto }
    private var sign: CGFloat { forward ? 1 : -1 }
    private var length: CGFloat { vertical ? frame.height : frame.width }
    private var start: CGFloat {
        vertical ? (forward ? frame.minY : frame.maxY) : (forward ? frame.minX : frame.maxX)
    }
    private var entryAxis: CGFloat {
        vertical ? (forward ? entry.minY : entry.maxY) : (forward ? entry.minX : entry.maxX)
    }
    private var distance: CGFloat { max(1,(entryAxis-start)*sign) }

    static func smooth(_ value: CGFloat, from: CGFloat = 0, to: CGFloat = 1) -> CGFloat {
        let t = min(1,max(0,(value-from)/(to-from)))
        return t*t*(3-2*t)
    }
    // The reference's upper edge rests while its lower edge bends first.
    // Travel then accelerates; axial foreshortening starts as the leading rows enter.
    var bend: CGFloat { Self.smooth(time,to:0.54) }
    var travel: CGFloat { Self.smooth(time,from:0.32,to:0.985) }
    var axialScale: CGFloat { 1-Self.smooth(time,from:0.48,to:0.99) }
    private var plane: CGFloat {
        // The source includes transparent shadow padding that may initially
        // overlap the entry. Release it continuously, preserving exact identity.
        let initial = max(distance,length)
        return initial+(distance-initial)*Self.smooth(time,to:0.30)
    }
    var hasVisibleArea: Bool { plane-travel*distance > pixel*0.15 && axialScale*length > pixel*0.15 }

    func terminalPoint(x: CGFloat, y: CGFloat) -> CGPoint {
        // Prime a valid surface before a cold opening. Skipping its initial warp
        // can leave WindowServer with no visible surface until identity handoff.
        let seam = pixel*0.25
        if vertical {
            return CGPoint(x:entry.minX+x*entry.width,
                           y:(forward ? entry.minY : entry.maxY-seam)+y*seam)
        }
        return CGPoint(x:(forward ? entry.minX : entry.maxX-seam)+x*seam,
                       y:entry.minY+y*entry.height)
    }

    func point(x: CGFloat, y: CGFloat) -> CGPoint {
        let sourceMain = vertical ? y : x
        let row = forward ? sourceMain : 1-sourceMain
        let cross = vertical ? x : y
        let along = travel*distance + row*length*axialScale
        let convergence = bend*Self.smooth(along/distance)
        let originalCross = vertical ? frame.minX+cross*frame.width : frame.minY+cross*frame.height
        let targetCross = vertical ? entry.minX+cross*entry.width : entry.minY+cross*entry.height
        let crossPosition = originalCross+(targetCross-originalCross)*convergence
        let visibleAxis: CGFloat
        if along > plane {
            // Strictly monotone, finite triangles; never submit an all-zero-area
            // mesh to WindowServer. Hidden rows fit in a quarter physical pixel.
            let overflow = max(pixel,travel*distance+length*axialScale-plane)
            visibleAxis = plane+pixel*0.25*(along-plane)/overflow
        } else { visibleAxis = along }
        let mainPosition = start+sign*visibleAxis
        return vertical ? CGPoint(x:crossPosition,y:mainPosition) : CGPoint(x:mainPosition,y:crossPosition)
    }
}
