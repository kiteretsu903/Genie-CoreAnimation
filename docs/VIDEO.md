# Demo recording

`media/genie-ca-live-blur.mp4` records the running AppKit demo with an original glacier background, built-in macOS app icons, and ordinary live `NSVisualEffectView` blur. The blur stays outside the animated mesh; a synchronized shape mask follows the same trajectory as the icons and labels.

The clip shows closing, opening, and a mid-motion reversal with 0.5-second transitions. A label beneath the title displays the live animation phase: Opening, Closing, Reversing, Expanded, or Collapsed. It is a real window recording, not a pre-rendered mesh illustration. Capture timing depends on the display and system load; an encoded frame rate is not a runtime compositor performance guarantee.

## Included capture

The included video is 1600 × 1200, exported at 60 fps from a variable-frame-rate ScreenCaptureKit recording. The capture delivered 163 changed frames with no encoder rejections. Among sample intervals shorter than 50 ms, the median interval was 16.61 ms (about 60 samples per second). Longer gaps include static holds. Export fills those gaps by repeating frames; it uses no optical-flow interpolation or generated motion frames. The actual timestamps are preserved in [`media/genie-ca-capture.json`](media/genie-ca-capture.json).

## Reproduce

Recording requires macOS 15.2+ and Swift. Use a new output directory:

```sh
scripts/record-demo.sh /tmp/genie-live-recording
```

Select the **Genie-CoreAnimation** window in the macOS sharing picker. The recorder accepts only that demo window; it does not capture other windows, audio, or the pointer. It then runs the short animation sequence automatically and writes `genie-native.mp4` plus `capture.json` with the actual captured sample timestamps. The recorder requests up to 120 frames per second; unchanged frames can be reported as idle by ScreenCaptureKit.

To create the README video and poster from a successful capture:

```sh
ffmpeg -i /tmp/genie-live-recording/genie-native.mp4 -vf fps=60 \
  -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p \
  -movflags +faststart -an docs/media/genie-ca-live-blur.mp4
ffmpeg -ss 2.8 -i /tmp/genie-live-recording/genie-native.mp4 \
  -frames:v 1 -q:v 2 docs/media/genie-ca-poster.jpg
```

The helper creates an ad hoc signed temporary app bundle so the system picker can identify the demo. The built-in app icons are read from the installed operating system, so they vary with macOS version. The bundled glacier artwork is an original generated image.

## GitHub presentation

The README uses a linked poster because repository-relative MP4 files are not guaranteed to play inline in GitHub Markdown. For an inline player after publication, upload the MP4 to the README editor and replace the poster/link with GitHub’s generated attachment URL.
