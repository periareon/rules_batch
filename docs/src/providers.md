# Providers

`rules_batch` defines two marker providers for type-safe dependency graphs:

| Provider | Advertised by | Required by |
| --- | --- | --- |
| `BatInfo` | `bat_library` | `deps` of `bat_binary`, `bat_test`, `bat_library` |
| `BatBinaryInfo` | `bat_binary`, `bat_test` | -- |

These providers carry no fields; they exist so that `deps` attributes can
restrict the set of allowed targets to the appropriate rule types.

Load them from the public API:

```python
load("@rules_batch//batch:bat_info.bzl", "BatInfo")
load("@rules_batch//batch:bat_binary_info.bzl", "BatBinaryInfo")
```
