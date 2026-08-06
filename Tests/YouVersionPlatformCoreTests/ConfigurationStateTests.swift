import Testing

/// Parent suite for all tests that mutate `YouVersionPlatformConfiguration` global state.
/// Each nested suite must also carry `.serialized` — the parent trait does not propagate
/// through nested `@Suite` declarations, so without it the child suite's own tests can
/// still interleave with each other and with sibling suites.
@Suite(.serialized)
struct ConfigurationStateTests {}
