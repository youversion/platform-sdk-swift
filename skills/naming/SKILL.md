---
name: naming
description: Name Swift entities (types, protocols, functions, parameters, properties, local variables, cases) following Apple's Swift API Design Guidelines and this project's conventions. Use when introducing or renaming any identifier in Swift code, reviewing a PR for naming, or deciding between candidate names.
---

# Naming Entities in Swift

The goal of a name is **clarity at the point of use**. A name succeeds when a reader who has never seen the call site can predict what it does, what type it is, and how it fits with the code around it. A name fails when it forces the reader to pause and think *"why is this one different?"* or *"what does that abbreviation stand for?"*

Apply these rules any time you introduce or rename a type, protocol, function, method, parameter, property, local variable, enum case, or generic parameter.

---

## 1. Hard rules

These are non-negotiable on this project.

### No abbreviations

Abbreviations force the reader to decode. Write the full word.

```swift
// No
let usr: User
let btnTitle: String
let createdDt: Date
let msgCount: Int
func calc(...) -> Int
class NoteMgr { ... }

// Yes
let user: User
let buttonTitle: String
let createdDate: Date
let messageCount: Int
func calculate(...) -> Int
class NotesManager { ... }
```

Narrow exceptions:
- **Deeply precedented domain terms** that everyone in that field would recognize: `sin`, `cos`, `url`, `id`, `json`, `html`. If a reasonable web search on the abbreviation alone would confirm the meaning, it is fine.
- **Established acronyms** already in the platform: `URL`, `UUID`, `HTTP`, `JSON`.

Acronyms follow the Swift case convention: uniformly upper-cased when capitalized (`URL`, `UTF8`), uniformly lower-cased otherwise (`urlString`, `jsonDecoder`). Never `Url` or `urlDecoderUrl`.

### No restating context

Inside a type, a property name should not repeat the enclosing type's name. The context is already obvious.

```swift
// No
struct BibleVersion {
    let versionTitle: String
    let bibleVersionAbbreviation: String
    let versionID: Int
}

// Yes
struct BibleVersion {
    let title: String
    let abbreviation: String
    let id: Int
}
```

Same for function parameters — do not restate the function's subject in each label:

```swift
// No
func updateVersion(versionTitle: String, versionAbbreviation: String) { ... }

// Yes
func updateVersion(title: String, abbreviation: String) { ... }
```

### Prefer product-focused names over technical names

When a shorter, more product-focused name conveys nearly all the meaning, use it. Multi-word internal-implementation names are a smell.

```swift
// No — technical, implementation-leaking, long
class NoteObjectStateSyncMachine { ... }
class UserDataRepositoryCoordinator { ... }
class PlanReadingProgressStateHandler { ... }

// Yes — what the thing is, in product terms
class NotesManager { ... }
class UserRepository { ... }
class PlanProgress { ... }
```

Ask *"what does this do for the product?"* and name from that vocabulary. Save specificity for the handful of cases where the role really is the distinguishing thing.

### A name must imply its type

A reader should be able to guess the type from the name without jumping to the declaration. Be consistent with the shape already used in nearby code.

| Type             | Suffix / shape                                  | Examples                                 |
| ---------------- | ----------------------------------------------- | ---------------------------------------- |
| `Date`           | `...Date`                                       | `createdDate`, `expirationDate`          |
| `TimeInterval`   | `...Duration`, `...Interval`, `...Seconds`      | `animationDuration`, `timeoutSeconds`    |
| `URL`            | `...URL`                                        | `avatarURL`, `shareURL`                  |
| `String` (URL)   | `...URLString`                                  | `avatarURLString`                        |
| `Bool`           | `is...`, `has...`, `can...`, `should...`        | `isHidden`, `hasUnread`, `canDismiss`    |
| Count            | `...Count`                                      | `messageCount`, `unreadCount`            |
| Array            | pluralize                                       | `friends`, `savedMoments`                |
| Dictionary       | `...By...` or descriptive pair                  | `usersByID`                              |
| Identifier       | `...ID` (when not the primary `id` of the type) | `userID`, `planID`                       |
| Closure          | verb phrase describing what it does             | `onTap`, `onLoad`, `didSelect`           |

Do not invent a new shape when a nearby one exists. If surrounding code uses `createdDate`, do not introduce `createdOn` or `createdAt` or `createdDt` — match the established pattern. **Never make the reader think "why is this similar-looking thing different from the other cases?"**

