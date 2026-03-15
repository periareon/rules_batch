@echo off
setlocal enableextensions enabledelayedexpansion

@REM --- begin runfiles.bat initialization v1 ---
set "_rf=_main/batch/runfiles/runfiles.bat"
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
        for /F "tokens=1,* usebackq" %%i in ("!_rf_mf!") do if "%%i" equ "!_rf!" if not defined RLOCATION set "RLOCATION=%%j"
    )
    if defined _rf_mf set "RUNFILES_MANIFEST_FILE=!_rf_mf!"
    set "_rf_mf="
)
if not defined RLOCATION (echo>&2 FAIL: cannot find !_rf! & exit /b 1)
set "_rf="
@REM --- end runfiles.bat initialization v1 ---

echo [TEST] rlocation.bat found at: %RLOCATION%

@REM Resolve the test data file via rlocation.
call "%RLOCATION%" "_main/batch/runfiles/tests/data.txt" DATA_PATH
if errorlevel 1 (
    echo>&2 FAIL: rlocation could not resolve data.txt
    exit /b 1
)
echo [TEST] data.txt resolved to: %DATA_PATH%

@REM Verify the resolved path actually exists on disk.
if not exist "%DATA_PATH%" (
    echo>&2 FAIL: resolved path does not exist: %DATA_PATH%
    exit /b 1
)

@REM Verify the file contains the expected payload.
set "FOUND="
for /F "usebackq" %%L in ("%DATA_PATH%") do (
    if "%%L" equ "RULES_BATCH_TEST_PAYLOAD" set "FOUND=1"
)
if not defined FOUND (
    echo>&2 FAIL: data.txt does not contain expected payload
    exit /b 1
)

echo [TEST] PASS: runfiles rlocation resolved and verified data.txt
exit /b 0
