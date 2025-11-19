import SwiftUI
import YouVersionPlatform

struct ProfileView: View {
    @State private var contextProvider = ContextProvider()
    //@State private var user: YouVersionUserInfo?
    //@State private var userInfoUnavailable = false
    @State private var signInData: SignInWithYouVersionResult?

    var body: some View {
        VStack(spacing: 32) {
            if //let accessToken = YouVersionPlatformConfiguration.accessToken,
               let tokenExpiryDate = YouVersionPlatformConfiguration.tokenExpiryDate,
               let refreshToken = YouVersionPlatformConfiguration.refreshToken {
                Text("You are signed in.")
                Text("Your token expires at: \(displayString(from: tokenExpiryDate))")
                Button("Refresh") {
                    Task {
                        if let result = try? await YouVersionAPI.Users.performRefresh(with: refreshToken) {
                            YouVersionPlatformConfiguration.saveAuthData(
                                accessToken: result.accessToken,
                                refreshToken: result.refreshToken,
                                expiryDate: result.expiryDate
                            )
                            dump(result)
                        }
                    }
                }
                .padding(.bottom)
                Button("Sign out") {
                    Task {
                        YouVersionAPI.Users.signOut()
                    }
                }
                .padding(.bottom)
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
                        } catch {
                            print(error)
                        }
                    }
                }
            }
        }
        .padding()
        .task {
            //await updateUser()
        }
        .onChange(of: YouVersionPlatformConfiguration.accessToken) {
            Task {
                //await updateUser()
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

//    private func updateUser() async {
//        if let accessToken = YouVersionPlatformConfiguration.accessToken {
//            do {
//                user = try await YouVersionAPI.Users.userInfo(accessToken: accessToken)
//                print("AccessToken: \(accessToken)")
//            } catch {
//                print("error in updateUser: \(error)")
//                // The token might have expired. But maybe they're just offline...
//                userInfoUnavailable = true
//            }
//        } else {
//            user = nil
//        }
//    }
}

#Preview {
    ProfileView()
}
