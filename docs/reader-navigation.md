# Reader navigation: take 3

The previous experiment is preserved on `YPE-4867-nav-bar-with-toolbars` at
`680d059`. This implementation starts from main on
`YPE-4867-nav-bar-with-toolbars-take-3` and follows the designer's revised rules.

## Inputs and decisions

| Input | Responsibility |
| --- | --- |
| `tabBarPlacement` | Top tabs put reader navigation at the bottom; bottom tabs put it at the top. |
| `.navigationPlacement(...)` | Preferred edge when there is no horizontal tab placement; defaults to bottom. |
| `toolbarVerticalEdge != nil` | Enables native toolbar items only with `.usesHostNavigationToolbar(true)`. No device-name or width heuristic. |
| `GeometryProxy.size.width` | Bounded label widths and centering; never changes which controls exist. |
| `safeAreaInsets` | The host's current usable content edges, including tab bar and native toolbar reservations. |
| `containerCornerInsets` | Horizontal clearance for window controls/rounded corners that intersect the top row. |
| Dynamic Type | Scales label budgets; custom pickers stack at accessibility sizes while retaining chapter arrows. |

The host tab placement is observed in a rendered background around the reader content. Earlier experiments found a direct read on the content modifier
could report nil while a rendered descendant received the real placement.

The reader's GeometryReader sits outside its own safe-area insets. This avoids
measuring geometry already altered by the custom navigation. The top row reserves corner width only where the corner extends below the top
safe inset, subtracting existing side safe insets. This lets the buttons sit
beside the window controls instead of reserving another row below them.
Corner geometry describes occupied space; it is not a direct Boolean reporting
the red/yellow/green window controls.

## Controls

Ordinary windows use custom controls at every width. Previous and next remain
inside the chapter capsule, with a separate version capsule. Scrolling down hides action buttons and replaces the pickers with a compact
chapter/version control; scrolling up or tapping that control restores them. An opaque upper background shields controls from
scrolled scripture; bottom navigation has a gradient behind it that reaches full opacity halfway
down and stays opaque through the bottom safe area.

Native vertical-toolbar mode puts chapter/version into one horizontal toolbar
item. Previous/next form a native ControlGroup and the menu is native, allowing
the system to place them on its vertical edge. Picker sheets are attached to
stable reader content so changing presentation does not remove their presenter.

The reader owns action placement; there is no external visibility or ordering configuration:

- Custom top navigation: Search stays beside the trailing menu.
- Native top navigation: Search is in the menu.
- Bottom navigation: Search beside the chapter picker.
- Search uses the existing reader search flow. An empty array removes optional actions.

Custom top pickers align to the outer leading edge of the centered reading
column, plus 16 pt, excluding the scripture's horizontal padding. On full-width
phone layouts this is 16 pt from the safe content edge. Corner reservations take
precedence so window controls remain clear. Search/menu remain trailing; picker
labels share the available width up to their bounded budget. Bottom navigation
remains centered. The preceding centered-top experiment is saved at `d76d943`.

When the host reports top tabs, the upper Search/menu row overlays the top safe
area rather than reserving another row below it. Its 60 pt height and 12 pt gap
above reading content align the action centers with the floating iPad tabs.
The overlay extends its hit-testing region through that safe area; native system
toolbars and bottom-tab layouts retain their existing presentation.

Labels have bounded budgets independent of their localized contents.
Overlong labels truncate rather than causing a different arrangement or pushing
controls into overflow. Accessibility sizes allow a two-line custom picker label.
Only symbols cap their scaling at xxxLarge so they stay inside their touch targets;
picker text continues to honor accessibility text sizes.
## Maintenance and testing

`ReaderNavigationLayout` owns the placement/action policy and has unit tests.
`ReaderNavigationBar` owns custom controls and sizing. `ReaderSystemToolbar` owns
native presentation. Established public initializer signatures remain intact;
reader modifiers configure placement and host-toolbar participation. Search
placement is reader-owned.

The sample app accepts `--reader-no-tabs` and `--reader-top`
for scenario testing, plus `--reader-width-debug` for a
centered width badge in debug builds.

Use Xcode 27.1 RC for the open Duo. Its active inner display must be captured with
`simctl io <device> screenshot --display=primary-1`; the default display can be
the inactive outer panel. Preserve the open state until closed-mode testing is
available. iPad resizing should use the actual window's bottom-right corner;
the resulting width is controlled by the OS and may differ from the drag target.

This iteration's simulator screenshots and earlier diagnostic notes are retained
outside the checkout under the task's `reader-navigation` artifact directory,
so switching branches does not remove them.

Validation: Xcode 27.1 RC simulator build, 588 Swift tests, strict SwiftLint, and
the public API stability check pass. Device checks include phone portrait and
landscape, iPad live resizing from 1032 pt to 375/536/787 pt, the open Duo,
scrolling, picker/search presentation, no-tab placement/action preferences,
accessibility text size, and right-to-left layout. Phone accessibility sometimes
reports `isHittable == false` despite successful picker taps; this was verified
with actual interactions. Closed Duo testing remains deferred to the user.

The reader no longer creates a NavigationStack for its main content. Native toolbar
participation requires `.usesHostNavigationToolbar(true)` and a host-owned navigation
container. The reader leaves host bar visibility and minimization unchanged.
