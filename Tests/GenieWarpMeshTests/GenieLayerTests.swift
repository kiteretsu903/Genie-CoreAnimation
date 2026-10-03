import AppKit
import XCTest
@testable import GenieWarpMesh

final class GenieLayerTests: XCTestCase {
    @MainActor func testTrajectoryIsFiniteAndStartsAtIdentity() {
        let source = CGRect(x:100,y:120,width:640,height:440)
        for direction in [GenieDirection.bottom,.top,.left,.right] {
            let target: CGRect
            switch direction {
            case .bottom: target = CGRect(x:350,y:60,width:60,height:0.5)
            case .top: target = CGRect(x:350,y:580,width:60,height:0.5)
            case .left: target = CGRect(x:50,y:280,width:0.5,height:60)
            default: target = CGRect(x:780,y:280,width:0.5,height:60)
            }
            let reference = GenieEffect()
            let path = GenieLayerTrajectory(source:source,viewport:CGRect(x:0,y:0,width:800,height:600),
                target:target,direction:direction,corrected:reference.computeCorrectedFrame(sourceFrame:source,targetFrame:target,direction:direction),pixel:0.5,easing:reference.easingType)
            for (a,b) in zip(path.from,path.points(at:0)) {
                XCTAssertEqual(a.x,b.x,accuracy:0.000001); XCTAssertEqual(a.y,b.y,accuracy:0.000001)
            }
            for i in 0...120 {
                XCTAssertTrue(path.points(at:Double(i)/120).allSatisfy { $0.x.isFinite && $0.y.isFinite })
                XCTAssertEqual(path.points(at:Double(i)/120).count,40)
            }
        }
    }
    @MainActor func testInvalidGeometryFailsWithoutStarting() {
        let effect = GenieLayerEffect()
        XCTAssertFalse(effect.play(layer:CALayer(),source:.zero,viewport:.zero,target:.zero,direction:.bottom,opening:true) {})
        XCTAssertFalse(effect.isAnimating)
        effect.cancel(); effect.cancel()
    }
    @MainActor func testReversalAndCancellationSuppressStaleCompletion() async throws {
        _ = NSApplication.shared
        try XCTSkipUnless(GenieLayerEffect.isAvailable,"Private mesh ABI unavailable")
        let panel = NSPanel(contentRect:CGRect(x:100,y:100,width:800,height:600),styleMask:.borderless,backing:.buffered,defer:false)
        let view = NSView(frame:CGRect(x:0,y:0,width:800,height:600)); view.wantsLayer = true
        panel.contentView = view; panel.orderFrontRegardless()
        let effect = GenieLayerEffect(); defer { effect.cancel(); panel.orderOut(nil) }
        var stale = 0, finished = 0
        XCTAssertTrue(effect.play(layer:view.layer!,source:CGRect(x:80,y:100,width:640,height:440),viewport:view.bounds,
            target:CGRect(x:350,y:40,width:60,height:0.5),direction:.bottom,opening:true,duration:0.3) { stale += 1 })
        try await Task.sleep(nanoseconds:80_000_000)
        XCTAssertTrue(effect.reverse(opening:false,duration:0.3) { finished += 1 })
        try await Task.sleep(nanoseconds:400_000_000)
        XCTAssertEqual(stale,0); XCTAssertEqual(finished,1); XCTAssertFalse(effect.isAnimating)
        XCTAssertTrue(effect.play(layer:view.layer!,source:CGRect(x:80,y:100,width:640,height:440),viewport:view.bounds,
            target:CGRect(x:350,y:40,width:60,height:0.5),direction:.bottom,opening:true,duration:0.3) { stale += 1 })
        effect.cancel()
        try await Task.sleep(nanoseconds:350_000_000)
        XCTAssertEqual(stale,0); XCTAssertFalse(effect.isAnimating)
    }
}
