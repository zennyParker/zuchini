import Foundation
import UIKit
import SwiftUI
import QuartzCore
import ZuchiniCore
import ZuchiniMenu

@MainActor
private final class GameHost: AimingHost {
    let runtime = ZucchiniRuntime()
    let store: MenuStore
    init(store: MenuStore) { self.store = store }

    func captureAimFrame() -> AimFrame? {
        guard let data = runtime.capture(target: store.choiceValue(for: "aimbot.target"),
                                         fov: store.numberValue(for: "aimbot.fov")),
              let sequence = data["sequence"] as? NSNumber,
              let time = data["capturedAt"] as? NSNumber,
              let origin = vector(data["origin"]), let forward = vector(data["forward"]),
              let targets = data["targets"] as? [[String: Any]] else { return nil }
        let candidates = targets.compactMap { target -> AimCandidate? in
            guard let id = target["id"] as? String else { return nil }
            return AimCandidate(id: id, head: vector(target["head"]), neck: vector(target["neck"]),
                                isEnemy: true, isAlive: true, isVisible: true)
        }
        return AimFrame(sequence: sequence.uint64Value, capturedAt: time.doubleValue,
                        cameraOrigin: origin, cameraForward: forward, candidates: candidates)
    }
    func applyAimCommand(_ command: AimCommand) -> Bool {
        runtime.apply(x: command.direction.x, y: command.direction.y, z: command.direction.z,
                      targetID: command.targetID, sequence: command.frameSequence)
    }
    private func vector(_ value: Any?) -> AimVector? {
        guard let values = value as? [NSNumber], values.count == 3 else { return nil }
        let vector = AimVector(values[0].doubleValue, values[1].doubleValue, values[2].doubleValue)
        return vector.isFinite ? vector : nil
    }
}

@MainActor
private final class MenuWindow: UIWindow {
    weak var store: MenuStore?
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let store else { return false }
        if store.isPresented || rootViewController?.presentedViewController != nil {
            return super.point(inside: point, with: event)
        }
        // Match ZuchiniOverlay's top-trailing 48-point launcher plus 12-point padding.
        return CGRect(x: bounds.width - safeAreaInsets.right - 60,
                      y: safeAreaInsets.top + 12, width: 48, height: 48).contains(point)
    }
}

@MainActor
private final class InjectionCoordinator: NSObject {
    static let shared = InjectionCoordinator()
    private let store: MenuStore
    private let host: GameHost
    private let controller: AimingController
    private var window: MenuWindow?
    private var displayLink: CADisplayLink?
    private var startupTimer: Timer?
    private var retries = 0
    private var lastReport = 0.0
    private var frameCount: UInt64 = 0
    private var longestCapture = 0.0
    private let logQueue = DispatchQueue(label: "zucchini.diagnostics")
    private let diagnosticsURL: URL

    override init() {
        // The static schema is covered by package tests; failure leaves injection inactive.
        let definition = try! AimbotMenu.definition()
        store = MenuStore(definition: definition)
        host = GameHost(store: store)
        controller = AimingController(store: store, host: host)
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        diagnosticsURL = documents.appendingPathComponent("zucchini-diagnostics.json")
        super.init()
    }

    func start() {
        guard startupTimer == nil, window == nil else { return }
        // The constructor can run before UIApplication has created its scene/window.
        startupTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self,
                                           selector: #selector(attachWhenReady), userInfo: nil, repeats: true)
        NotificationCenter.default.addObserver(self, selector: #selector(suspend),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc private func attachWhenReady() {
        retries += 1
        if retries > 240 { startupTimer?.invalidate(); startupTimer = nil; writeReport(); return }
        guard UIApplication.shared.applicationState == .active else { return }
        let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive && $0.windows.contains(where: { $0.isKeyWindow }) })
        // The supplied Unity app may still use an AppDelegate window without UIScene.
        guard scene != nil || UIApplication.shared.windows.contains(where: { $0.isKeyWindow }) else { return }
        startupTimer?.invalidate(); startupTimer = nil
        let overlay: MenuWindow
        if let scene { overlay = MenuWindow(windowScene: scene) }
        else { overlay = MenuWindow(frame: UIScreen.main.bounds) }
        overlay.store = store
        overlay.backgroundColor = .clear
        overlay.windowLevel = .normal + 1
        let view = ZuchiniOverlay(store: store) { Color.clear }
        let hosting = UIHostingController(rootView: view)
        hosting.view.backgroundColor = .clear
        overlay.rootViewController = hosting
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(exportDiagnostics(_:)))
        gesture.minimumPressDuration = 1.2
        overlay.addGestureRecognizer(gesture)
        window = overlay
        overlay.isHidden = false // Keep the game's existing key window for keyboard/input.
        store.present()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
        writeReport()
    }

    @objc private func tick() {
        let start = CACurrentMediaTime()
        if UIApplication.shared.applicationState != .active || store.isPresented || window?.rootViewController?.presentedViewController != nil || !store.toggleValue(for: "aimbot.enabled") {
            if controller.isActive { controller.suspend(); host.runtime.reset() }
        } else {
            if !controller.isActive { controller.activate() }
            _ = controller.step(clock: { CACurrentMediaTime() })
            longestCapture = max(longestCapture, CACurrentMediaTime() - start)
            frameCount += 1
        }
        if start - lastReport > 2 { lastReport = start; writeReport() }
    }

    @objc private func suspend() {
        controller.suspend(); host.runtime.reset(); store.dismiss(); writeReport()
    }

    private func reportData() -> Data? {
        let report: [String: Any] = [
            "product": "Zucchini experimental game integration",
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "gameVersion": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            "iOS": UIDevice.current.systemVersion,
            "runtimeStatus": host.runtime.status,
            "engineStatus": controller.lastDecision.status.rawValue,
            "enabled": store.toggleValue(for: "aimbot.enabled"),
            "target": store.choiceValue(for: "aimbot.target"),
            "fov": store.numberValue(for: "aimbot.fov"),
            "frameCount": frameCount,
            "captureCalls": host.runtime.reads,
            "appliedCommands": host.runtime.writes,
            "longestCaptureSeconds": longestCapture,
            "overlayAttached": window != nil,
            "deviceGameplayVerified": false
        ]
        return try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    }
    private func writeReport() {
        guard let data = reportData() else { return }
        let url = diagnosticsURL
        logQueue.async { try? data.write(to: url, options: .atomic) }
    }
    @objc private func exportDiagnostics(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, !store.isPresented,
              let root = window?.rootViewController else { return }
        controller.suspend(); host.runtime.reset()
        // Share a string snapshot, so export cannot race the periodic file write.
        guard let data = reportData(), let text = String(data: data, encoding: .utf8) else { return }
        let activity = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = root.view
        activity.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.maxX - 60, y: root.view.safeAreaInsets.top + 12, width: 48, height: 48)
        root.present(activity, animated: true)
    }
}

@_cdecl("zucchiniStart")
public func zucchiniStart() {
    DispatchQueue.main.async { InjectionCoordinator.shared.start() }
}
