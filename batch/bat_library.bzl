"""bat_library rule implementation."""

load("//batch/private:providers.bzl", "BatInfo")

_SHARED_PROVIDER = BatInfo()

def _bat_library_impl(ctx):
    transitive = [dep[DefaultInfo].files for dep in ctx.attr.deps]
    files = depset(ctx.files.srcs, transitive = transitive)

    runfiles = ctx.runfiles(files = ctx.files.srcs)
    for target in ctx.attr.data:
        runfiles = runfiles.merge(target[DefaultInfo].default_runfiles)
    for target in ctx.attr.deps:
        runfiles = runfiles.merge(target[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            files = files,
            runfiles = runfiles,
        ),
        _SHARED_PROVIDER,
    ]

bat_library = rule(
    doc = """\
Groups batch scripts and optional data for use as dependencies of `bat_binary`
or other `bat_library` targets. Batch has no link step; this rule only bundles
files and propagates runfiles, similar in spirit to `sh_library`.
""",
    implementation = _bat_library_impl,
    attrs = {
        "data": attr.label_list(
            allow_files = True,
            doc = "Additional runfiles (any files or targets with runfiles).",
        ),
        "deps": attr.label_list(
            providers = [BatInfo],
            doc = "Other batch libraries whose scripts and runfiles are merged in.",
        ),
        "srcs": attr.label_list(
            allow_files = [".bat", ".cmd"],
            doc = "Batch script sources in this library.",
        ),
    },
    provides = [BatInfo],
)
