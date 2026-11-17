import YouVersionPlatformCore

/// The authentication behavior used by `BibleReaderViewModel`.
///
/// Reads, validates, and clears YouVersion authentication for `BibleReaderViewModel`.
/// Production uses `default`; tests can supply a deterministic instance so view
/// model tests do not read or mutate the process-wide token store shared by
/// other test suites.
struct BibleReaderAuthentication {
    static let `default` = BibleReaderAuthentication(
        isSignedIn: { YouVersionAPI.isSignedIn },
        hasValidToken: { await YouVersionAPI.hasValidToken() },
        signOut: { YouVersionAPI.Users.signOut() },
        hasPermission: { YouVersionAPI.hasPermission($0) }
    )

    private let readIsSignedIn: @MainActor () -> Bool
    private let validateToken: @MainActor () async -> Bool
    private let performSignOut: @MainActor () -> Void
    private let readPermission: @MainActor (String) -> Bool
    private let readAccount: @MainActor () -> BibleReaderAccount?

    /// Creates an authentication dependency for the reader.
    init(
        isSignedIn: @escaping @MainActor () -> Bool,
        hasValidToken: @escaping @MainActor () async -> Bool,
        signOut: @escaping @MainActor () -> Void,
        hasPermission: @escaping @MainActor (String) -> Bool,
        account: @escaping @MainActor () -> BibleReaderAccount? = { BibleReaderAccount.current }
    ) {
        self.readIsSignedIn = isSignedIn
        self.validateToken = hasValidToken
        self.performSignOut = signOut
        self.readPermission = hasPermission
        self.readAccount = account
    }

    /// Whether the current authentication state can perform signed-in reader actions.
    @MainActor
    var isSignedIn: Bool {
        readIsSignedIn()
    }

    /// The account whose credentials are currently used for reader requests.
    @MainActor
    var account: BibleReaderAccount? {
        readAccount()
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

    /// Whether the current user has granted a just-in-time data exchange permission.
    @MainActor
    func hasPermission(_ permission: String) -> Bool {
        readPermission(permission)
    }
}
