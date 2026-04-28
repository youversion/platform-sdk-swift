---
name: audit-swift
description: Audit Swift code for compliance with this project's style and conventions (access control, async/await, code organization, idioms, formatting). Use when writing new Swift code, reviewing a PR for style, or checking whether existing Swift code follows project rules.
---

# Auditing Swift code

Apply these rules when writing or reviewing Swift code in this project. They apply across all targets — `YouVersionPlatformCore`, `YouVersionPlatformUI`, and `YouVersionPlatformReader` — and to the example apps.

For naming guidance (types, functions, parameters, properties, cases), load the `naming` skill. For SwiftUI-specific rules, load `audit-swift-ui`.

## Style and idioms

- Prefer idiomatic, industry standard Swift style. Follow https://www.swift.org/documentation/api-design-guidelines/.
- Don't make whitespace-only changes.
- Prefer async-await to completion block-based API design.
- Prefer Swift Concurrency over Combine.
- Prefer `@Observable` to `ObservableObject`.
- ALWAYS mark ViewModel types as `@MainActor`.
- NEVER use locks (NSLock, etc.); prefer actors for isolation.
- When awaiting multiple independent async calls, run them concurrently with `async let` (or a task group) rather than serially with back-to-back `await`s.
- Don't build a new array with a `for` loop and `append`. Use `map`, `filter`, `compactMap`, `flatMap`, or `reduce` instead.
- Use local functions instead of inline closure blocks (`let x: () -> T = { ... }`).
- Don't unwrap optional closures with `if let` — use `closure?()`.
- If a function immediately `guard`s an Optional argument, make the argument non-Optional. The unwrap belongs at the call site, where the precondition stays explicit.
- When using `guard`, the `return`/`continue` belongs on a new line.
- Don't use `guard` in an overridden method to return early.
- Don't use a comma between logical expressions when `&&` will suffice.
- Use `Notification.Name("name")` not `Notification.Name(rawValue:)`, and `Notification.Name` not `NSNotification.Name`.

## Access control and mutability

- Make access controls on properties and functions as strict as they can be (`private`, `fileprivate`, `private(set)`, etc).
- Don't specify `internal` — it's the default.
- Prefer to make entity properties immutable (`let` over `var`).
- Classes should be marked `final` if they have no subclasses.
- Prefer structs over classes.
- For computed values with no arguments, prefer `var` over `func`.

## Initializers

- NEVER create objects starting with `.init(...)`.
- Don't override methods or initializers only to call `super`.
- Do not add a `deinit` solely to remove `NotificationCenter` observers — it's unnecessary.

## Code organization within a type

- Properties should be listed before all functions.
- Stored properties should be declared before all initializers.
- Derived properties and functions should be declared after all initializers.
- Sort imports alphabetically.

## Comments and dead code

- Don't add inline comments inside functions, but don't delete existing inline comments.
- Do add DocC comments to new, non-private functions, but not on SwiftUI initializers and body.
- No author attribution comment blocks (`// Created by`).
- Don't leave unused code.
- Do not leave commented-out code in place.

## Formatting

- Do not prepend `self.` when it is unnecessary.
- `else`/`catch` on the same line as the closing brace (`} else {`, `} catch {`).
- No blank lines at the top of `var`/`func`/`init` blocks.
- Always have one blank line between functions.
- Let the compiler infer types when possible.
- Use `""` over `String()` for empty strings.
- Use `private(set)` not `private (set)`.
- Use `private static` not `static private`.

## Naming summary

Detailed naming guidance lives in the `naming` skill — load it for anything name-related. The project-specific essentials:

- Avoid abbreviations; prefer clarity over brevity.
- Public-facing types should generally include "YouVersion" in their name (e.g. `YouVersionBigButtonStyle`, `SignInWithYouVersionView`) to disambiguate from client-local types.
- Class, struct, enum entity names should always be in PascalCase. Property and function names should always be in camelCase.
- Async functions with return values should have names that are noun phrases describing the return value rather than verb phrases and should never begin with "get", "load", "fetch", or "request".
- For Booleans, ensure that they start with a helping verb like "is", "should". "shows" and "showing" are also acceptable prefixes.
- Non-boolean entities should end with a word that indicates their data type (e.g. `shadowColor` rather than `colorShadow` for a Color).

## Localization

- Use existing localized strings if possible; prompt the user before adding new strings.

## Testing

- Use Swift Testing for unit tests, not XCTest.

## Platform support

- Code MUST support iOS 17 but can branch using `if #available(iOS ##.#, *)` checks.
