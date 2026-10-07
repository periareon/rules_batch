# Runfiles

Utility for resolving [Bazel runfiles](https://bazel.build/extending/rules#runfiles) paths at runtime in batch scripts.

See the [Runfiles](https://periareon.github.io/rules_batch/runfiles.html) page for the copy-paste preamble and usage.

## Quick start

Add the runfiles target to your `bat_binary` or `bat_test` dependencies:

```python
bat_binary(
    name = "my_tool",
    srcs = ["my_tool.bat"],
    deps = ["@rules_batch//batch/runfiles"],
)
```

Then in your script, use the [preamble](https://periareon.github.io/rules_batch/runfiles.html#preamble) to locate `runfiles.bat` and resolve data files:

```bat
call "%RLOCATION%" "my_workspace/data/config.txt" CONFIG_PATH
echo Config is at: %CONFIG_PATH%
```
