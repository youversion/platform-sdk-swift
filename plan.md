# Just-In-Time Data Exchange Permissions Plan

This plan is written as a checklist so multiple agents can implement independent pieces. Agents are not alone in this codebase: avoid reverting unrelated edits, keep changes scoped to the owned files for each task, and coordinate if a task needs to touch another task's file.

## Open Questions To Resolve First

- [ ] Confirm the browser flow query parameter names for `/data-exchange`.
  - Proposed placeholders: `token=<data exchange token>` and `app_key=<app key>`.
  - The API spec only explicitly names `/data-exchange/token` query parameters, not the browser flow query names.
- [ ] Confirm the exact response schema for `DataExchangeToken`.
  - Proposed placeholder: `{ "token": String }`.
  - If the OpenAPI component uses a different key, match that schema exactly.
- [x] Confirm the exact request schema for `DataExchangeTokenCreate`.
  - Proposed placeholder: `{ "permissions": [String] }`.
  - Encode `SignInWithYouVersionPermission` raw values, sorted for stable tests.

## Task 1: Core API URL Support

Owner files:

- `Sources/YouVersionPlatformCore/APIs/URLBuilder.swift`
- `Tests/YouVersionPlatformCoreTests/URLBuilderTests.swift`

Checklist:

- [ ] Add `URLBuilder.dataExchangeTokenURL(appKey:appID:)`.
  - Path: `/data-exchange/token`.
  - Include `x-yvp-app-key` when an app key is provided.
  - Include `x-yvp-app-id` when an app ID is provided.
  - Allow either query item to be absent, but callers should normally pass app key.
- [ ] Add `URLBuilder.dataExchangeURL(token:appKey:)`.
  - Path: `/data-exchange`.
  - Include the short-lived data exchange token query parameter.
  - Include the app key query parameter.
- [ ] Add URLBuilder tests for both helpers.
  - Verify path.
  - Verify query values via `URLComponents` rather than depending on query ordering.

## Task 2: Core Data Exchange API

Owner files:

- `Sources/YouVersionPlatformCore/APIs/DataExchange/DataExchange.swift`
- `Sources/YouVersionPlatformCore/APIs/Users/SignInWithYouVersionPermission.swift`
- `Tests/YouVersionPlatformCoreTests/DataExchangeAPITests.swift`
- `Tests/YouVersionPlatformCoreTests/UsersModelsTests.swift`

Checklist:

- [x] Add `case highlights` to `SignInWithYouVersionPermission`.
- [x] Add or update permission model tests for the new `highlights` raw value.
- [x] Add `public extension YouVersionAPI { enum DataExchange { ... } }`.
- [x] Add public response model `DataExchangeToken`.
  - Make it `Codable`, `Sendable`, and `Equatable`.
  - Keep the public surface minimal until the schema is confirmed.
- [x] Add private request body model `DataExchangeTokenCreate`.
- [x] Add `public static func token(...) async throws -> DataExchangeToken`.
  - Suggested signature:
    `token(permissions: Set<SignInWithYouVersionPermission>, accessToken providedToken: String? = nil, session: URLSession = .shared)`.
  - Use a noun phrase because it returns a value.
  - Require an access token or throw `YouVersionAPIError.missingAuthentication`.
  - Require `YouVersionPlatformConfiguration.appKey` or throw `YouVersionAPIError.missingAuthentication`.
  - POST to `URLBuilder.dataExchangeTokenURL(appKey:appID:)`.
  - Set `Authorization: Bearer <access token>`.
  - Set `Content-Type: application/json`.
  - Preserve additional test-session headers using `YouVersionAPI.urlRequest(...)` or equivalent existing pattern.
  - Decode only HTTP `201` as success.
  - Map `401` to `YouVersionAPIError.notPermitted`.
  - Map non-HTTP response to `YouVersionAPIError.invalidResponse`.
  - Map other unexpected statuses to `YouVersionAPIError.cannotDownload`.
- [ ] Add tests for:
  - Successful request method, path, query, `Authorization`, `Content-Type`, JSON body, and decoded token.
  - Missing app key throws `missingAuthentication`.
  - Missing access token throws `missingAuthentication`.
  - `401` throws `notPermitted`.
  - Unexpected status throws `cannotDownload`.
  - Non-HTTP response throws `invalidResponse`.
  - Malformed JSON throws a decoding error.

