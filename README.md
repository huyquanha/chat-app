# A Chat app written in Golang

## Go

### Manage Go dependencies with Bazel

**Reference**: https://github.com/bazel-contrib/rules_go/blob/master/docs/go/core/bzlmod.md

- To install a new dependency: `bazel run @rules_go//go get ...`
- To tidy up dependencies in `go.mod`: `bazel run @rules_go//go mod tidy`.
- To update the `use_repo` call accordingly in `MODULE.bazel`: `bazel mod tidy`.

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

Use the convenience alias in the root `BUILD.bazel` to run buildifier: `bazel run //:fmt ...`

Useful commands:

- To reformat recursively all BUILD/MODULE files: `bazel run //:fmt -- -r .`
- To check without modifying: `bazel run //:fmt -- -r -mode check .`
- To lint (detect unused imports): `bazel run //:fmt -- -r -lint warn .`
