# Runfiles

`runfiles.bat` resolves [Bazel runfiles](https://bazel.build/extending/rules#runfiles) paths from batch scripts, the way `runfiles.bash` does for shell scripts.

## Setup

Add the runfiles target to the `deps` of your `bat_binary` or `bat_test`:

```python
bat_binary(
    name = "my_tool",
    srcs = ["my_tool.bat"],
    data = ["data/config.txt"],
    deps = ["@rules_batch//batch/runfiles"],
)
```

Then paste this block at the top of your script, after `setlocal enabledelayedexpansion`. It locates `runfiles.bat` and stores its path in `RLOCATION`:

```bat
@REM --- begin runfiles.bat initialization v3 ---
set "_rf=batch/runfiles/runfiles.bat"
if not defined RUNFILES_DIR if exist "%~f0.runfiles\" set "RUNFILES_DIR=%~f0.runfiles"
set "_rf_mf="
if defined RUNFILES_MANIFEST_FILE if exist "!RUNFILES_MANIFEST_FILE!" set "_rf_mf=!RUNFILES_MANIFEST_FILE!"
if not defined _rf_mf if defined RUNFILES_DIR for %%m in ("!RUNFILES_DIR!\MANIFEST" "!RUNFILES_DIR!_manifest") do if not defined _rf_mf if exist "%%~m" set "_rf_mf=%%~m"
if not defined _rf_mf for %%m in ("%~f0.runfiles_manifest" "%~f0.exe.runfiles_manifest") do if not defined _rf_mf if exist "%%~m" set "_rf_mf=%%~m"
if defined _rf_mf (set "_rf_mf=!_rf_mf:/=\!" & set "RUNFILES_MANIFEST_FILE=!_rf_mf!")
@REM Map the apparent repo name rules_batch to its canonical runfiles directory.
set "_rf_rm="
if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\_repo_mapping" set "_rf_rm=!RUNFILES_DIR!\_repo_mapping"
if not defined _rf_rm if defined _rf_mf for /F "usebackq tokens=1,*" %%i in (`%SYSTEMROOT%\system32\findstr.exe /b /l /c:"_repo_mapping " "!_rf_mf!" 2^>nul`) do set "_rf_rm=%%j"
set "_rf_c="
if defined _rf_rm for /F "usebackq delims=" %%L in ("!_rf_rm:/=\!") do if not defined _rf_c (
    set "_rf_l=%%L"
    if not "!_rf_l:,rules_batch,=!"=="!_rf_l!" (set "_rf_c=!_rf_l:*,=!" & set "_rf_c=!_rf_c:*,=!")
)
if not defined _rf_c set "_rf_c=rules_batch"
set "_rf=!_rf_c!/!_rf!"
set "RLOCATION="
if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\!_rf:/=\!" set "RLOCATION=!RUNFILES_DIR!\!_rf:/=\!"
if not defined RLOCATION if defined _rf_mf for /F "usebackq tokens=1,*" %%i in (`%SYSTEMROOT%\system32\findstr.exe /b /l /c:"!_rf! " "!_rf_mf!" 2^>nul`) do if not defined RLOCATION set "RLOCATION=%%j"
if not defined RLOCATION (echo>&2 ERROR: cannot find !_rf! in runfiles & exit /b 1)
set "RLOCATION=!RLOCATION:/=\!"
set "_rf=" & set "_rf_mf=" & set "_rf_rm=" & set "_rf_c=" & set "_rf_l="
@REM --- end runfiles.bat initialization v3 ---
```

The block works under `bazel test`, `bazel run`, and when the built script is started directly from `bazel-bin`. If your `MODULE.bazel` renames the dependency with `repo_name`, replace `,rules_batch,` in the block with that name.

## Resolving paths

```bat
call "%RLOCATION%" "my_module/data/config.txt" CONFIG_PATH
if errorlevel 1 exit /b 1
type "%CONFIG_PATH%"
```

```
call "%RLOCATION%" PATH RESULT_VAR [SOURCE_REPO]
```

- `PATH` is `repo/package/file`, where `repo` is the name you use for that repository in `MODULE.bazel` (your own module's name for files in the main repository). `/` and `\` both work as separators. Files inside directory outputs resolve as well. Lookups are case sensitive.
- On success `RESULT_VAR` holds the absolute, backslash separated location and the exit code is `0`. On failure `RESULT_VAR` is empty, a message goes to stderr, and the exit code is `1`.
- `SOURCE_REPO` is only needed when the calling script lives in an external repository and must resolve names from that repository's point of view; pass its canonical name, for example `+my_ext+my_repo`. Batch cannot detect the calling script's repository on its own, so the default is the main repository.

## Child processes

Scripts started by yours that use a runfiles library themselves need `RUNFILES_DIR` and `RUNFILES_MANIFEST_FILE`. Before starting them, make sure both are set:

```bat
call "%RLOCATION%" runfiles_export_envvars
if errorlevel 1 exit /b 1
```

It fills in whichever variable is missing from the other one and returns `1` if neither points to anything usable.

## Inline mode

Instead of the preamble you can append `runfiles.bat` to your script at build time and call the labels directly. The script must `exit /b` before the end so execution does not run into the appended library.

```python
genrule(
    name = "my_tool_bundled",
    srcs = ["my_tool_body.bat", "@rules_batch//batch/runfiles:runfiles.bat"],
    outs = ["my_tool_bundled.bat"],
    cmd = "cat $(SRCS) > $@",
)
```

```bat
call :rlocation "my_module/data/config.txt" CONFIG_PATH
call :runfiles_export_envvars
```

Both calls run in their own scope and only write their results to your environment, plus a few `_rl_RM_*` cache variables.

## Examples

The [`examples`](https://github.com/periareon/rules_batch/tree/main/examples) module contains a working copy of each pattern, run both as tests and directly from `bazel-bin` in CI:

| Example | Shows |
|---|---|
| `greet.bat` | The preamble and `call "%RLOCATION%"`. |
| `inline_greet_body.bat` | Inline mode with the `genrule` above. |
| `parent.bat` / `child.bat` | `runfiles_export_envvars` before starting a script that uses runfiles itself. |

## Limitations

- Paths containing `!` cannot be resolved.
- The repository used for name translation defaults to the main repository; pass `SOURCE_REPO` from scripts in external repositories.
