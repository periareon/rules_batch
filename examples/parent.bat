@echo off
setlocal enableextensions enabledelayedexpansion

@REM Parent script: resolves a child script from its own runfiles, makes sure
@REM both RUNFILES_DIR and RUNFILES_MANIFEST_FILE are exported, and runs the
@REM child. The child then locates the same runfiles through the environment.

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

call "%RLOCATION%" "rules_batch_examples/child.bat" CHILD
if errorlevel 1 (
    echo>&2 ERROR: could not resolve child.bat
    exit /b 1
)

call "%RLOCATION%" runfiles_export_envvars
if errorlevel 1 (
    echo>&2 ERROR: runfiles environment not available
    exit /b 1
)

echo Parent starting: %CHILD%
call "%CHILD%"
if errorlevel 1 (
    echo>&2 ERROR: child failed
    exit /b 1
)
echo Parent done.
exit /b 0