### Consistency with nearby code wins

Before naming a new thing, read the file and the module around it. If there is an existing convention — suffix, verb, parameter label order, collection naming — follow it. A technically better name that breaks a local pattern is worse than the local pattern.

---

## 2. Choosing the base name

### Name by role, not by type

Use the *role* the value plays in the code, not its class name.

```swift
// No
let string: String
let view: UIView
let array: [YVNPerson]

// Yes
let greeting: String
let avatarView: UIView
let suggestedFriends: [YVNPerson]
```

### Include just enough — no more, no less

> Every word in a name should convey salient information at the use site.

Two failure modes:

1. **Too few words** → ambiguous. `remove(x)` could mean "remove the first equal element" or "remove at index x". `remove(at: x)` makes it clear.
2. **Too many words** → noise. If `view.backgroundColor` already tells you it is a color, don't write `view.backgroundColorColor` or `view.backgroundColorValue`.

### Compensate for weak type information

When a parameter's type is `Any`, `NSObject`, `String`, `Int`, a closure, or similar, add a noun that describes its role:

```swift
// No — "add what?"
func add(_ observer: Any)

// Yes
func addObserver(_ observer: Any)
```

---

## 3. Functions and methods

### Functions that return a value are noun phrases, not verb phrases

If a function's job is to **produce and hand back a value**, its name describes that value. Think of the call site as reading "the … of x", not "do something to x".

This applies to every kind of value-returning function — synchronous, async, throwing, static, free functions, computed helpers. Not just async. Not just API methods.

Never start a value-returning function with `get`, `load`, `fetch`, `request`, `build`, `compute`, `calculate`, `retrieve`, or `find`. Reserve `make` exclusively for factory methods per Apple's guidelines.

```swift
// No — verb phrases for something that just returns a value
func getUser(id: String) async throws -> User
func fetchSuggestedFriends() async throws -> [Person]
func loadPlans() async throws -> [Plan]
func calculateTotalPrice() -> Decimal
func buildAttributedTitle() -> NSAttributedString
func findMatchingVerse(in chapter: Chapter) -> Verse?

// Yes — noun phrases that describe the returned value
func user(withID id: String) async throws -> User
func suggestedFriends() async throws -> [Person]
func plans() async throws -> [Plan]
func totalPrice() -> Decimal
func attributedTitle() -> NSAttributedString
func matchingVerse(in chapter: Chapter) -> Verse?
```

Read the call site out loud: `let verse = matchingVerse(in: chapter)` reads as "let verse equal the matching verse in chapter" — natural. `let verse = findMatchingVerse(in: chapter)` reads as an instruction, not an expression.

Exceptions (narrow):
- **Booleans** read as assertions, so they start with `is` / `has` / `can` / `should` — these are verbs but they *are* the noun-phrase form for booleans. `isEmpty`, `hasUnread`, `canDismiss`.
- **Factory methods** start with `make` per Apple's guidelines: `makeIterator()`.
- **Mutating/nonmutating pairs** — the `-ed`/`-ing` form of a verb (`sorted()`, `reversed()`, `strippingNewlines()`) returns a value and keeps the verb root; that is the intended form for the non-mutating sibling of a verb-rooted mutating operation.

### Functions with side effects are imperative verb phrases

```swift
func dismissSuggestion(...)        // does a thing
func reload()                      // does a thing
func sort()                        // mutates in place
```

In UIKit code on this project, function names are verb phrases: `setUp` not `setup`.

### What if a function both returns a value *and* has side effects?

Prefer splitting it — one side-effecting method and one accessor — so each name tells the truth. If you can't split it, name it for the dominant purpose. If the caller primarily wants the returned value, name it as a noun phrase. If the caller primarily wants the side effect and the return value is incidental (like `@discardableResult` status codes or inserted elements), name it as an imperative verb phrase.

### Mutating / non-mutating pairs

- **Verb-rooted:** imperative mutates, `-ed`/`-ing` returns a new value.
  `x.sort()` ↔ `x.sorted()`, `x.reverse()` ↔ `x.reversed()`.
- **Noun-rooted:** the noun form returns a new value, `form-` prefix mutates.
  `a.union(b)` ↔ `a.formUnion(b)`.

### Boolean methods and properties read as assertions

```swift
x.isEmpty
line1.intersects(line2)
user.hasUnreadMessages
```

### Factory methods start with `make`

