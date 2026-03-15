"""Shared implementation for bat_binary and bat_test."""

load("//batch/private:providers.bzl", "BatBinaryInfo", "BatInfo")

_SHARED_PROVIDER = BatBinaryInfo()

def bat_executable_impl(ctx):
    """The implementation for batch executable rules.

    Args:
        ctx (ctx): The rule's context object

    Returns:
        list: The list of providers
    """
    if len(ctx.files.srcs) != 1:
        fail("you must specify exactly one file in 'srcs'", attr = "srcs")
    src = ctx.files.srcs[0]

    entrypoint = ctx.actions.declare_file("{}.{}".format(ctx.label.name, src.extension))
    ctx.actions.symlink(output = entrypoint, target_file = src)

    files = depset([src, entrypoint])
    runfiles = ctx.runfiles(files = ctx.files.data, transitive_files = files)

    for target in ctx.attr.data:
        runfiles = runfiles.merge(target[DefaultInfo].default_runfiles)
    for target in ctx.attr.deps:
        runfiles = runfiles.merge(target[DefaultInfo].default_runfiles)

    return [
        DefaultInfo(
            executable = entrypoint,
            files = files,
            runfiles = runfiles,
        ),
        _SHARED_PROVIDER,
    ]

BAT_EXECUTABLE_ATTRS = {
    "data": attr.label_list(
        allow_files = True,
        doc = "Data dependencies merged into the executable runfiles.",
    ),
    "deps": attr.label_list(
        providers = [BatInfo],
        doc = "Dependencies (e.g. `bat_library`) merged into the executable runfiles.",
    ),
    "srcs": attr.label_list(
        allow_files = [".bat", ".cmd"],
        doc = "The batch script source file. Must be a singleton list.",
    ),
}

BAT_EXECUTABLE_PROVIDES = [BatBinaryInfo]
