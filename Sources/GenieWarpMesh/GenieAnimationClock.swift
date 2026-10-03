import Foundation

/// Presentation time starts with the first delivered frame, so main-thread work
/// before the display link runs cannot consume an unseen animation.
struct GenieAnimationClock {
    private(set) var rawTime = 0.0
    private var anchorTime: TimeInterval?
    private var anchorProgress = 0.0
    private var lastPresentationTime: TimeInterval?

    mutating func start(at progress: Double = 0) {
        rawTime = min(1,max(0,progress))
        anchorProgress = rawTime
        anchorTime = nil
        lastPresentationTime = nil
    }

    mutating func advance(to presentationTime: TimeInterval, duration: TimeInterval) -> Double {
        guard presentationTime.isFinite else { return rawTime }
        let origin = anchorTime ?? presentationTime
        anchorTime = origin
        let timestamp = max(presentationTime,lastPresentationTime ?? presentationTime)
        lastPresentationTime = timestamp
        rawTime = min(1,max(rawTime,anchorProgress+(timestamp-origin)/max(duration,0.001)))
        return rawTime
    }

    /// Use the last displayed pose, without advancing through an unpresented gap.
    /// A reversal before the first callback must remain unanchored too.
    mutating func reverse(at time: TimeInterval) {
        rawTime = 1-rawTime
        anchorProgress = rawTime
        if anchorTime != nil {
            anchorTime = time
            lastPresentationTime = time
        }
    }
}

/// Bounded callback diagnostics. These measure scheduling, not displayed FPS.
public struct GenieAnimationDiagnostics {
    public internal(set) var firstCallbackDelay: TimeInterval?
    public internal(set) var frameCount = 0
    public internal(set) var maxCallbackGap: TimeInterval = 0
    public private(set) var maxTargetGap: TimeInterval = 0
    public private(set) var repeatedTargets = 0
    public private(set) var maxWarpSubmission: TimeInterval = 0
    public private(set) var lateSubmissions = 0
    private var lastTarget: TimeInterval?
    mutating func recordTarget(_ target: TimeInterval) {
        guard target.isFinite, target > 0 else { return }
        if let previous = lastTarget {
            if target <= previous { repeatedTargets += 1 }
            else { maxTargetGap = max(maxTargetGap,target-previous) }
        }
        lastTarget = target
    }
    mutating func recordSubmission(start: TimeInterval,end: TimeInterval) {
        guard start.isFinite, end.isFinite, end >= start else { return }
        maxWarpSubmission = max(maxWarpSubmission,end-start)
        if let lastTarget, end > lastTarget { lateSubmissions += 1 }
    }
}
