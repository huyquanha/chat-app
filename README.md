# A Chat app written in Golang

## Go

### Manage Go dependencies with Bazel

**Reference**: https://github.com/bazel-contrib/rules_go/blob/master/docs/go/core/bzlmod.md

`bin/go` is a wrapper around `bazel run @rules_go//go`, so you can just invoke `go get`, `go mod tidy` and it'll do the right thing.

### Static Analysis with `nogo`

**Reference**: https://github.com/bazel-contrib/rules_go/blob/master/go/nogo.rst

Once configured, `nogo` will be invoked automatically when building any Go target. If any analyzers reject the program, the build will fail.

- Set `--keep_going` to see all `nogo` findings, not just those from the first failing target.
- Set `--norun_validations` to disable all validations, including `nogo`

To prevent `nogo` from running for a particular target, add `no-nogo` to `tags`.

Some analyzers generate fixes. To apply those fixes all at once, use the following commands

```shell
# Only run nogo, no compilation actions, and don't fail on findings.
bazel build //... --norun_validations --output_groups nogo_fix --remote_download_regex='.*/nogo.patch$'
# Apply all fixes.
bazel cquery //... --norun_validations --output_groups nogo_fix --remote_download_regex='.*/nogo.patch$' --output=files \
  | xargs -I{} sh -c '[[ ! -e {}/nogo.patch ]] || patch -p1 -N --reject-file /dev/null < {}/nogo.patch'
```

### Buildifier

`bin/buildifier` is a dotslash file that will install platform-specific prebuilt binary (if not exist) for `buildifier` and run it. The version of the prebuilt binary will be kept in-sync with the `buildifier_prebuilt` bazel module version.

Using dotslash to fetch the binary and then invoking it directly is more preferable than going via Bazel here e.g. with `bazel run @buildifier_prebuilt//:buildifier` because Bazel adds some overhead on top of the binary execution (analysis, cache checking etc.), which significantly slows down VSCode's Format on Save.

Some useful commands:

- To reformat recursively all BUILD/MODULE files: `buildifier -r .`
- To check without modifying: `buildifier -r -mode check .`
- To lint (detect unused imports): `buildifier -r -lint warn .`

### Debugging

1. Open the file to debug (this could be a source file, or a test file).
2. Set a breakpoint
3. OP