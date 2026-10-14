# Reader Navigation

## Navigation Configuration

### Overview

Use modifiers on `BibleReaderView` to set its preferred navigation position and allow native toolbar integration. Apply them to a reader created with a reference or restored from the last passage.

```swift
import SwiftUI
import YouVersionPlatform

struct ReaderScreen: View {
    var body: some View {
        BibleReaderView.restoringLastPassage()
            .navigationPlacement(.bottomBar)
    }
}
```

The reader includes book and chapter selection, previous and next chapter buttons, Bible version selection, and a menu. The modifiers configure their presentation without changing your app's tabs or tab selection.

| Modifier | Default | Description |
| --- | --- | --- |
| `.navigationPlacement(...)` | `.bottomBar` | Preferred reader navigation position when a horizontal host tab bar is not detected. |
| `.usesHostNavigationToolbar(...)` | `false` | Allows native toolbar items in a host-provided navigation container when the system uses vertical toolbars. |

### Position the Reader Navigation

On iOS 18 and later, the reader automatically places its navigation opposite a detected horizontal SwiftUI tab bar.

| Host tab bar | Reader navigation |
| --- | --- |
| Top | Bottom |
| Bottom | Top |
| No detected horizontal tab bar, including sidebar placement | Uses the preferred navigation placement |
| Tab placement detection unavailable, including iOS 17 | Uses the preferred navigation placement |

For example, an iPad window may show your app's tabs at the top when wide and at the bottom when narrow. The reader moves its navigation to the opposite edge as the tab placement changes. Your app does not need to select a width breakpoint.

`navigationPlacement(_:)` specifies a preference, but it is not a forced position. Setting `.topBar` does not keep the reader navigation at the top when a top tab bar is detected, and it does not move your app's tab bar.

For a reader without a tab bar, request top navigation as follows:

```swift
BibleReaderView.restoringLastPassage()
    .navigationPlacement(.topBar)
```

Omit the modifiers to use the defaults, including bottom navigation when no horizontal tab bar is detected:

```swift
BibleReaderView.restoringLastPassage()
```

### Support Tabs on iOS 17

Automatic tab placement detection is unavailable on iOS 17. If your reader is inside a bottom `TabView`, apply `.navigationPlacement(.topBar)` so the reader controls appear above the content.

```swift
struct TabbedReaderScreen: View {
    var body: some View {
        TabView {
            BibleReaderView.restoringLastPassage()
                .navigationPlacement(.topBar)
                .tabItem {
                    Label("Bible", systemImage: "book")
                }
        }
    }
}
```

Use this configuration across supported iOS versions; an availability check is unnecessary. On iOS 17, the reader uses your top preference. On iOS 18 and later, detected tab placement takes precedence, including when iPad tabs move to the top.

Without this preference, an iOS 17 reader uses its default bottom navigation even inside a bottom `TabView`. Its placement can therefore differ after an OS upgrade enables automatic detection.

For a custom tab bar that SwiftUI does not report, set the reader's preferred position opposite your tab bar. If your custom tab bar moves, update the value passed to `.navigationPlacement(...)`. There is no separate host-tab-location override in the current API.

### Use a Host Navigation Stack

The reader does not create a navigation stack for its main content. You can display it independently or push it onto your app's existing stack. It does not hide the host's navigation bar or Back button, or change the host's toolbar visibility. When native reader toolbar items are active, it disables navigation bar minimization so those actions remain available while the custom reader bar is collapsed.

By default, the reader uses custom controls even inside a navigation stack. To allow native controls in a system vertical-toolbar arrangement, opt in and provide the navigation container:

```swift
NavigationStack {
    BibleReaderView.restoringLastPassage()
        .usesHostNavigationToolbar(true)
}
```

If the reader is already a destination in your stack, apply the modifier there without adding another stack. The modifier grants permission to contribute toolbar items; it does not create a container or force native controls in ordinary horizontal layouts. Keep the host's toolbar visible when using native reader controls.

With a visible host navigation bar, custom reader controls can appear below it. Your app remains responsible for the host bar and its navigation actions. Reader sheets may provide their own separate navigation flows.


