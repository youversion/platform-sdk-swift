# Agent instructions for `platform-sdk-swift`

## Required local checks

- Always run SwiftLint for code changes before finalizing work.
- In this Linux container, run SwiftLint with SourceKit configured:

```bash
LINUX_SOURCEKIT_LIB_PATH=/root/.local/share/swiftly/toolchains/6.1.3/usr/lib swiftlint --strict
```

## If `swiftlint` is not installed

Install the Linux binary from Realm SwiftLint releases, then rerun the command above.

```bash
tmpdir="$(mktemp -d)"
curl -fL https://github.com/realm/SwiftLint/releases/latest/download/swiftlint_linux_amd64.zip -o "$tmpdir/swiftlint_linux_amd64.zip"
unzip -q "$tmpdir/swiftlint_linux_amd64.zip" -d "$tmpdir"
install -m 0755 "$tmpdir/swiftlint" /usr/local/bin/swiftlint
rm -rf "$tmpdir"
```

## If SourceKit fails to load

If you see an error like:

`Loading libsourcekitdInProc.so failed`

make sure `LINUX_SOURCEKIT_LIB_PATH` points to the active Swift toolchain `usr/lib` directory. For this container, that is:

`/root/.local/share/swiftly/toolchains/6.1.3/usr/lib`
