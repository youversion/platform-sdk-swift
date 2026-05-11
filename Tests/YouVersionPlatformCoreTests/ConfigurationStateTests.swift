import Testing

/// Parent suite that serializes all tests touching `YouVersionPlatformConfiguration`'s
/// global state. `.serialized` only prevents parallelism *within* a suite, so suites
/// that share mutable static state must be nested under a common serialized parent to
/// prevent cross-suite races.
@Suite(.serialized)
struct ConfigurationStateTests {}