## Task 3: Persist Granted Data Exchange Permissions

Owner files:

- `Sources/YouVersionPlatformCore/YouVersionPlatformConfiguration.swift`
- `Tests/YouVersionPlatformCoreTests/YouVersionPlatformConfigurationTests.swift`

Checklist:

- [ ] Add storage for granted data exchange permissions.
  - Suggested private UserDefaults key: `YouVersionPlatformDataExchangePermissions`.
  - Store raw permission strings.
- [ ] Add `public static func hasDataExchangePermission(_ permission: SignInWithYouVersionPermission) -> Bool`.
- [ ] Add `@MainActor public static func saveDataExchangePermission(_ permission: SignInWithYouVersionPermission)`.
- [ ] Add a helper for saving multiple permissions if the browser grants a set later, but keep it private unless needed publicly.
- [ ] Clear granted data exchange permissions from `clearAuthTokens()`.
  - Signing out should remove highlight permission state.
- [ ] Add tests for:
  - Saving and reading a permission.
  - Unknown or absent permissions return false.
  - `clearAuthTokens()` clears saved data exchange permissions.

## Task 4: UI Data Exchange Browser Session

Owner files:

- `Sources/YouVersionPlatformUI/APIs/DataExchangeSession.swift`
- `Tests/YouVersionPlatformUITests/DataExchangeSessionTests.swift` if practical, otherwise core-only helper tests for parsing.

Checklist:

- [ ] Add a public result enum.
  - Suggested shape:
    `public enum DataExchangeRequestResult: String, Sendable { case granted; case cancelled = "cancel" }`.
- [ ] Add a public `DataExchangeSession` type alongside `Users+SignIn.swift`.
  - Keep a strong reference to `ASWebAuthenticationPresentationContextProviding`.
  - Guard with `#if canImport(AuthenticationServices)`.
  - Keep unsupported platforms consistent with the existing sign-in implementation.
- [ ] Add `@MainActor public func requestDataExchange(permissions: Set<SignInWithYouVersionPermission>) async throws -> DataExchangeRequestResult`.
  - This exact method name is intentional placeholder API shape.
  - Call `YouVersionAPI.DataExchange.token(...)`.
  - Build `/data-exchange` with the returned token and app key.
  - Start `ASWebAuthenticationSession`.
  - Use a callback URL scheme similar to sign-in, for example `youversionauth://callback`.
  - Parse `status` from the callback URL query.
  - Return `.granted` for `status=granted`.
  - Return `.cancelled` for `status=cancel`.
  - Throw `URLError(.badServerResponse)` for missing or unknown statuses.
  - When result is `.granted`, save each requested permission via `YouVersionPlatformConfiguration.saveDataExchangePermission`.
- [ ] Extract status parsing into a small internal/static helper if direct `ASWebAuthenticationSession` tests are not practical.
- [ ] Add tests for status parsing:
  - `status=granted`.
  - `status=cancel`.
  - Missing `status`.
  - Unknown status.

## Task 5: Reader View Model Flow

Owner files:

- `Sources/YouVersionPlatformReader/ViewModels/BibleReaderViewModel.swift`
- `Sources/YouVersionPlatformReader/ViewModels/BibleReaderViewModel+Navigation.swift`
- `Sources/YouVersionPlatformReader/ViewModels/BibleReaderAuthentication.swift`
- `Tests/YouVersionPlatformReaderTests/BibleReaderViewModelSignInTests.swift`
- Add `Tests/YouVersionPlatformReaderTests/BibleReaderViewModelDataExchangeTests.swift` if clearer.

Checklist:

- [ ] Extend `BibleReaderAuthentication` with data exchange permission reads.
  - Suggested closure: `hasDataExchangePermission: @MainActor (SignInWithYouVersionPermission) -> Bool`.
  - Default implementation should call `YouVersionPlatformConfiguration.hasDataExchangePermission`.
  - Update test support factory methods to supply deterministic values.
- [ ] Add view-model state for a pending highlight add.
  - Suggested private state: selected references and color string.
  - Keep the state typed, not stringly beyond the color hex.
