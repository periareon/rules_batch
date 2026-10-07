@echo off
setlocal enableextensions enabledelayedexpansion

@REM Integration test: exercises runfiles.bat through the documented preamble
@REM against the real runfiles of this test.

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

echo [TEST] runfiles.bat found at: %RLOCATION%
if not exist "%RLOCATION%" (
    echo>&2 FAIL: RLOCATION does not exist on disk
    exit /b 1
)
set "FAILED="

call :expect_file "_main/batch/runfiles/tests/data.txt" "canonical repo name"
set "DATA_PATH=!OUT!"
call :expect_file "rules_batch/batch/runfiles/tests/data.txt" "apparent repo name through repo mapping"
if /i not "!OUT!"=="!DATA_PATH!" (
    echo>&2 FAIL: apparent and canonical lookups differ: [!OUT!] vs [!DATA_PATH!]
    set "FAILED=1"
)
call :expect_file "rules_batch/batch/runfiles/runfiles.bat" "library through apparent repo name"
call :expect_file "_main\batch\runfiles\tests\data.txt" "backslash separated path"
call :expect_fail "_main/batch/runfiles/tests/does_not_exist.txt" "missing file"
call :expect_fail "../escape.txt" "non-normalized path"

@REM The cache for the repo mapping location must survive standalone calls.
if not defined _rl_RM_KEY (
    echo>&2 FAIL: repo mapping cache was not exported by the standalone entry point
    set "FAILED=1"
)

@REM Verify the resolved data file contains the expected payload.
set "FOUND="
for /F "usebackq" %%L in ("!DATA_PATH!") do (
    if "%%L"=="RULES_BATCH_TEST_PAYLOAD" set "FOUND=1"
)
if not defined FOUND (
    echo>&2 FAIL: data.txt does not contain expected payload
    set "FAILED=1"
) else (
    echo [TEST] PASS: data.txt payload verified
)

@REM runfiles_export_envvars in standalone mode.
call "%RLOCATION%" runfiles_export_envvars
if errorlevel 1 (
    echo>&2 FAIL: runfiles_export_envvars returned an error
    set "FAILED=1"
)
if not defined RUNFILES_DIR (
    echo>&2 FAIL: RUNFILES_DIR not set after runfiles_export_envvars
    set "FAILED=1"
)
if not defined RUNFILES_MANIFEST_FILE (
    echo>&2 FAIL: RUNFILES_MANIFEST_FILE not set after runfiles_export_envvars
    set "FAILED=1"
)
if not exist "!RUNFILES_MANIFEST_FILE!" (
    echo>&2 FAIL: RUNFILES_MANIFEST_FILE does not exist: !RUNFILES_MANIFEST_FILE!
    set "FAILED=1"
)
echo [TEST] exported RUNFILES_DIR=!RUNFILES_DIR!
echo [TEST] exported RUNFILES_MANIFEST_FILE=!RUNFILES_MANIFEST_FILE!

if defined FAILED (
    echo>&2 [TEST] FAILED
    exit /b 1
)
echo [TEST] PASS: all runfiles integration checks passed
exit /b 0

:expect_file
@REM %1=path  %2=description. Resolves %1 and checks the result exists.
set "OUT="
call "%RLOCATION%" %1 OUT
if errorlevel 1 (
    echo>&2 FAIL: %~2: rlocation failed for %~1
    set "FAILED=1"
    exit /b 0
)
if not exist "!OUT!" (
    echo>&2 FAIL: %~2: resolved path does not exist: !OUT!
    set "FAILED=1"
    exit /b 0
)
echo [TEST] PASS: %~2: !OUT!
exit /b 0

:expect_fail
@REM %1=path  %2=description. Expects rlocation to fail for %1.
set "OUT="
call "%RLOCATION%" %1 OUT 2>nul
if not errorlevel 1 (
    echo>&2 FAIL: %~2: expected %~1 to fail but got [!OUT!]
    set "FAILED=1"
    exit /b 0
)
echo [TEST] PASS: %~2 rejected
exit /b 0
