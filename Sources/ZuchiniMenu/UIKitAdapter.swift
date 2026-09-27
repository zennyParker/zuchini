#if canImport(UIKit) && canImport(SwiftUI)
import SwiftUI
import UIKit

/// Present the menu from a view controller in an app you own/control.
/// Retain the store in your scene; UIKit manages presentation lifecycle.
@MainActor
public enum ZuchiniUIKit {
    public static func makeViewController(
        store: MenuStore,
        theme: MenuTheme = MenuTheme()
    ) -> UIViewController {
        let controller = UIHostingController(rootView: HostedMenu(store: store, theme: theme))
        controller.view.backgroundColor = .clear
        controller.modalPresentationStyle = .pageSheet
        controller.sheetPresentationController?.detents = [.medium(), .large()]
        controller.sheetPresentationController?.prefersGrabberVisible = true
        return controller
    }
}

@MainActor
private struct HostedMenu: View {
    @ObservedObject var store: MenuStore
    let theme: MenuTheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZuchiniPanel(store: store, theme: theme)
            .onAppear { store.present() }
            .onDisappear { store.dismiss() }
            .onChange(of: store.isPresented) { presented in
                if !presented { dismiss() }
            }
    }
}
#endif
