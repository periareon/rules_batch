# Rules (rules_batch)

This repository provides Microsoft Batch rules for Bazel.

## `bat_binary`

- **Purpose:** Declares an executable batch script with a runfiles-aware launcher.
- **Sources:** Exactly one `.bat` or `.cmd` in `srcs` (the entry script).
- **Runfiles:** Merges `deps`, `data`, the entry script, and runfiles support from `//batch/runfiles`.

Runtime resolution uses the [runfiles preamble](./runfiles.md) to set the `RLOCATION` variable, then resolves paths via:

```bat
call "%RLOCATION%" "workspace/path/to/file" RESULT_VAR
```

## `bat_library`

- **Purpose:** Groups batch scripts (and optional data) for reuse. There is no link step; libraries only bundle files and propagate `DefaultInfo` runfiles.
- **Sources:** Any number of `.bat` / `.cmd` files in `srcs`, plus optional `data` and `deps` on other libraries.

Depend on a library from `bat_binary` via `deps` so helper scripts appear next to the binary in the runfiles tree.

## `bat_library` vs `filegroup`

| Use | Prefer |
| --- | --- |
| Reusable batch helpers depended on by `bat_binary` / `bat_library` | `bat_library` |
| Arbitrary files in runfiles without batch-specific meaning | `filegroup` and `data` on `bat_binary` |

Both end up in runfiles once attached; the distinction is clarity and convention, not a separate mechanism.

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

Use the module name from your `bazel_dep` in place of `@rules_batch` if needed.
