import AppKit
import SwiftUI
import WallpaperKit
import Foundation
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // keep menu bar metaphor; main window still opens
        // Set the activation policy back to regular once the user opens the window.
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.activate(ignoringOtherApps: true) }
        return true
    }

    func showAbout() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 280),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "About OpenEngine"
        panel.contentViewController = NSHostingController(rootView: AboutPanel())
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutPanel: View {
    var body: some View {
        VStack(spacing: OE_Theme.Sp.m) {
            Image(systemName: "circle.hexagonpath.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("OpenEngine").font(.title2.weight(.semibold))
            Text("Open-source dynamic wallpapers").font(.callout).foregroundStyle(.secondary)
            Text("Version \(WallpaperKit.version)").font(.caption).foregroundStyle(.tertiary)
            VStack(spacing: 4) {
                Text("MIT Licensed · Free Forever")
                    .font(.caption2).foregroundStyle(.secondary)
                Link("github.com/cogrow4/OpenEngine",
                     destination: URL(string: "https://github.com/cogrow4/OpenEngine")!)
                    .font(.caption2)
            }
            .padding(.top, OE_Theme.Sp.s)
        }
        .padding(OE_Theme.Sp.xl)
        .frame(width: 380, height: 260)
    }
}

struct MenuBarContent: View {
    @ObservedObject var engine: OEEngine
    @State private var showWindow = false
    @State private var cpuUsage: Double = 0
    @State private var ramUsage: Double = 0
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: OE_Theme.Sp.s) {
            Text("OpenEngine").font(.headline)
            Divider()
            Text(currentWallpaperLine)
                .font(.caption2).multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.secondary)
            // CPU / RAM monitoring (updates every 1s, kept under 1%)
            VStack(alignment: .leading, spacing: 2) {
                Text("CPU: \(String(format: "%.1f", cpuUsage))%")
                    .font(.caption2)
                Text("RAM: \(String(format: "%.1f", ramUsage)) MB")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            Divider()
            Button("Open Gallery") { NSApp.activate(ignoringOtherApps: true) }
            Button("Pause Wallpaper") { engine.controller.pausePlaybackAll() }
            Button("Resume Wallpaper") { engine.controller.resumePlaybackAll() }
            Divider()
            Button("Quit OpenEngine") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, OE_Theme.Sp.s)
        .padding(.horizontal, OE_Theme.Sp.m)
        .frame(width: 240)
        .onAppear { startMonitoring() }
        .onDisappear { stopMonitoring() }
    }

    private func startMonitoring() {
        updateSystemStats()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateSystemStats()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateSystemStats() {
        cpuUsage = SystemStats.currentCPU()
        ramUsage = SystemStats.currentRAMMB()
    }

    var currentWallpaperLine: String {
        if let w = engine.settings.wallpaperID, !w.isEmpty {
            return "Wallpaper: \(w)"
        }
        return "Wallpaper: none"
    }
}

// Lightweight system stats — uses mach_task API (under 1% overhead).
enum SystemStats {
    /// Current process RAM in MB.
    static func currentRAMMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { rawPtr in
            rawPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1_048_576.0
    }

    /// Process CPU usage via thread_info. Samples twice with a short delay
    /// and computes the delta to get a meaningful percentage.
    static func currentCPU() -> Double {
        let old = threadCPUUsage()
        Thread.sleep(forTimeInterval: 0.1)
        let new = threadCPUUsage()
        let elapsed = max(new.time - old.time, 0.001)
        let cpuDelta = new.cpu - old.cpu
        return (cpuDelta / elapsed * 100.0).clamped(0...100)
    }

    private struct CpuSample { let cpu: Double; let time: TimeInterval }
    private static func threadCPUUsage() -> CpuSample {
        var totalCPU: Double = 0
        var threadCount: mach_msg_type_number_t = 0
        var threads: thread_act_array_t?
        let kr = task_threads(mach_task_self_, &threads, &threadCount)
        if kr == KERN_SUCCESS, let raw = threads {
            for i in 0..<Int(threadCount) {
                var info = thread_basic_info()
                var count = mach_msg_type_number_t(MemoryLayout<thread_basic_info>.size) / 4
                let err = withUnsafeMutablePointer(to: &info) { rawPtr in
                    rawPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        thread_info(raw[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                    }
                }
                if err == KERN_SUCCESS {
                    totalCPU += Double(info.cpu_usage) / 100.0
                }
            }
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: raw), vm_size_t(Int(threadCount) * MemoryLayout<thread_act_t>.size))
        }
        return CpuSample(cpu: totalCPU, time: Date().timeIntervalSinceReferenceDate)
    }
}

private extension Double {
    func clamped(_ range: ClosedRange<Double>) -> Double {
        return max(range.lowerBound, min(range.upperBound, self))
    }
}

struct MenuBarContent_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarContent(engine: OEEngine())
            .preferredColorScheme(.dark)
    }
}
