# Runfiles

Utility for resolving [Bazel runfiles](https://bazel.build/extending/rules#runfiles) paths at runtime in batch scripts.

## Setup

Add the runfiles target to your `bat_binary` or `bat_test` dependencies:

```python
bat_binary(
    name = "my_tool",
    srcs = ["my_tool.bat"],
    deps = ["@rules_batch//batch/runfiles"],
)
```

## Preamble

Copy-paste this block at the top of your script (after `setlocal enabledelayedexpansion`) to locate `runfiles.bat` and set the `RLOCATION` variable:

```bat
@REM --- begin runfiles.bat initialization v1 ---
set "_rf=rules_batch/batch/runfiles/runfiles.bat"
set "RLOCATION="
if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\!_rf:/=\!" set "RLOCATION=!RUNFILES_DIR!\!_rf:/=\!"
if not defined RLOCATION if exist "%~f0.runfiles\!_rf:/=\!" (
    set "RUNFILES_DIR=%~f0.runfiles"
    set "RLOCATION=!RUNFILES_DIR!\!_rf:/=\!"
)
if not defined RLOCATION (
    set "_rf_mf="
    if defined RUNFILES_MANIFEST_FILE if exist "!RUNFILES_MANIFEST_FILE!" set "_rf_mf=!RUNFILES_MANIFEST_FILE!"
    if not defined _rf_mf if defined RUNFILES_DIR (
        if exist "!RUNFILES_DIR!\MANIFEST" (set "_rf_mf=!RUNFILES_DIR!\MANIFEST") else if exist "!RUNFILES_DIR!_manifest" set "_rf_mf=!RUNFILES_DIR!_manifest"
    )
    if not defined _rf_mf for %%m in ("%~f0.runfiles\MANIFEST" "%~f0.runfiles_manifest" "%~f0.exe.runfiles_manifest") do if not defined _rf_mf if exist "%%~m" set "_rf_mf=%%~m"
    if defined _rf_mf (
        set "_rf_mf=!_rf_mf:/=\!"
        for /F "tokens=1,* usebackq" %%i in ("!_rf_mf!") do if not defined RLOCATION (
            set "_k=%%i"
            if "%%i" equ "!_rf!" (set "RLOCATION=%%j") else if "!_k:~-28!" equ "/batch/runfiles/runfiles.bat" set "RLOCATION=%%j"
        )
    )
    if defined _rf_mf set "RUNFILES_MANIFEST_FILE=!_rf_mf!"
    set "_rf_mf="
    set "_k="
)
if not defined RLOCATION (echo>&2 ERROR: cannot find !_rf! & exit /b 1)
set "_rf="
@REM --- end runfiles.bat initialization v1 ---
```

After the preamble, `%RLOCATION%` points to `runfiles.bat` and you can resolve runfiles:

```bat
call "%RLOCATION%" "my_workspace/data/config.txt" CONFIG_PATH
echo Config is at: %CONFIG_PATH%
```

The preamble tries three strategies in order:

1. **Directory lookup** via `RUNFILES_DIR` -- fast path when the runfiles tree exists.
2. **Sibling `.runfiles` directory** next to the script (`%~f0.runfiles`).
3. **Manifest scan** -- reads the manifest file line-by-line to find the `runfiles.bat` entry. A suffix fallback matches any canonical repo prefix ending in `/batch/runfiles/runfiles.bat` to handle Bzlmod version suffixes.

## Full example

```bat
@echo off
setlocal enableextensions enabledelayedexpansion

@REM --- begin runfiles.bat initialization v1 ---
set "_rf=rules_batch/batch/runfiles/runfiles.bat"
set "RLOCATION="
if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\!_rf:/=\!" set "RLOCATION=!RUNFILES_DIR!\!_rf:/=\!"
if not defined RLOCATION if exist "%~f0.runfiles\!_rf:/=\!" (
    set "RUNFILES_DIR=%~f0.runfiles"
    set "RLOCATION=!RUNFILES_DIR!\!_rf:/=\!"
)
if not defined RLOCATION (
    set "_rf_mf="
    if defined RUNFILES_MANIFEST_FILE if exist "!RUNFILES_MANIFEST_FILE!" set "_rf_mf=!RUNFILES_MANIFEST_FILE!"
    if not defined _rf_mf if defined RUNFILES_DIR (
        if exist "!RUNFILES_DIR!\MANIFEST" (set "_rf_mf=!RUNFILES_DIR!\MANIFEST") else if exist "!RUNFILES_DIR!_manifest" set "_rf_mf=!RUNFILES_DIR!_manifest"
    )
    if not defined _rf_mf for %%m in ("%~f0.runfiles\MANIFEST" "%~f0.runfiles_manifest" "%~f0.exe.runfiles_manifest") do if not defined _rf_mf if exist "%%~m" set "_rf_mf=%%~m"
    if defined _rf_mf (
        set "_rf_mf=!_rf_mf:/=\!"
        for /F "tokens=1,* usebackq" %%i in ("!_rf_mf!") do if not defined RLOCATION (
            set "_k=%%i"
            if "%%i" equ "!_rf!" (set "RLOCATION=%%j") else if "!_k:~-28!" equ "/batch/runfiles/runfiles.bat" set "RLOCATION=%%j"
        )
    )
    if defined _rf_mf set "RUNFILES_MANIFEST_FILE=!_rf_mf!"
    set "_rf_mf="
    set "_k="
)
if not defined RLOCATION (echo>&2 ERROR: cannot find !_rf! & exit /b 1)
set "_rf="
@REM --- end runfiles.bat initialization v1 ---

call "%RLOCATION%" "my_workspace/data/config.txt" CONFIG_PATH
echo Config is at: %CONFIG_PATH%
```

## Repo mapping

When Bazel provides a `_repo_mapping` file in the runfiles manifest, `rlocation` automatically translates the first path segment (the apparent repo name) to the canonical runfiles directory name before the manifest lookup. This supports both the standard format and the compact wildcard format introduced by [`--incompatible_compact_repo_mapping_manifest`](https://github.com/bazelbuild/bazel/issues/26262) in Bazel 9.

The translation uses the **source repository** to determine which view of the repo mapping applies. By default, the main repository is assumed (empty source repo). An optional third argument can override this:

```bat
@REM Default: resolves using the main repo's mapping (most common case).
call "%RLOCATION%" "my_dep/data/file.txt" RESULT

@REM Explicit: resolves using +my_ext+my_repo's mapping.
call "%RLOCATION%" "my_dep/data/file.txt" RESULT "+my_ext+my_repo"
```

In practice, the third argument is almost never needed. Batch scripts live in the main repository in the vast majority of cases, and the default covers that. The explicit form exists for the rare case where a batch script in an external repository needs to resolve paths from its own repo mapping context.

## Exporting environment variables

Before spawning child processes that depend on runfiles (e.g. tools built with `rules_venv`), call `:runfiles_export_envvars` to ensure both `RUNFILES_DIR` and `RUNFILES_MANIFEST_FILE` are set:

```bat
call :runfiles_export_envvars
if errorlevel 1 (
    echo>&2 ERROR: runfiles environment not available
    exit /b 1
)
```

The preamble already sets whichever variable it discovers during initialization (mirroring the shell init block). This function fills in the **other** variable so children see a consistent pair:

- If only `RUNFILES_DIR` is set, derives `RUNFILES_MANIFEST_FILE` from `RUNFILES_DIR\MANIFEST` or `RUNFILES_DIR_manifest`.
- If only `RUNFILES_MANIFEST_FILE` is set, strips the `\MANIFEST` or `_manifest` suffix to derive `RUNFILES_DIR`.
- If both are already set and valid, no changes are made.
- Returns `exit /b 1` if neither variable points to a valid path.

This mirrors [`runfiles_export_envvars`](https://github.com/bazel-contrib/rules_shell) from `rules_shell`.

## Inline mode

Instead of calling `runfiles.bat` externally, you can concatenate or paste its content into your script at build time. The `:rlocation` subroutine is then available as a local label call:

```bat
call :rlocation "my_workspace/data/config.txt" CONFIG_PATH
echo Config is at: !CONFIG_PATH!
```

When inlined, only the subroutine block (between `goto :_rl_end` and `:_rl_end`) is active. The standalone entry point at the bottom of the file is unreachable because the user's script never falls through to it. Intermediate variables use a `_rl_` prefix to minimize collisions.
