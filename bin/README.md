# `//bin` — repo-managed tools on `$PATH`

This directory is added to `$PATH` by [direnv](https://direnv.net/) via the repo-root `.envrc`. It contains shortcuts to tools like `go` and `buildifier` from Bazel, which can be invoked by developers without typing out `bazel run` with the full Bazel target. It also ensures the same version of these tools are used by everyone, which are the same version sourced from Bazel and used by CI, for consistency.

Some of the binaries in this directory are [Dotslash files](https://dotslash-cli.com/docs/), so `dotslash` must be installed globally. `dotslash -- create-url-entry` is a handy command to output the JSON object for the relevant platform of the tool from a Github platform-specific release download URL.