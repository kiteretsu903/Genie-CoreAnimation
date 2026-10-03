import AppKit
import CGSPrivate

/// The existing passage sampled into CA mesh keyframes. Source/window coordinates
/// stay Cocoa-global at the API boundary; the passage itself uses top-left pixels.
struct GenieLayerTrajectory {
    let source: CGRect
    let viewport: CGRect
    let target: CGRect
    let direction: GenieDirection
    let corrected: CGRect?
    let pixel: CGFloat
    let easing: EasingType
    var columns: Int { vertical ? 2 : 20 }
    var rows: Int { vertical ? 20 : 2 }
    private var vertical: Bool { direction == .bottom || direction == .top || direction == .auto }
    func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x:(point.x-viewport.minX)/viewport.width,y:(point.y+viewport.maxY)/viewport.height)
    }
    var from: [CGPoint] {
        (0..<columns*rows).map { i in
            local(CGPoint(x:source.minX+CGFloat(i%columns)/CGFloat(columns-1)*source.width,
                          y:-source.maxY+CGFloat(i/columns)/CGFloat(rows-1)*source.height))
        }
    }
    func points(at progress: Double) -> [CGPoint] {
        let retreat = CGFloat(easing.function(progress))
        var frame=source
        if let corrected {
            frame.origin.x += (corrected.minX-source.minX)*retreat
            frame.origin.y += (corrected.minY-source.minY)*retreat
        }
        let passage=GeniePassage(frame:CGRect(x:frame.minX,y:-frame.maxY,width:frame.width,height:frame.height),
            entry:CGRect(x:target.minX,y:-target.maxY,width:target.width,height:target.height),
            direction:direction,time:CGFloat(progress),pixel:pixel)
        return (0..<columns*rows).map { i in
            let x=CGFloat(i%columns)/CGFloat(columns-1),y=CGFloat(i/columns)/CGFloat(rows-1)
            return local(passage.hasVisibleArea ? passage.point(x:x,y:y) : passage.terminalPoint(x:x,y:y))
        }
    }
    /// Maps the live backdrop's outline through exactly the same prepared mesh.
    /// Native behind-window blur cannot itself be rasterized/mesh transformed.
    func materialOutline(at progress:Double,inset:CGFloat,radius:CGFloat) -> CGPath {
        let mesh=points(at:progress)
        func map(_ p:CGPoint)->CGPoint {
            let x=min(1,max(0,p.x/source.width))*CGFloat(columns-1)
            let y=min(1,max(0,p.y/source.height))*CGFloat(rows-1)
            let col=min(columns-2,Int(x)),row=min(rows-2,Int(y))
            let tx=x-CGFloat(col),ty=y-CGFloat(row)
            let a=mesh[row*columns+col],b=mesh[row*columns+col+1]
            let c=mesh[(row+1)*columns+col],d=mesh[(row+1)*columns+col+1]
            let px=(a.x+(b.x-a.x)*tx)*(1-ty)+(c.x+(d.x-c.x)*tx)*ty
            let py=(a.y+(b.y-a.y)*tx)*(1-ty)+(c.y+(d.y-c.y)*tx)*ty
            return CGPoint(x:px*viewport.width,y:py*viewport.height)
        }
        let rect=CGRect(origin:.zero,size:source.size).insetBy(dx:inset,dy:inset)
        let outline=CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil)
        let path=CGMutablePath();var last=CGPoint.zero;var first=CGPoint.zero
        outline.applyWithBlock { element in
            let e=element.pointee
            switch e.type {
            case .moveToPoint:last=e.points[0];first=last;path.move(to:map(last))
            case .addLineToPoint:
                let end=e.points[0]
                for i in 1...24 {let t=CGFloat(i)/24;path.addLine(to:map(CGPoint(x:last.x+(end.x-last.x)*t,y:last.y+(end.y-last.y)*t)))}
                last=end
            case .addCurveToPoint:
                let a=last,b=e.points[0],c=e.points[1],d=e.points[2]
                for i in 1...8 {let t=CGFloat(i)/8,u=1-t;path.addLine(to:map(CGPoint(x:u*u*u*a.x+3*u*u*t*b.x+3*u*t*t*c.x+t*t*t*d.x,y:u*u*u*a.y+3*u*u*t*b.y+3*u*t*t*c.y+t*t*t*d.y)))}
                last=d
            case .closeSubpath:path.addLine(to:map(first));path.closeSubpath()
            default:break
            }
        }
        return path
    }
    func mesh(at progress: Double) -> AnyObject? {
        let a=from,b=points(at:progress)
        return a.withUnsafeBufferPointer { ap in b.withUnsafeBufferPointer { bp in
            GWMCreateLayerMesh(ap.baseAddress!,bp.baseAddress!,UInt(columns),UInt(rows)) as AnyObject?
        } }
    }
}