```swift
func makeIterator() -> Iterator
```

### Computed vars vs functions

A zero-argument, side-effect-free accessor is a `var`, not a `func`:

```swift
// No
func displayName() -> String { ... }

// Yes
var displayName: String { ... }
```

---

## 4. Argument labels

The goal is for the call site to read like a grammatical English phrase.

### First-argument labels

- **Initializers and factory methods:** the first argument label does *not* form part of a phrase starting with the base name. Write `Color(red: 32, green: 64, blue: 128)`, not `Color(havingRGBValuesRed: 32, ...)`.
- **Value-preserving conversions:** first label is `_`. `Int64(someUInt32)`.
- **Narrowing conversions:** use a descriptive label. `Int(truncating: x)`, `Int(saturating: y)`.
- **Prepositional phrase at first argument:** label begins with the preposition. `x.removeBoxes(havingLength: 12)`.
- **Arguments that join the base name grammatically:** omit the first label and fold the word into the name. `view.addSubview(y)`, not `view.add(subview: y)`.
- **When the first argument does not form a grammatical phrase with the base name:** label it.

### Omit labels only when the arguments are truly indistinguishable

```swift
min(a, b)              // order doesn't carry meaning
zip(xs, ys)            // symmetric
```

Anything else takes a label.

### Defaulted arguments are always labeled

A caller may or may not pass them, so the label anchors the meaning when they do.

### Parameters with defaults go at the end of the list

---

## 5. Types and protocols

### Types, properties, variables, constants — noun phrases

```swift
struct BibleVersion { ... }
let title: String
var createdDate: Date
```

Types and protocols use `UpperCamelCase`; everything else is `lowerCamelCase`.

### Protocols

- A protocol that describes **what something is**: a noun. `Collection`, `Sequence`, `Identifiable`, `Plan`.
- A protocol that describes a **capability**: suffix with `-able`, `-ible`, or `-ing`. `Equatable`, `Hashable`, `ProgressReporting`, `AsyncRequestSending`.

Avoid the `I`-prefix, `...Protocol` suffix, or other Obj-C / C# holdovers. Only append `Protocol` when you genuinely need to disambiguate from an associated type of the same name.

### Enum cases

Enum cases are `lowerCamelCase` noun phrases. The enum name already supplies context — don't restate it.

```swift
// No
enum Tab {
    case bibleTab, plansTab, momentsTab
}

// Yes
enum Tab {
    case bible, plans, moments
}
```

---

## 6. Parameters that never appear at the call site

Parameter *names* (as opposed to labels) do not appear at call sites, but they do appear in documentation and in the function body. Pick ones that read well there.

```swift
// No — reads badly in docs and body
func remove(_ a: Element) -> Element?

// Yes
func remove(_ member: Element) -> Element?
```

The same applies to closure parameters and tuple members — give them names where they appear in the API so documentation and call-site autocomplete are expressive.

---

## 7. Use established terminology

- Prefer the common word when it serves equally well; reserve technical terms for when they carry meaning ordinary words cannot.
- When you *do* reach for a technical term, use it in its accepted sense. Don't call something a `Monad` if it isn't one.
- Favor platform precedent. `Array`, not `List`. `Dictionary`, not `Map`. `Set`, not `HashSet`.

---

## 8. A short checklist when you name something

Run through this in order. Stop at the first problem and fix it.

1. **Any abbreviations?** Spell them out.
2. **Would a reader know the type from the name?** If not, adjust the shape (`...Date`, `is...`, `...URL`, etc.).
3. **Does the name restate the containing type or function subject?** Drop the redundancy.
4. **Is the name implementation-leaking or needlessly technical?** Try a product-focused alternative.
5. **Does it match the pattern of nearby similar things?** If not, either match them or have a strong reason not to.
6. **At the call site, does the full line read like a grammatical phrase?** Read it out loud. If it is awkward, the label is wrong.
7. **Does the function return a value?** Then its name is a noun phrase — no `get`/`load`/`fetch`/`request`/`calculate`/`compute`/`retrieve`/`build`/`find`. **Does it only cause a side effect?** Imperative verb. Confirm the shape matches.
8. **Boolean?** Starts with `is` / `has` / `can` / `should`, reads as an assertion.
9. **Can you shorten the name without losing clarity?** Do it. `NotesManager` beats `NoteObjectStateSyncMachine`.

If you are hesitating between two names, read both at the call site — not at the declaration.
