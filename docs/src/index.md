# rules_batch

Bazel rules for [Microsoft Batch](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands).

## Setup

```python
bazel_dep(name = "rules_batch", version = "{version}")
```

## Overview

`rules_batch` provides Bazel rules for building and testing Microsoft Batch
(`.bat` / `.cmd`) scripts. The rules handle runfiles propagation, dependency
tracking, and runtime path resolution so that batch scripts integrate cleanly
into Bazel builds.

The rule set consists of:

- **`bat_binary`** -- declares an executable batch script.
- **`bat_test`** -- declares a test batch script.
- **`bat_library`** -- groups batch scripts and data for reuse as dependencies.

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

## Runfiles

To resolve runfiles paths at runtime, add `@rules_batch//batch/runfiles` to
your target's `deps` and use the [runfiles preamble](./runfiles.md) in your script:

```bat
call "%RLOCATION%" "workspace/path/to/file" RESULT_VAR
```

See the [Runfiles](./runfiles.md) page for the full preamble, repo mapping, and manifest discovery details.
