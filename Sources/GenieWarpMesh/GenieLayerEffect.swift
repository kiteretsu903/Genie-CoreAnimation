import AppKit
import CGSPrivate

/// Samples the accepted passage once, then lets Core Animation own playback.
/// A one-shot display link only arms the transaction; it never drives mesh frames.
@MainActor public final class GenieLayerEffect: NSObject {
    public static var isAvailable: Bool { GWMLayerMeshAvailable() }
    public var failureHandler: (() -> Void)?
    public private(set) var isAnimating = false
    public private(set) var keyframeCount = 0
    public private(set) var preparationDuration: TimeInterval = 0
    public private(set) var firstCallbackDelay: TimeInterval = 0
    private weak var layer: CALayer?
    private weak var mask: CAShapeLayer?
    private var trajectory: GenieLayerTrajectory?
    private var completion: (() -> Void)?
    private var started: TimeInterval?
    private var requested = 0.0
    private var startProgress = 0.0
    private var endProgress = 0.0
    private var span: TimeInterval = 0
    private var generation = 0
    private var arm: CADisplayLink?
    private var pending: (() -> Void)?
    private let key = "genie-layer-mesh"
    private var maskInset: CGFloat = 32
    private var maskRadius: CGFloat = 18
    public var progress: Double {
        guard isAnimating else { return endProgress }
        guard let started else { return startProgress }
        let t = min(1,max(0,(CACurrentMediaTime()-started)/max(0.001,span)))
        return startProgress+(endProgress-startProgress)*t
    }
    public func cancel() {
        generation += 1; isAnimating = false; completion = nil
        arm?.invalidate(); arm = nil; pending = nil
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer?.removeAnimation(forKey:key); mask?.removeAnimation(forKey:key)
        if let layer { _ = GWMApplyLayerMesh(layer,nil) }
        CATransaction.commit()
        trajectory = nil; layer = nil; mask = nil
    }
    @discardableResult public func play(layer: CALayer, source: CGRect, viewport: CGRect, target: CGRect,
        direction: GenieDirection, opening: Bool, duration: TimeInterval = 0.5,
        backingScale: CGFloat = 2, backdropMask: CAShapeLayer? = nil,
        materialInset: CGFloat = 32, materialRadius: CGFloat = 18,
        screen: NSScreen? = nil, completion: @escaping () -> Void) -> Bool {
        cancel()
        guard Self.isAvailable, source.width > 0, source.height > 0, viewport.width > 0, viewport.height > 0 else { return false }
        let reference = GenieEffect()
        let direction = direction.resolved(from:source,to:target)
        trajectory = GenieLayerTrajectory(source:source,viewport:viewport,target:target,direction:direction,
            corrected:reference.computeCorrectedFrame(sourceFrame:source,targetFrame:target,direction:direction),
            pixel:1/max(1,backingScale),easing:reference.easingType)
        self.layer = layer; mask = backdropMask; maskInset = materialInset; maskRadius = materialRadius
        return submit(from:opening ? 1 : 0,to:opening ? 0 : 1,duration:duration,screen:screen,completion:completion)
    }
    @discardableResult public func reverse(opening: Bool, duration: TimeInterval = 0.5, completion: @escaping () -> Void) -> Bool {
        guard isAnimating else { return false }
        let from = progress, to = opening ? 0.0 : 1.0
        return submit(from:from,to:to,duration:duration*abs(to-from),screen:arm == nil ? nil : NSScreen.main,completion:completion)
    }
    @objc private func beginPlayback(_ link: CADisplayLink) {
        link.invalidate(); arm = nil
        firstCallbackDelay = CACurrentMediaTime()-requested
        let work = pending; pending = nil; work?()
    }
    private func submit(from: Double, to: Double, duration: TimeInterval, screen: NSScreen?, completion: @escaping () -> Void) -> Bool {
        guard let layer, let trajectory else { return false }
        let prepare = CACurrentMediaTime()
        let count = max(2,Int(ceil(max(0.001,duration)*240))+1)
        var values: [AnyObject] = [], paths: [CGPath] = [], times: [NSNumber] = []
        values.reserveCapacity(count); paths.reserveCapacity(count); times.reserveCapacity(count)
        for i in 0..<count {
            let t = Double(i)/Double(count-1), p = from+(to-from)*t
            guard let mesh = trajectory.mesh(at:p) else { cancel(); return false }
            values.append(mesh); times.append(NSNumber(value:t))
            if mask != nil {
                var flip = CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:trajectory.viewport.height)
                paths.append(trajectory.materialOutline(at:p,inset:maskInset,radius:maskRadius).copy(using:&flip)!)
            }
        }
        generation += 1; let token = generation
        arm?.invalidate(); arm = nil; pending = nil
        CATransaction.begin(); CATransaction.setDisableActions(true)
        layer.removeAnimation(forKey:key); mask?.removeAnimation(forKey:key)
        guard GWMApplyLayerMesh(layer,values.first!) else { CATransaction.commit(); cancel(); return false }
        if let first = paths.first { mask?.path = first }
        CATransaction.commit()
        self.completion = completion; startProgress = from; endProgress = to; span = max(0.001,duration)
        started = nil; isAnimating = true; requested = CACurrentMediaTime(); firstCallbackDelay = 0
        keyframeCount = count; preparationDuration = requested-prepare
        let playback: () -> Void = { [weak self, weak layer] in
            guard let self, let layer, self.generation == token else { return }
            CATransaction.begin(); CATransaction.setDisableActions(true)
            _ = GWMApplyLayerMesh(layer,values.last!)
            if let last = paths.last { self.mask?.path = last }
            CATransaction.setCompletionBlock { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.generation == token, self.isAnimating else { return }
                    self.isAnimating = false
                    let finished = self.completion; self.completion = nil
                    if to == 0 {
                        CATransaction.begin(); CATransaction.setDisableActions(true)
                        _ = GWMApplyLayerMesh(layer,nil)
                        CATransaction.commit()
                    }
                    finished?()
                }
            }
            self.started = CACurrentMediaTime()
            let ok = GWMAnimateLayerMesh(layer,values,times,self.span,self.key)
            if let mask = self.mask, !paths.isEmpty {
                let motion = CAKeyframeAnimation(keyPath:"path")
                motion.values = paths; motion.keyTimes = times; motion.duration = self.span
                motion.calculationMode = .linear; motion.timingFunction = CAMediaTimingFunction(name:.linear)
                mask.add(motion,forKey:self.key)
            }
            CATransaction.commit()
            if !ok { self.cancel(); self.failureHandler?() }
        }
        if let screen {
            pending = playback
            let link = screen.displayLink(target:self,selector:#selector(beginPlayback(_:)))
            arm = link; link.add(to:.main,forMode:.common)
        } else { playback() }
        return true
    }
}
