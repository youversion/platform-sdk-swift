module.exports = {
  extends: ["@commitlint/config-conventional"],
  // Release commits (`chore(release): X.Y.Z [skip ci]`) carry the generated
  // release-notes body, which routinely contains lines > 100 chars (URLs,
  // embedded prior-commit bodies) and `* ` bullet lines the parser treats
  // as footer entries. They're already on `main` by the time any PR sees
  // them, so they don't need re-validation. Skip them outright as a
  // belt-and-suspenders alongside the workflow's `origin/<base>..head`
  // range, which already excludes them in the normal case.
  ignores: [(message) => /^chore\(release\): \d+\.\d+\.\d+/.test(message)],
  rules: {
    "body-max-line-length": [2, "always", 300],
    "type-enum": [
      2,
      "always",
      [
        "feat", // New feature - triggers minor version increment
        "fix", // Bug fix - triggers patch version increment
        "docs", // Documentation only - no version increment
        "style", // Code style changes (formatting, etc.) - no version increment
        "refactor", // Code refactoring - no version increment
        "perf", // Performance improvements - no version increment
        "test", // Adding/updating tests - no version increment
        "build", // Build system changes - no version increment
        "ci", // CI/CD changes - no version increment
        "chore", // Maintenance tasks - no version increment
        "revert", // Revert previous commit - no version increment
      ],
    ],
  },
};
