import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

/// Captures the full display on explicit user demand only.
/// Uses ScreenCaptureKit exclusively (macOS 15+).
/// Zero background monitoring. No scheduled captures. No recording.
actor ScreenCapturer {

    func captureScreen() async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
            )
            guard let display = content.displays.first else { return nil }

            let filter = SCContentFilter(
                display: display,
                excludingApplications: [],
                exceptingWindows: []
            )

            let cfg = SCStreamConfiguration()
            cfg.width         = display.width  * 2   // Retina resolution
            cfg.height        = display.height * 2
            cfg.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            cfg.capturesAudio = false
            cfg.showsCursor   = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: cfg
            )
        } catch {
            // Likely a permissions issue — surface it to the caller as nil
            print("[ScreenCapturer] capture failed: \(error.localizedDescription)")
            return nil
        }
    }
}
