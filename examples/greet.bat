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

call "%RLOCATION%" "_main/data/greeting.txt" GREETING_PATH
if errorlevel 1 (
    echo>&2 ERROR: could not resolve greeting.txt
    exit /b 1
)

echo Reading greeting from: %GREETING_PATH%
type "%GREETING_PATH%"
