![Platform Swift SDK](./assets/github-swift-sdk-banner.png)

![Platform](https://img.shields.io/badge/Platform-IOS-red)
[![License](https://img.shields.io/badge/license-Apache-blue.svg)](LICENSE)
[![Coverage](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/youversion/platform-sdk-swift/main/.github/badges/coverage.json)](./CONTRIBUTING.md#code-coverage)

# YouVersion Platform SDK for Swift

A Swift SDK for integrating with the YouVersion Platform, to display Bible content and implement user authentication in iOS, iPadOS, and other platforms where Swift can run.


## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Swift Package Manager](#swift-package-manager)
  - [CocoaPods](#cocoapods)
- [Getting Started](#getting-started)
- [Usage](#usage)
  - [Displaying Scripture in SwiftUI](#displaying-scripture-in-swiftui)
  - [Bible Reader](#bible-reader)
  - [Implementing Sign In](#implementing-sign-in)
  - [Fetching User Data](#fetching-user-data)
  - [Displaying Verse of the Day](#displaying-verse-of-the-day)
- [Sample App](#sample-app)
- [For Different Use Cases](#-for-different-use-cases)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Support](#support)
- [License](#license)

## Features

- 📖 **Scripture Display** - Easy-to-use SwiftUI components for displaying Bible verses with `BibleTextView` and `BibleCardView`
- 📖 **Bible Reader** - A complete Bible reading experience inside your app with `BibleReaderView`
- 🔐 **User Authentication** - Seamless "Sign In with YouVersion" integration using `SignInWithYouVersionButton`
- 🌅 **Verse of the Day** - Built-in `VotdView` component and API access to VOTD data

## Requirements

- iOS 17+ / iPadOS 17+
- A YouVersion Platform API key ([Register here](https://platform.youversion.com/))

## Installation

### Swift Package Manager

1. In Xcode, open your app project, then select the menu **File → Add Package Dependencies**
2. Enter the package URL: `https://github.com/youversion/platform-sdk-swift.git`
3. Select `platform-sdk-swift` from the search results.
4. Click **Add Package**
5. Click **Add Package** on the next dialog.

Or add it to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/youversion/platform-sdk-swift.git", from: "0.1.0")
]
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'YouVersionPlatform', '~> 1.0'
```

Then run `pod install`

## Getting Started

1. **Get Your App Key**: Register your app with [YouVersion Platform](https://platform.youversion.com/) to acquire an app key
2. **Configure the SDK**: Add the following to your app's initialization:

```swift
import SwiftUI
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
            BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verse: 16)
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
            BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3, verseStart: 16, verseEnd: 20)
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
            BibleReference(versionId: 3034, bookUSFM: "JHN", chapter: 3)
        )
    }
}
```

> **Note**: For longer passages, wrap `BibleTextView` in a `ScrollView`. 

The SDK automatically fetches Scripture from YouVersion servers and maintains a local cache for improved performance.

### Bible Reader

Displays a full Bible reading experience, very similar to the YouVersion Bible app, ready to be added as a tab in your app.

```swift
    BibleReaderView(
        appName: "Sample App",
        signInMessage: "Sign in to see your YouVersion highlights in this Sample App."
    )
```


### Implementing Sign In

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

In the header of your SwiftUI view, store a strong reference to the `ContextProvider`:
```swift
@State private var contextProvider = ContextProvider() // Store a strong reference
```

Add the "Sign In" button to your SwiftUI view:

```swift
    SignInWithYouVersionButton {
        Task {
            do {
                let result = try await YouVersionAPI.Users.signIn(
                    permissions: [.profile, .email],
                    contextProvider: contextProvider
                )
                // The user is logged in and you have an access token at result.accessToken!
                // You may now call the YouVersion Platform APIs which require authentication.
            } catch {
                print(error)
            }
        }
    }
}
```

> **Note**: The SDK stores the access token locally, and persists it across app launches. 
Deleting or losing the access token is the equivalent of "logging out".

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

Building an iOS or iPadOS application? This Swift SDK provides native SwiftUI components including `BibleTextView`, `VotdView`, and `SignInWithYouVersionButton` with full Swift Package Manager support and modern async/await APIs.

### 🔧 API Integration

Need direct access to YouVersion Platform APIs? See [our comprehensive API documentation](https://developers.youversion.com/overview) for advanced integration patterns and REST endpoints.

### 🤖 LLM Integration

Building AI applications with Bible content? Access YouVersion's LLM-optimized endpoints and structured data designed for language models. See [our LLM documentation](https://developers.youversion.com/for-llms) for details.

## Documentation

- [API Documentation](https://developers.youversion.com/overview) - Complete API reference
- [LLM Integration Guide](https://developers.youversion.com/for-llms) - AI/ML integration docs
- [Sample Code](./Examples) - Working examples and best practices

## Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details on development setup, code style, and the pull request process.

## Support

- **Issues**: [GitHub Issues](https://github.com/youversion/platform-sdk-swift/issues)
- **Questions**: Open a [discussion](https://github.com/youversion/platform-sdk-swift/discussions)
- **Platform Support**: [YouVersion Platform](https://platform.youversion.com/)

## License

This SDK is licensed under the Apache License 2.0. See [LICENSE](./LICENSE) for details.

---

Made with ❤️ by [YouVersion](https://www.youversion.com)
