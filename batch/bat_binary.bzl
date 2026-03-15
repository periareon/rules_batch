"""bat_binary rule."""

load("//batch/private:bat_executable.bzl", "BAT_EXECUTABLE_ATTRS", "BAT_EXECUTABLE_PROVIDES", "bat_executable_impl")

bat_binary = rule(
    doc = """\
Declares an executable batch script.

The user script is symlinked as the executable entry point. Dependencies
declared via `deps` and `data` are merged into the runfiles tree.

To resolve runfiles at runtime, add a dependency on
`@rules_batch//batch/runfiles` and use the runfiles preamble in your script.
""",
    implementation = bat_executable_impl,
    attrs = BAT_EXECUTABLE_ATTRS,
    executable = True,
    provides = BAT_EXECUTABLE_PROVIDES,
)
