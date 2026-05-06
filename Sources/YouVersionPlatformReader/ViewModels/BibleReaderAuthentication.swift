import YouVersionPlatformCore

/// The authentication behavior used by `BibleReaderViewModel`.
///
/// The reader keeps customer-facing state on `BibleReaderViewModel.isSignedIn`,
/// but the work of reading, validating, and clearing YouVersion authentication
/// lives here. Production uses `default`; tests can supply a deterministic
/// instance so view model tests do not read or mutate the process-wide token
/// store shared by other test suites.
struct BibleReaderAuthentication {
    static let `default` = BibleReaderAuthentication(
        isSignedIn: { YouVersionAPI.isSignedIn },
        hasValidToken: { await YouVersionAPI.hasValidToken() },
        signOut: { YouVersionAPI.Users.signOut() }
    )

    private let readIsSignedIn: @MainActor () -> Bool
    private let validateToken: @MainActor () async -> Bool
    private let performSignOut: @MainActor () -> Void

    /// Creates an authentication dependency for the reader.
    init(
        isSignedIn: @escaping @MainActor () -> Bool,
        hasValidToken: @escaping @MainActor () async -> Bool,
        signOut: @escaping @MainActor () -> Void
    ) {
        self.readIsSignedIn = isSignedIn
        self.validateToken = hasValidToken
        self.performSignOut = signOut
    }

    /// Whether the current authentication state can perform signed-in reader actions.
    @MainActor
    var isSignedIn: Bool {
        readIsSignedIn()
    }

    /// Validates the current authentication state, refreshing tokens when needed.
    @MainActor
    func hasValidToken() async -> Bool {
        await validateToken()
    }

    /// Clears the current authentication state.
    @MainActor
    func signOut() {
        performSignOut()
    }
}
