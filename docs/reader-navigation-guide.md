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
| `.usingNavigationStack(...)` | `.none` | Sets whether the reader uses custom controls, shares the host navigation bar, or manages a dedicated host stack’s navigation bar. |

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

The reader does not create a navigation stack for its main content. Use `.usingNavigationStack(...)` to describe how it may use a stack supplied by your app.

| Option | Behavior |
| --- | --- |
| `.none` (default) | Uses custom reader controls. Does not add native toolbar items or change the host’s navigation bar. A stack is not required. |
| `.shared` | Adds native reader actions e.g. when the system uses a vertical toolbar. Preserves the host’s navigation-bar visibility and minimization settings. |
| `.justForReader` | Adds native reader actions and keeps the vertical toolbar visible, even when custom reader controls collapse. May hide the horizontal navigation bar to avoid an empty row above the custom controls. |

Both `.shared` and `.justForReader` require a host-provided navigation stack. These options do not force native controls in ordinary horizontal layouts. Navigation-bar visibility management applies on iOS and iPadOS.

For a stack dedicated to the reader, such as the root of a Bible tab:

```swift
NavigationStack {
    BibleReaderView.restoringLastPassage()
        .usingNavigationStack(.justForReader)
}
```

Choose `.shared` when your app needs to preserve its navigation title, Back button, or other toolbar items. Apply it to the reader inside your existing stack; do not add a nested stack. Your app controls visibility and minimization, and must keep the system bar visible when it contains native reader actions.

Choose `.justForReader` only when the reader may manage the entire navigation bar. Hiding the horizontal bar also hides any host title, Back button, and toolbar items in that bar.

With `.none`, an existing host navigation bar is left alone and can still occupy space above the custom reader controls. The option disables reader integration; it does not remove an existing stack or its bar. Reader sheets may provide their own separate navigation flows.
