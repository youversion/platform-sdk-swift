import SwiftUI
import YouVersionPlatform

struct ProfileView: View {
    @State private var contextProvider = ContextProvider()
    @State private var isSignedIn = false

    var body: some View {
        VStack {
            if isSignedIn {
                Text("You are signed in as: ")
                    .padding()
                Text(YouVersionAPI.Users.currentUserName ?? "(no name)")
                Text(YouVersionAPI.Users.currentUserEmail ?? "(no email)")
                Button("Sign out") {
                    YouVersionAPI.Users.signOut()
                    isSignedIn = false
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
            } catch {
                print("Sign In failed: \(error.localizedDescription)")
            }
            isSignedIn = YouVersionAPI.isSignedIn
        }
    }
}

#Preview {
    ProfileView()
}
