"""Declaring Go binary artifacts for oci image build and load"""

load("@rules_oci//oci:defs.bzl", "oci_image", "oci_image_index", "oci_load")
load("@rules_pkg//:pkg.bzl", "pkg_tar")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

_SUPPORTED_PLATFORMS = [
    Label("//tools/bazel_rules/oci:linux_amd64"),
    Label("//tools/bazel_rules/oci:linux_arm64"),
]

def go_image_artifact(name, binary, entrypoint = None, base = "@distroless_static", platforms = _SUPPORTED_PLATFORMS, **kwargs):
    """Declares a published go container image artifact.

    Args:
        name: String name of the artifact
        binary: Go binary label
        entrypoint: Entrypoint for the container
        base: Base image to use (defaults to @distroless_static)
        platforms: List of platforms to support (defaults to _SUPPORTED_PLATFORMS)
        **kwargs: Other keyword arguments to parse down
    """

    visibility = kwargs.pop("visibility", None)

    if entrypoint == None:
        binary_label = native.package_relative_label(binary)
        entrypoint = ["/" + binary_label.name]

    pkg_tar(
        name = "%s.binary_layer" % name,
        srcs = [binary],
        include_runfiles = True,
        visibility = visibility,
    )

    oci_image(
        name = "%s.standalone" % name,
        base = base,
        entrypoint = entrypoint,
        tars = [":%s.binary_layer" % name],
        visibility = ["//visibility:private"],
        **kwargs
    )

    oci_image_index(
        name = name,
        images = [":%s.standalone" % name],
        platforms = platforms,
        visibility = visibility,
    )

    repo_tag = "bazel/{package}:{name}".format(
        package = native.package_name(),
        name = name,
    )

    # This target loads the entire image index to the
    # Podmand daemon (with platform transitions alrady
    # applied). format=oci must be specified to load
    # an image index, and it's only supported by Podman
    # and not Docker (unless containerd store is enabled).
    # For our setup, this works fine as Podman is now the
    # default on all Macbooks. On Linux, the standalone load
    # target (defined below) should be used instead, because
    # we don't have Podman installed on Linux.
    oci_load(
        name = "%s.load" % name,
        image = ":%s" % name,
        format = "oci",
        repo_tags = [repo_tag],
        visibility = ["//visibility:private"],
    )

    # This target only works on linux environments
    # on MacOS, running this target will lead to
    # exec format error when running the container,
    # as it uses the standalone image (without platform
    # transition), so the Go binary is still built for
    # the host platform (darwin) and will be incompatible
    # with the container platform (linux).
    # It's included here for local testing in Linux environments,
    # as we don't have Podman installed there in order
    # to load the entire image index.
    oci_load(
        name = "%s_standalone.load" % name,
        image = ":%s.standalone" % name,
        repo_tags = [repo_tag],
        visibility = ["//visibility:private"],
    )

    native.config_setting(
        name = "%s.config_linux" % name,
        constraint_values = ["@platforms//os:linux"],
        visibility = ["//visibility:private"],
    )

    native.alias(
        name = "%s.platform_load" % name,
        actual = select({
            ":%s.config_linux" % name: ":%s_standalone.load" % name,
            "//conditions:default": ":%s.load" % name,
        }),
        visibility = ["//visibility:private"],
    )

    sh_binary(
        name = "%s.kind_load" % name,
        srcs = ["//tools/bazel_rules/oci:kind_load.sh"],
        env = {
            "IMAGE_TAG": repo_tag,
            "CLUSTER_NAME": "chat-app",
            "LOADER": "$(rootpath :%s.platform_load)" % name,
        },
        data = [":%s.platform_load" % name],
        deps = ["@rules_shell//shell/runfiles"],
        visibility = visibility,
    )
