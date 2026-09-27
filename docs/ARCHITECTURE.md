# Architecture

`ZuchiniCore` owns immutable configuration and value normalization. It uses Foundation only and can be tested without a device. All control IDs are unique across the menu, action controls carry no stored value, slider input is bounded, and each store has independent state.

`ZuchiniMenu` owns main-actor UI state and views. Its public entry points are `MenuStore`, `MenuTheme`, `ZuchiniOverlay`, `ZuchiniPanel`, and `ZuchiniUIKit`. The store has no global singleton and creates no worker threads. The overlay belongs to the hosting view hierarchy; it neither discovers unrelated windows nor changes their levels. The UIKit adapter presents a regular view controller.

The app supplies configuration and responds to typed `MenuEvent` values. The library never assumes access to game state. The example's controls update only the example canvas. UI events are synchronous and should be fast; any future long-running host operation needs asynchronous scheduling, explicit cancellation, and a completion state rather than a main-thread wait.

When a SwiftUI scene becomes inactive, the floating panel closes while its session values remain in memory. No background workload is started. The panel uses a short, user-triggered transition and respects Reduce Motion. There are no continuous animation loops or polling tasks.

Current boundaries: no authentication, remote settings, telemetry, persistence, archive processing, injection, hooking, or signing tools. A future design can replace the panel view while reusing the state model. Adding user-requested persistence or networking later should be a separately tested change rather than a prerequisite for the UI.

The preserved Free Fire ZIP sits outside the source folder and outside all build inputs. This project does not reuse Monite's binary code, assets, or signatures and cannot reconstruct its proprietary implementation from screenshots.
