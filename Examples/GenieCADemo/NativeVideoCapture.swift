import AppKit
import AVFoundation
import ScreenCaptureKit

@available(macOS 15.2, *)
final class NativeVideoCapture: NSObject, SCStreamOutput, SCContentSharingPickerObserver, @unchecked Sendable {
    private let queue = DispatchQueue(label: "genie.native.video")
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private var stream: SCStream?
    private var began = false
    private var times: [Double] = []
    private var statuses: [Int: Int] = [:]
    private var rejected = 0
    @MainActor private var selection: CheckedContinuation<SCContentFilter, Error>?
    private(set) var windowOnScreen = false
    let requestedFPS = 120
    init(url: URL, width: Int, height: Int) throws {
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 16_000_000,
                AVVideoExpectedSourceFrameRateKey: 120, AVVideoMaxKeyFrameIntervalKey: 120]])
        input.expectsMediaDataInRealTime = true
        super.init()
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CaptureError.writer }
    }
    @MainActor func start(window: NSWindow) async throws {
        let picker = SCContentSharingPicker.shared
        var pickerConfig = SCContentSharingPickerConfiguration()
        pickerConfig.allowedPickerModes = [.singleWindow]
        pickerConfig.allowsChangingSelectedContent = false
        picker.defaultConfiguration = pickerConfig
        picker.add(self); picker.isActive = true
        let filter = try await withCheckedThrowingContinuation { continuation in
            selection = continuation
            picker.present(using:.window)
        }
        guard filter.includedWindows.count == 1,
              let captured = filter.includedWindows.first,
              captured.windowID == CGWindowID(window.windowNumber) else { throw CaptureError.window }
        windowOnScreen = captured.isOnScreen
        let config = SCStreamConfiguration()
        config.width = 1600; config.height = 1200
        config.minimumFrameInterval = CMTime(value: 1, timescale: 120)
        config.queueDepth = 8; config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.colorSpaceName = CGColorSpace.sRGB
        config.ignoreShadowsSingleWindow = true
        let capture = SCStream(filter: filter, configuration: config, delegate: nil)
        try capture.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        stream = capture
        print("Native recording: session-scoped window picker selection")
        try await capture.startCapture()
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]]
        let status = (attachments?.first?[.status] as? NSNumber)?.intValue ?? -1
        statuses[status, default: 0] += 1
        guard status == SCFrameStatus.complete.rawValue else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !began { writer.startSession(atSourceTime: pts); began = true }
        guard input.isReadyForMoreMediaData else { rejected += 1; return }
        if input.append(sampleBuffer) { times.append(pts.seconds) } else { rejected += 1 }
    }
    @MainActor func finish(metadata: URL) async throws {
        try await stream?.stopCapture()
        SCContentSharingPicker.shared.remove(self)
        SCContentSharingPicker.shared.isActive = false
        let count = queue.sync { times.count }
        guard count > 1 else {
            writer.cancelWriting()
            print("No captured frames. statuses=\(queue.sync { statuses })")
            throw CaptureError.noFrames
        }
        queue.sync { input.markAsFinished() }
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CaptureError.writer }
        let data: [String: Any] = queue.sync {
            ["requestedFPS": requestedFPS, "encodedFrames": times.count,
             "samplePTS": times.map { $0-times[0] }, "encoderRejected": rejected,
             "frameStatuses": Dictionary(uniqueKeysWithValues: statuses.map { (String($0.key), $0.value) }),
             "material": "NSVisualEffectView (within-window live blur)", "capture": "ScreenCaptureKit window recording",
             "windowOnScreen": windowOnScreen]
        }
        try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]).write(to: metadata)
        print("Native recording completed: \(count) frames")
    }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in self.selection?.resume(throwing:CaptureError.cancelled); self.selection = nil }
    }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in self.selection?.resume(returning:filter); self.selection = nil }
    }
    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in self.selection?.resume(throwing:error); self.selection = nil }
    }
    enum CaptureError: Error { case window, writer, noFrames, cancelled }
}
