---
name: audit-swift-ui
description: Audit SwiftUI code for compliance with this project's view-specific conventions (Dynamic Type, @State privacy, view naming). Use when writing new SwiftUI views, reviewing a PR that touches SwiftUI, or checking whether existing SwiftUI code follows project rules.
---

# Auditing SwiftUI code

These rules are specific to SwiftUI views. For general Swift conventions, load the `audit-swift` skill. For naming guidance, load `naming`.

- Mark `@State` properties `private`.
- Do not use the suffix "Widget" for SwiftUI view names, as it conflicts with iOS home screen widgets (WidgetKit); use a more descriptive name instead.
- Use Dynamic Type text styles (`.body`, `.callout`, `.footnote`, etc.) instead of `.font(.system(size:))` so fonts adapt to the user's preferred text size.
- When using `Font.custom`, always include the `relativeTo:` parameter (e.g., `Font.custom("MyFont", size: 16, relativeTo: .callout)`) so custom fonts scale with Dynamic Type.
