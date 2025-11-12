import SwiftUI
import YouVersionPlatform

struct ProfileView: View {
    @State private var contextProvider = ContextProvider()
    @State private var user: YouVersionUserInfo?
    @State private var userInfoUnavailable = false

    var body: some View {
        VStack(spacing: 32) {
            if let user {
                Text("You are signed in as \(user.firstName ?? "(no firstname)") \(user.lastName ?? "(no lastname)")")
                Button("Sign out") {
                    Task {
                        YouVersionAPI.Users.signOut()
                        userInfoUnavailable = false
                        await updateUser()
                    }
                }
            } else if userInfoUnavailable {
                Text("You're signed in, but your user information is unavailable. Please try again later.")
                Button("Sign out") {
                    Task {
                        YouVersionAPI.Users.signOut()
                        userInfoUnavailable = false
                        await updateUser()
                    }
                }
            } else if YouVersionPlatformConfiguration.accessToken != nil {
                ProgressView()
            } else {
                SignInWithYouVersionButton {
                    Task {
                        do {
                            let result = try await YouVersionAPI.Users.signIn(
                                permissions: [.bibles, .highlights],
                                contextProvider: contextProvider
                            )
                            dump(result)
                            // The user is logged in! Their accessToken will automatically be saved
                            // to UserDefaults on this device, so they don't have to log in again next time.
                            // You may examine the "permissions" parameter to see what the user approved;
                            // e.g. perhaps they didn't grant access for your app to see their highlights.
                            await updateUser()
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            await updateUser()
        }
        .onChange(of: YouVersionPlatformConfiguration.accessToken) {
            Task {
                await updateUser()
            }
        }
    }
    
    private func updateUser() async {
        if let accessToken = YouVersionPlatformConfiguration.accessToken {
            do {
                user = try await YouVersionAPI.Users.userInfo(accessToken: accessToken)
                print("AccessToken: \(accessToken)")
            } catch {
                print("error in updateUser: \(error)")
                // The token might have expired. But maybe they're just offline...
                userInfoUnavailable = true
            }
        } else {
            user = nil
        }
    }
}

#Preview {
    ProfileView()
}
