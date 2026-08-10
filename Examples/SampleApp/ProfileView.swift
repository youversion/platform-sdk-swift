import SwiftUI
import YouVersionPlatform

struct ProfileView: View {
#if !os(tvOS)
    @State private var contextProvider = ContextProvider()
#endif
    @State private var isSignedIn = false
    @State private var dataExchangeStatusText: String?
    @State private var hasHighlightsPermission = false
    
    var body: some View {
        VStack {
            if isSignedIn {
                Text("profile.signed_in_as")
                    .padding()
                Text(YouVersionAPI.Users.currentUserName ?? String(localized: "profile.no_name"))
                Text(YouVersionAPI.Users.currentUserEmail ?? String(localized: "profile.no_email"))
                    .padding(.bottom)
                if hasHighlightsPermission {
                    Text("profile.highlights_permission_granted")
                } else {
                    Button("profile.request_highlights_permission") {
                        requestHighlightsPermission()
                    }
                }
                if let dataExchangeStatusText {
                    Text(dataExchangeStatusText)
                        .font(.footnote)
                        .padding(.vertical)
                }
                Button("profile.sign_out") {
                    doSignOut()
                }
                .padding(.top)
            } else {
                SignInWithYouVersionButton {
                    doSignIn()
                }
            }
        }
        .onAppear {
            isSignedIn = YouVersionAPI.isSignedIn
            hasHighlightsPermission = YouVersionAPI.hasPermission("highlights")
        }
    }
    
    func doSignIn() {
        Task {
            do {
#if os(tvOS)
                _ = try await YouVersionAPI.Users.signIn(permissions: ["profile", "email"])
#else
                _ = try await YouVersionAPI.Users.signIn(
                    permissions: ["profile", "email"],
                    contextProvider: contextProvider
                )
#endif
                // The user is signed in! Their accessToken will automatically be saved
                // to UserDefaults on this device, so they don't have to log in again next time.
                // Now you may use accessors like YouVersionAPI.Users.currentUserName.
            } catch {
                print("Sign In failed: \(error.localizedDescription)")
            }
            isSignedIn = YouVersionAPI.isSignedIn
        }
    }
    
    func doSignOut() {
        YouVersionAPI.Users.signOut()
        isSignedIn = false
        dataExchangeStatusText = nil
        hasHighlightsPermission = false
    }
    
    func requestHighlightsPermission() {
        dataExchangeStatusText = nil
        Task {
            do {
#if os(tvOS)
                let session = DataExchangeSession()
#else
                let session = DataExchangeSession(contextProvider: contextProvider)
#endif
                _ = try await session.requestDataExchange(permissions: ["highlights"])
                hasHighlightsPermission = YouVersionAPI.hasPermission("highlights")
            } catch {
                dataExchangeStatusText = String(
                    format: String(localized: "profile.highlights_permission_failed"),
                    error.localizedDescription
                )
            }
        }
    }

}

#Preview {
    ProfileView()
}
