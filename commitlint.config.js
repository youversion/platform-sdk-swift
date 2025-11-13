module.exports = {
  extends: ["@commitlint/config-conventional"],
  rules: {
    "body-max-line-length": [2, "always", 200],
    "type-enum": [
      2,
      "always",
      [
        "feat", // New feature
        "fix", // Bug fix
        "docs", // Documentation only
        "style", // Code style changes (formatting, etc.)
        "refactor", // Code refactoring
        "perf", // Performance improvements
        "test", // Adding/updating tests
        "build", // Build system changes
        "ci", // CI/CD changes
        "chore", // Maintenance tasks
        "revert", // Revert previous commit
      ],
    ],
  },
};
