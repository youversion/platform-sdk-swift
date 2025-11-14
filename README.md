
![Platform Swift SDK](./assets/github-swift-sdk-banner.png)

![Platform](https://img.shields.io/badge/Platform-IOS-red)
[![License](https://img.shields.io/badge/license-Apache-blue.svg)](LICENSE)

# YouVersion Platform SDK for Swift

A Swift SDK for integrating with the YouVersion Platform, enabling developers to display Scripture content and implement user authentication in iOS, iPadOS, and other platforms where Swift can run.


## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Swift Package Manager](#swift-package-manager)
  - [CocoaPods](#cocoapods)
- [Getting Started](#getting-started)
- [Usage](#usage)
  - [Displaying Scripture in SwiftUI](#displaying-scripture-in-swiftui)
  - [Implementing Login](#implementing-login)
  - [Fetching User Data](#fetching-user-data)
  - [Displaying Verse of the Day](#displaying-verse-of-the-day)
- [Sample App](#sample-app)
- [For Different Use Cases](#-for-different-use-cases)
- [Contributing](#contributing)
- [Documentation](#documentation)
- [Support](#support)
- [License](#license)

## Features

- 📖 **Scripture Display** - Easy-to-use SwiftUI components for displaying Bible verses, chapters, and passages with `BibleTextView`
- 🔐 **User Authentication** - Seamless "Log In with YouVersion" integration using `LoginWithYouVersionButton`
- 🌅 **Verse of the Day** - Built-in `VotdView` component and API access to VOTD data
- 🚀 **Modern Swift APIs** - Built with async/await, SwiftUI, and Swift concurrency
- 📦 **Multiple Installation Options** - Available via Swift Package Manager and CocoaPods
- 💾 **Smart Caching** - Automatic local caching for improved performance

## Requirements

- iOS 15.0+ / iPadOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- A YouVersion Platform API key ([Register here](https://platform.youversion.com/))

## Installation

### Swift Package Manager

1. In Xcode, select **File → Add Package Dependencies**
2. Enter the package URL: `https://github.com/youversion/platform-sdk-swift.git`
3. Select `youversion-platform-sdk-swift` from the search results
4. Choose **Up to Next Major Version** as the dependency rule
5. Select your project next to **Add to Project**
6. Click **Add Package**
7. Add `YouVersionPlatform` to your target and click **Add Package**

Or add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/youversion/platform-sdk-swift.git", from: "1.0.0")
]
```

> **💡 Note: use a semantic version range within the current published versions in the `from` field above.**

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'YouVersionPlatform', '~> 1.0'
```

> **💡 Note: use a semantic version range within the current published versions in the field above.**

Then run:

```bash
pod install
```

## Getting Started

1. **Get Your API Key**: Register your app with [YouVersion Platform](https://platform.youversion.com/) to acquire an app key
2. **Configure the SDK**: Add the following to your app's initialization:

```swift
import YouVersionPlatform

@main
struct YourApp: App {
    init() {
        YouVersionPlatform.configure(appKey: "YOUR_APP_KEY_HERE")
    }
    var body: some Scene {...
}
```

## Usage

### Displaying Scripture in SwiftUI

Display a single verse:
```swift
import YouVersionPlatform

struct DemoView: View {
    var body: some View {
        BibleTextView(
            BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 3, verse: 16)
        )
    }
}
```

Display a verse range:
```swift
import YouVersionPlatform

struct DemoView: View {
    var body: some View {
        BibleTextView(
            BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 3, verseStart: 16, verseEnd: 20)
        )
    }
}
```

Or display a full chapter:
```swift
import YouVersionPlatform

struct DemoView: View {
    var body: some View {
        BibleTextView(
            BibleReference(versionId: 111, bookUSFM: "JHN", chapter: 3)
        )
    }
}
```

> **Note**: For longer passages, wrap `BibleTextView` in a `ScrollView`. The SDK automatically fetches Scripture from YouVersion servers and maintains a local cache for improved performance.

### Implementing Login

First, create a helper class for presentation context:

```swift
import AuthenticationServices

class ContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
```

Then add the login button to your SwiftUI view:

```swift
import YouVersionPlatform

struct LoginView: View {
    @State private var contextProvider = ContextProvider()
    @State private var accessToken: String?

    var body: some View {
        LoginWithYouVersionButton {
            Task {
                do {
                    let result = try await YouVersionAPI.Users.signIn(
                        permissions: [.bibles, .highlights],
                        optionalPermissions: [.highlights],
                        contextProvider: contextProvider
                    )
                    accessToken = result.accessToken
                    // Store the token securely (e.g., in Keychain)
                } catch {
                    print("Login failed: \(error)")
                }
            }
        }
    }
}
```

> **Note**: The SDK stores the access token securely in the Keychain, and the token persists user authentication across app launches.  Deleting or losing the access token is the equivalent of "logging out".

### Fetching User Data

Retrieve information about the authenticated user:

```swift
// Implementation TBD - this information will be included in response tokens in the future.
```

### Displaying Verse of the Day

Use the built-in VOTD component:

```swift
import YouVersionPlatform

struct ContentView: View {
    var body: some View {
        VotdView()
    }
}
```

Or fetch VOTD data for custom UI:

```swift
let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date())!
let votd = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: dayOfYear)
// Use votd.reference with BibleTextView
```

## Sample App

Explore the [Examples directory](./Examples) for a complete sample app demonstrating:
- Scripture display with various reference types
- User authentication flows
- VOTD integration
- Best practices for token storage

To run the sample app:
1. Open `platform-sdk-swift` directory in Xcode
2. Select the `SampleApp` scheme
3. Build and run on simulator or device

## 🎯 For Different Use Cases

### 📱 Swift SDK

Building an iOS or iPadOS application? This Swift SDK provides native SwiftUI components including `BibleTextView`, `VotdView`, and `LoginWithYouVersionButton` with full Swift Package Manager support and modern async/await APIs.

### 🔧 API Integration

Need direct access to YouVersion Platform APIs? See [our comprehensive API documentation](https://developers.youversion.com/overview) for advanced integration patterns and REST endpoints.

### 🤖 LLM Integration

Building AI applications with Bible content? Access YouVersion's LLM-optimized endpoints and structured data designed for language models. See [our LLM documentation](https://developers.youversion.com/for-llms) for details.

## Contributing (Starting Early 2026)

We welcome contributions! To contribute to this SDK:

1. **Fork the repository** and create a feature branch
2. **Follow our coding standards** (see [CONTRIBUTING.md](./CONTRIBUTING.md))
3. **Write tests** for new functionality
4. **Use Conventional Commits** for commit messages (enforced by `commitlint`)
5. **Submit a pull request** targeting the `main` branch

### Development Requirements

- Xcode 15.0+
- Swift 5.9+
- [Node.js 24+ (LTS)](https://nodejs.org/) - Required for release automation and commit message validation
- SwiftLint (for code style enforcement)

### Commit Message Format

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add new Bible version selector
fix: resolve crash in verse navigation
docs: update authentication examples
```

See [RELEASING.md](./RELEASING.md) for complete details on our automated release process.

## Documentation

- [API Documentation](https://developers.youversion.com/overview) - Complete API reference
- [LLM Integration Guide](https://developers.youversion.com/for-llms) - AI/ML integration docs
- [Release Process](./RELEASING.md) - Contribution and release guidelines
- [Sample Code](./Examples) - Working examples and best practices

## Support

- **Issues**: [GitHub Issues](https://github.com/youversion/platform-sdk-swift/issues)
- **Questions**: Open a [discussion](https://github.com/youversion/platform-sdk-swift/discussions)
- **Platform Support**: [YouVersion Platform](https://platform.youversion.com/)

## License

This SDK is licensed under the Apache License 2.0. See [LICENSE](./LICENSE) for details.

---

Made with ❤️ by [YouVersion](https://www.youversion.com)
