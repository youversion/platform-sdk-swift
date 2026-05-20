import SwiftUI
import YouVersionPlatform

struct ProfileView: View {
    @State private var contextProvider = ContextProvider()
    @State private var isSignedIn = false
    @State private var dataExchangeStatusText: String?
    @State private var hasHighlightsPermission = false
    
    var body: some View {
        VStack {
            if isSignedIn {
                Text("You are signed in as: ")
                    .padding()
                Text(YouVersionAPI.Users.currentUserName ?? "(no name)")
                Text(YouVersionAPI.Users.currentUserEmail ?? "(no email)")
                    .padding(.bottom)
                if hasHighlightsPermission {
                    Text("Highlights permission: granted")
                } else {
                    Button("Request highlights permission") {
                        requestHighlightsPermission()
                    }
                }
                if let dataExchangeStatusText {
                    Text(dataExchangeStatusText)
                        .font(.footnote)
                        .padding(.vertical)
                }
                Button("Sign out") {
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
            hasHighlightsPermission = YouVersionAPI.hasPermission(.highlights)
        }
    }
    
    func doSignIn() {
        Task {
            do {
                _ = try await YouVersionAPI.Users.signIn(
                    permissions: [.profile, .email],
                    contextProvider: contextProvider
                )
                // The user is signed in! Their accessToken will automatically be saved
                // to UserDefaults on this device, so they don't have to log in again next time.
                // Now you may use accessors like YouVersionAPI.Users.currentUserName.
                
                // To prove out the UX: immediately request the highlights permission
                requestHighlightsPermission()
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
                let session = DataExchangeSession(contextProvider: contextProvider)
                let result = try await session.requestDataExchange(permissions: [.highlights])
                if !result.isGranted {
                    dataExchangeStatusText = "Highlights permission status: \(result.status)"
                }
                hasHighlightsPermission = YouVersionAPI.hasPermission(.highlights)
            } catch {
                dataExchangeStatusText = "Highlights permission failed: \(error.localizedDescription)"
            }
        }
    }

}

#Preview {
    ProfileView()
}
