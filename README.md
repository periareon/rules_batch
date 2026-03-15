# rules_batch

Bazel rules for [Microsoft Batch](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands).

## Setup

In `MODULE.bazel`:

```python
bazel_dep(name = "rules_batch", version = "...")
```

## Example

```python
load("@rules_batch//batch:bat_binary.bzl", "bat_binary")
load("@rules_batch//batch:bat_library.bzl", "bat_library")

bat_library(
    name = "helpers",
    srcs = ["helper.bat"],
)

bat_binary(
    name = "tool",
    srcs = ["main.bat"],
    deps = [":helpers"],
)
```

## Documentation

For more details see the docs at <https://periareon.github.io/rules_batch/>
