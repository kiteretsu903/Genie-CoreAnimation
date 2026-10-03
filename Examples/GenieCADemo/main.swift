import AppKit
import GenieWarpMesh

final class FlippedView: NSView { override var isFlipped: Bool { true } }
@MainActor final class Demo: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let plane = FlippedView()
    private let effect = GenieLayerEffect()
    private var expanded = true
    private let backdrop = NSVisualEffectView()
    private let backdropMask = CAShapeLayer()
    private let phase = NSTextField(labelWithString:"Expanded")
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect:NSRect(x:200,y:180,width:800,height:600),
                          styleMask:CommandLine.arguments.contains("--record") ? [.borderless] : [.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        window.title = "Genie-CoreAnimation — Live Blur"
        window.isReleasedWhenClosed = false
        let root = FlippedView(frame:NSRect(x:0,y:0,width:800,height:600))
        root.wantsLayer = true; root.appearance = NSAppearance(named:.darkAqua)
        let wallpaper = NSImageView(frame:root.bounds)
        wallpaper.image = NSImage(contentsOf:Bundle.module.url(forResource:"glacier-blue",withExtension:"png")!)
        wallpaper.imageScaling = .scaleAxesIndependently
        root.addSubview(wallpaper)
        let title = NSTextField(labelWithString:"Genie-CoreAnimation")
        title.font = .systemFont(ofSize:22,weight:.semibold); title.textColor = NSColor(srgbRed:0.04,green:0.12,blue:0.17,alpha:1)
        title.frame = NSRect(x:80,y:44,width:640,height:36); root.addSubview(title)
        phase.font = .systemFont(ofSize:13,weight:.medium)
        phase.textColor = NSColor(srgbRed:0.04,green:0.12,blue:0.17,alpha:0.8)
        phase.frame = NSRect(x:80,y:86,width:640,height:24); root.addSubview(phase)
        window.contentView = root
        backdrop.frame = root.bounds
        backdrop.blendingMode = .withinWindow; backdrop.material = .hudWindow; backdrop.state = .active
        backdrop.wantsLayer = true
        // The mesh plane is flipped; NSVisualEffectView and its mask use Cocoa
        // bottom-left coordinates, matching the effect's backdrop paths.
        backdropMask.frame = root.bounds; backdropMask.fillColor = NSColor.black.cgColor
        backdropMask.path = CGPath(roundedRect:CGRect(x:80,y:130,width:640,height:320),cornerWidth:24,cornerHeight:24,transform:nil)
        backdrop.layer?.mask = backdropMask
        root.addSubview(backdrop)
        plane.frame = root.bounds; plane.wantsLayer = true; root.addSubview(plane)
        let card = FlippedView(frame:NSRect(x:80,y:150,width:640,height:320))
        card.wantsLayer = true; card.layer?.backgroundColor = nil
        card.layer?.cornerRadius = 24
        plane.addSubview(card)
        let fixtures: [(String,String)] = [
            ("Finder","/System/Library/CoreServices/Finder.app"),
            ("Safari","/System/Cryptexes/App/System/Applications/Safari.app"),
            ("Mail","/System/Applications/Mail.app"),
            ("Photos","/System/Applications/Photos.app"),
            ("Notes","/System/Applications/Notes.app"),
            ("Calendar","/System/Applications/Calendar.app"),
            ("Reminders","/System/Applications/Reminders.app"),
            ("Music","/System/Applications/Music.app"),
            ("Messages","/System/Applications/Messages.app"),
            ("Maps","/System/Applications/Maps.app"),
            ("Weather","/System/Applications/Weather.app"),
            ("Settings","/System/Applications/System Settings.app")]
        for (i,fixture) in fixtures.enumerated() {
            let x = 22+CGFloat(i%6)*100, y = 30+CGFloat(i/6)*140
            let icon = NSImageView(frame:NSRect(x:x+10,y:y,width:64,height:64))
            icon.image = NSWorkspace.shared.icon(forFile:fixture.1)
            icon.imageScaling = .scaleProportionallyUpOrDown
            icon.setAccessibilityLabel(fixture.0); card.addSubview(icon)
            let label = NSTextField(labelWithString:fixture.0); label.alignment = .center
            label.font = .systemFont(ofSize:11,weight:.medium); label.textColor = .labelColor
            label.frame = NSRect(x:x,y:y+74,width:84,height:20); card.addSubview(label)
        }
        let button = NSButton(title:"Toggle Genie",target:self,action:#selector(toggle))
        button.frame = NSRect(x:325,y:535,width:150,height:36); root.addSubview(button)
        effect.failureHandler = { [weak self] in self?.restoreFallback() }
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
        if let index = CommandLine.arguments.firstIndex(of:"--record"), CommandLine.arguments.count > index+1 {
            let output = URL(fileURLWithPath:CommandLine.arguments[index+1],isDirectory:true)
            Task { @MainActor in
                do {
                    guard #available(macOS 15.2, *) else { throw NativeRecordingError.unavailable }
                    try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
                    try await Task.sleep(for:.seconds(2))
                    let recorder = try NativeVideoCapture(url:output.appendingPathComponent("genie-native.mp4"),width:1600,height:1200)
                    try await recorder.start(window:self.window)
                    try await Task.sleep(for:.seconds(0.8))
                    self.toggle(); try await Task.sleep(for:.seconds(1.1))
                    self.toggle(); try await Task.sleep(for:.seconds(1.5))
                    self.toggle(); try await Task.sleep(for:.seconds(1.1))
                    self.toggle(); try await Task.sleep(for:.seconds(0.24)); self.toggle()
                    try await Task.sleep(for:.seconds(1.4))
                    self.toggle(); try await Task.sleep(for:.seconds(1))
                    try await recorder.finish(metadata:output.appendingPathComponent("capture.json"))
                } catch { print("Native recording failed: \(error)") }
                NSApp.terminate(nil)
            }
        }
    }
    @objc private func toggle() {
        let opening = !expanded; expanded = opening
        if effect.isAnimating, effect.reverse(opening:opening,completion:{ [weak self] in self?.settled(opening) }) {
            phase.stringValue = opening ? "Reversing → Opening" : "Reversing → Closing"
            return
        }
        phase.stringValue = opening ? "Opening" : "Closing"
        plane.isHidden = false; backdrop.isHidden = false
        plane.layer!.shouldRasterize = true
        plane.layer!.rasterizationScale = window.backingScaleFactor
        // Rects share a bottom-left coordinate space; source corresponds to the
        // flipped card frame above. Target is a thin mouth above the button.
        let ok = effect.play(layer:plane.layer!,source:CGRect(x:80,y:130,width:640,height:320),
            viewport:CGRect(x:0,y:0,width:800,height:600),target:CGRect(x:360,y:68,width:80,height:0.5),
            direction:.bottom,opening:opening,backingScale:window.backingScaleFactor,backdropMask:backdropMask,materialInset:0,materialRadius:24,screen:window.screen) {
                [weak self] in self?.settled(opening)
            }
        if !ok { restoreFallback() }
    }
    private func settled(_ opening: Bool) {
        phase.stringValue = opening ? "Expanded" : "Collapsed"
        plane.isHidden = !opening; backdrop.isHidden = !opening; plane.layer?.shouldRasterize = false
    }
    private func restoreFallback() {
        effect.cancel(); expanded = true; plane.isHidden = false; backdrop.isHidden = false
        phase.stringValue = "Unavailable — restored"
        backdropMask.path = CGPath(roundedRect:CGRect(x:80,y:130,width:640,height:320),cornerWidth:24,cornerHeight:24,transform:nil)
        plane.layer?.shouldRasterize = false
        window.title = "Private mesh unavailable — content restored safely"
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { effect.cancel() }
}
enum NativeRecordingError: Error { case unavailable }

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let demo = Demo(); app.delegate = demo
    withExtendedLifetime(demo) { app.run() }
}
