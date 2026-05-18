// On `main` this constant always reads "Dev".
// The release workflow rewrites the literal in the *tagged* release commit
// only — that commit is not pushed to `main` — so production builds resolved
// via SPM or CocoaPods at a release tag report the real version, while
// in-repo and PR-CI builds report "Dev". If you change the shape of the
// declaration below, also update scripts/stamp-sdk-version.sh.
enum SDKVersion {
    static let current = "6.0.0"
}
