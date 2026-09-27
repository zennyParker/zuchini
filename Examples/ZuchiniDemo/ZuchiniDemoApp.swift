import SwiftUI
import ZuchiniCore
import ZuchiniMenu

@main
@MainActor
struct ZuchiniDemoApp: App {
    var body: some Scene {
        WindowGroup { DemoRoot() }
    }
}

@MainActor
private struct DemoRoot: View {
    @StateObject private var store: MenuStore
    @State private var didOpenMenu = false

    init() {
        do {
            let definition = try AimbotMenu.definition()
            _store = StateObject(wrappedValue: MenuStore(definition: definition))
        } catch {
            preconditionFailure("Invalid menu definition: \(error)")
        }
    }

    var body: some View {
        ZuchiniOverlay(store: store) {
            ZStack {
                Color(red: 0.035, green: 0.045, blue: 0.065).ignoresSafeArea()
                RadialGradient(colors: [.orange.opacity(0.13), .clear],
                               center: .bottomLeading, startRadius: 10, endRadius: 650)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Text("ZUCCHINI").font(.caption.monospaced()).tracking(5)
                            .foregroundStyle(.white.opacity(0.45))
                        Image(systemName: "scope").font(.system(size: 64, weight: .ultraLight))
                            .foregroundStyle(.orange)
                        Text("Menu preview").font(.largeTitle.weight(.medium))
                        Text("Open the crosshair to configure Aimbot.")
                            .foregroundStyle(.white.opacity(0.65))
                        VStack(spacing: 8) {
                            Text(store.toggleValue(for: "aimbot.enabled") ? "Aimbot control: on" : "Aimbot control: off")
                            Text("\(store.choiceValue(for: "aimbot.target"))  /  FOV \(Int(store.numberValue(for: "aimbot.fov")))")
                            Text("Speed \(store.numberValue(for: "aimbot.speed"), specifier: "%.2f")")
                        }
                        .font(.subheadline.monospaced()).foregroundStyle(.orange)
                        Text("Standalone UI build. Game targeting is not connected.")
                            .font(.footnote).foregroundStyle(.white.opacity(0.45))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28).padding(.vertical, 70)
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.white)
        }
        .onAppear {
            guard !didOpenMenu else { return }
            didOpenMenu = true
            store.present()
        }
    }
}
