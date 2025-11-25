import SwiftUI
import YouVersionPlatform

struct ProfileView: View {
    @State private var contextProvider = ContextProvider()
    //@State private var user: YouVersionUserInfo?
    //@State private var userInfoUnavailable = false
    @State private var authData: SignInWithYouVersionResult?

    var body: some View {
        VStack {
            if let authData, let tokenExpiryDate = authData.expiryDate {
                Text("You are signed in.")
                // TODO: show user's name, permissions, etc.: have an accessor read from idToken
                Text("Your token expires at: \(displayString(from: tokenExpiryDate))")
                Button("Refresh") {
                    doManualRefresh()
                }
                Button("Sign out") {
                    YouVersionAPI.Users.signOut()
                }
            } else {
                SignInWithYouVersionButton {
                    doSignIn()
                }
            }
        }
        .onReceive(
            Timer.publish(every: 5, on: .main, in: .common).autoconnect()
        ) { _ in
            /*
               A normal app would not have a timer like this! Usually you will:
                - examine YouVersionAPI.isSignedIn (not an async call)
                - await YouVersionAPI.hasValidToken() prior to making API calls
                - call YouVersionAPI.Users.signIn()
                - call YouVersionAPI.Users.signOut()
             */
            authData = YouVersionPlatformConfiguration.authData
        }
    }

    func doManualRefresh() {
        Task {
            let result = await YouVersionAPI.hasValidToken()
            print("Refresh: done, returned \(result)")
        }
    }

    func doSignIn() {
        Task {
            do {
                let result = try await YouVersionAPI.Users.signIn(
                    permissions: [.bibles, .highlights],
                    contextProvider: contextProvider
                )
                dump(result)
                // The user is logged in! Their accessToken will automatically be saved
                // to UserDefaults on this device, so they don't have to log in again next time.
            } catch {
                print(error)
            }
        }
    }

    private func displayString(from date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        )
    }

}

#Preview {
    ProfileView()
}