- [ ] Add `var showingDataExchangeConfirmation = false`.
- [ ] Add `var startDataExchangeFlow = false`.
- [ ] Change `addVerseColor(_:)`.
  - If `.highlights` permission is already granted, behave as today.
  - If permission is missing, store the pending highlight and begin the JIT flow.
  - If signed out and sign-in is enabled, start the sign-in flow first.
  - If sign-in is disabled or cannot start, do not add highlights.
- [ ] Add a method called after sign-in succeeds.
  - If a pending highlight exists and permission is still missing, show the confirmation dialog.
- [ ] Add a method for confirming the data exchange prompt.
  - Set `startDataExchangeFlow = true`.
- [ ] Add a method for cancelling the data exchange prompt.
  - Clear pending highlight state.
  - Do not modify highlights.
- [ ] Add a method for completing the data exchange flow.
  - On `.granted`, apply the pending highlight, remove selection, and clear pending state.
  - On `.cancelled`, clear pending state and leave highlights unchanged.
- [ ] Add tests for:
  - Highlight add proceeds immediately when permission already granted.
  - Signed-in user without permission stores pending highlight and shows confirmation.
  - Confirmation cancel clears pending state and does not create highlights.
  - Confirmation accept sets `startDataExchangeFlow`.
  - Data exchange granted applies pending highlight and clears selection.
  - Data exchange cancelled does not apply pending highlight.
  - Signed-out user starts sign-in before showing the data exchange confirmation.
  - After sign-in success, pending highlight shows the data exchange confirmation.

## Task 6: Reader View UI Wiring

Owner files:

- `Sources/YouVersionPlatformReader/BibleReaderView.swift`
- `Sources/YouVersionPlatformUI/Resources/Localizable.xcstrings` if new localized strings are added.

Checklist:

- [ ] Add a confirmation dialog or alert for the data exchange permission prompt.
  - Prefer existing localized strings if possible.
  - If new strings are required, add them to `Localizable.xcstrings`.
  - Suggested copy: ask permission to connect with YouVersion so highlights can be saved.
- [ ] Add an `.onChange(of: viewModel.startDataExchangeFlow)` handler.
- [ ] In the handler:
  - Reset `startDataExchangeFlow`.
  - Create/use `DataExchangeSession` with the existing `contextProvider`.
  - Call `requestDataExchange(permissions: [.highlights])`.
  - Pass the result back to the view model.
  - Log errors with `YouVersionPlatformLogger`.
- [ ] Update the existing sign-in completion path.
  - After `await viewModel.updateSignInState()`, notify the view model so it can continue pending data exchange work.
- [ ] Remove `dump(result)` from the sign-in path if still present while touching this code.
- [ ] Keep tvOS compile behavior correct.
  - Existing `ASWebAuthenticationSession` handling has platform conditionals; match those patterns.

## Task 7: Sample App Profile Button

Owner files:

- `Examples/SampleApp/ProfileView.swift`

Checklist:

- [ ] Add a signed-in-only button: `Request highlights permission`.
- [ ] Reuse the existing `contextProvider`.
- [ ] Call `DataExchangeSession(contextProvider: contextProvider).requestDataExchange(permissions: [.highlights])`.
- [ ] Show simple status text for granted, cancelled, or error.
- [ ] Keep the existing sign-in and sign-out sample behavior intact.

## Task 8: Documentation

Owner files:

- `README.md`

Checklist:

- [ ] Add a short section under Bible Reader or Sign In explaining just-in-time highlight permissions.
- [ ] Document that `BibleReaderView` prompts only when needed.
- [ ] Document custom usage through `DataExchangeSession.requestDataExchange(permissions:)`.
- [ ] Mention that the placeholder API may change if product/API naming is still unsettled.

## Task 9: Final Verification

Checklist:

- [ ] Run `swift test`.
- [ ] Run SwiftLint:
  `LINUX_SOURCEKIT_LIB_PATH=/root/.local/share/swiftly/toolchains/6.1.3/usr/lib swiftlint --strict`
- [ ] If public API changed, consider running:
  `scripts/check-api-stability.sh check`
- [ ] Review `git diff` for unrelated changes.
- [ ] Confirm pre-existing local edits in these files were not reverted:
  - `Examples/SampleApp/SampleApp.swift`
  - `Sources/YouVersionPlatformCore/APIs/Bible/Highlights.swift`
