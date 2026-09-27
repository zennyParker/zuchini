# Architecture

`ZuchiniCore` owns immutable configuration and session values. IDs are unique, slider values are bounded and normalized, and choice values must belong to a validated set. `AimbotMenu.definition()` declares the one-section product menu: enabled, target, FOV. It does not implement aiming.

`ZuchiniMenu` owns main-actor UI state and views. Public entry points are `MenuStore`, `MenuTheme`, `ZuchiniOverlay`, `ZuchiniPanel`, and `ZuchiniUIKit`. Each host/scene retains its own store. The overlay stays in the host view hierarchy; it creates no additional window. The UIKit adapter uses a standard hosting controller.

The panel uses an orange accent, dark control cards, a checkbox-style toggle, an inline expanding choice list, and native sliders. A fixed header keeps dismissal accessible while the body scrolls. No section navigation is rendered for the single-section Aimbot menu. Generic multi-section definitions remain supported.

The demo calls `present()` once on its first appearance. Closing exposes the crosshair launcher. Backgrounding closes the panel while retaining session values, and does not automatically reopen it on foregrounding. A fresh process resets values and opens the panel. The overlay respects Reduce Motion; no continuous animation loops or polling tasks run.

Typed `MenuEvent.valueChanged` callbacks carry `.toggle`, `.number`, or `.choice` values. Hosts supply gameplay behavior separately. The example only shows the current values on its own preview screen. It does not read or manipulate game state. There is no network, authentication, persistence, telemetry, archive modification, or signing code in the application.

See `../project.md` for the intended product and missing Free Fire integration contract. Build outputs are a standalone preview, never a modified game archive.

`AimingEngine` performs portable snapshot-to-command calculation. `AimingController` reads the same MenuStore and routes commands to a weakly held `AimingHost` on the main actor; it begins inactive and owns no frame loop. Its Apple-only tests use a fake host. No production game adapter implements this protocol yet. Details and timing/coordinate contracts are in `AIMING.md`.
