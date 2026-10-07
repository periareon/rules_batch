@echo off
setlocal enableextensions enabledelayedexpansion

@REM Inline mode: the genrule in BUILD.bazel appends runfiles.bat to this file,
@REM so :rlocation is a local label and no preamble is needed. The script must
@REM exit before falling through into the appended library.

call :rlocation "rules_batch_examples/data/greeting.txt" GREETING_PATH
if errorlevel 1 (
    echo>&2 ERROR: could not resolve greeting.txt
    exit /b 1
)

echo Reading greeting from: %GREETING_PATH%
type "%GREETING_PATH%"
exit /b 0
