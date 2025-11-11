
![Platform Swift SDK](./assets/github-swift-sdk-banner.png)

![Platform](https://img.shields.io/badge/Platform-IOS-red)
[![License](https://img.shields.io/badge/license-Apache-blue.svg)](LICENSE)

# YouVersion Platform SDK for Swift

A Swift SDK for integrating with the YouVersion Platform, enabling developers to display Scripture content and implement user authentication in iOS, iPadOS, and other platforms where Swift can run.


## Table of Contents

- [YouVersion Platform Swift SDK](#youversion-platform-swift-sdk)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [🎯 For Different Use Cases](#-for-different-use-cases)
    - [📱 Swift SDK](#-swift-sdk)
    - [🔧 API Integration](#-api-integration)
    - [🤖 LLM Integration](#-llm-integration)
  - [Getting Started](#getting-started)
  - [Sample App](#sample-app)
  - [Displaying Scripture in SwiftUI](#displaying-scripture-in-swiftui)
    - [In case you're interested:](#in-case-youre-interested)
  - [Implementing Login](#implementing-login)
  - [Fetching data for the logged-in user](#fetching-data-for-the-logged-in-user)
  - [Displaying the Verse of the Day](#displaying-the-verse-of-the-day)

## Features

- 📖 **Scripture Display** - Easy-to-use SwiftUI components for displaying Bible verses, chapters, and passages with `BibleTextView`
- 🔐 **User Authentication** - Seamless "Log In with YouVersion" integration using `LoginWithYouVersionButton`
- 🌅 **Verse of the Day** - Built-in `VotdView` component and API access to VOTD data

## 🎯 For Different Use Cases

### 📱 Swift SDK

Building an iOS or iPadOS application? This Swift SDK provides native SwiftUI components including `BibleTextView`, `VotdView`, and `LoginWithYouVersionButton` with full Swift Package Manager support and modern async/await APIs.

### 🔧 API Integration

Need direct access to YouVersion Platform APIs? See YouVersion's comprehensive Platform API documentation and advanced integration patterns, [see our full API documentation here](https://developers.youversion.com/overview).

### 🤖 LLM Integration

Building AI applications with Bible content? Access YouVersion's LLM-optimized endpoints and structured data designed for language models and AI applications, [see our LLM documentation here](https://developers.youversion.com/for-llms).

## Getting Started

1. Register your app with [YouVersion Platform](https://platform.youversion.com/), and acquire an app key.
2. In your Xcode project, in the File menu, choose "Add Package Dependencies".
3. Type `https://github.com/youversion/platform-sdk-swift.git` into the search field.
4. Select `youversion-platform-sdk-swift` from the search results.
5. For the "Dependency Rule", select `Up to Next Major Version`. (Or, if you're in YOLO mode, `Branch` and then `main`.)
6. Ensure your project is selected next to `Add to Project`.
7. Click `Add Package`.
8. On the Package Products dialog, add `YouVersionPlatform` to your target and click `Add Package`.

## Sample App

For a quick start, open the sample app located in the Examples directory. It has examples of several different ways to use the SDK.

Opening the SDK directory in Xcode allows you to run the unit tests easily.

## Displaying Scripture in SwiftUI

Create an init() function for your app if you don't already have one, and specify your app key there, like this:
```swift
import YouVersionPlatform

@main
struct yourApp: App {
    init() {
        YouVersionPlatform.configure(appKey: "YOUR_APP_KEY_HERE")
    }
    var body: some Scene {...
```

And now to display a single verse, this is all it takes:
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

Note: If you're displaying a longer passage of Scripture than a single verse, 
you should wrap `BibleTextView` inside a normal SwiftUI `ScrollView`.

### In case you're interested:

When `BibleTextView` is rendered, it will fetch the necessary Bible text 
from the YouVersion server as needed and display it as soon as it can.
It will also maintain a limited-size local cache of the Bible data for speed.

## Implementing Login

To the view where you want to add a "Log In with YouVersion" button, add this:
```swift
import YouVersionPlatform
```

Add a helper class, which tells iOS where to display the system's login sheet.
(See [here](https://developer.apple.com/documentation/authenticationservices/authenticating-a-user-through-a-web-service) for more details.)
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

Finally, inside your SwiftUI view, add the button and start the login process when it is tapped:
```swift
    LoginWithYouVersionButton {
        Task {
            do {
                let result = try await YouVersionAPI.Users.logIn(
                    requiredPermissions: [.bibles],
                    optionalPermissions: [.highlights],
                    contextProvider: contextProvider
                )
                accessToken = result.accessToken
                dump(result)
                // The user is logged in and you have an access token!
                // Now you can use the token in YouVersion Platform API calls.
                // You should save the token locally so the user doesn't have to log in again next time.
                // You may examine the "permissions" parameter to see what the user approved;
                // e.g. perhaps they didn't grant access for your app to see their highlights.
            } catch {
                print(error)
            }
        }
    }
```

You'll need to store the user's access token to make some API calls, preferably in the keychain. 
Deleting or losing the access token is the same as "logging out". 

## Fetching data for the logged-in user

Once you have an access token (see above), you can use it like this:
```swift
private func loadUI(accessToken: String) {
    Task {
        do {
            let info = try await YouVersionAPI.Users.userInfo(accessToken: accessToken)
            self.userWelcome = "Welcome, \(info.firstName)!"
        } catch {
            // handle the error
        }
    }
}
```

## Displaying the Verse of the Day

If you just want to display a simple VOTD view, you can use the one built into the SDK:
```swift
var body: some View {
    VotdView()
}
```

If you want to use the data of the VOTD in your own UI, you can request it like this:
```swift
let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date())!
let votd = try await YouVersionAPI.VOTD.verseOfTheDay(dayOfYear: dayOfYear)
```

That will give you the Bible reference; use BibleTextView to display it.
See the "SampleApp" example code in the SDK for more information!
