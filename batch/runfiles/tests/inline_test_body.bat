@echo off
setlocal enableextensions enabledelayedexpansion

@REM Body of the inline mode test. runfiles_unit_test.bat appends runfiles.bat
@REM to this file and runs the result, so :rlocation and
@REM :runfiles_export_envvars are local labels here.
@REM %1=expected location of my_ws/data/a.txt  %2=expected location of dep/lib/x.bat

call :rlocation "my_ws/data/a.txt" R
if errorlevel 1 (
    echo>&2 FAIL: inline rlocation failed
    exit /b 1
)
if /i not "!R!"=="%~1" (
    echo>&2 FAIL: inline rlocation returned [!R!], expected [%~1]
    exit /b 1
)
call :rlocation "dep/lib/x.bat" R2 "mod++ext+repo"
if errorlevel 1 (
    echo>&2 FAIL: inline rlocation with source repo failed
    exit /b 1
)
if /i not "!R2!"=="%~2" (
    echo>&2 FAIL: inline rlocation with source repo returned [!R2!], expected [%~2]
    exit /b 1
)
call :runfiles_export_envvars
if errorlevel 1 (
    echo>&2 FAIL: inline runfiles_export_envvars failed
    exit /b 1
)
if not defined RUNFILES_DIR (
    echo>&2 FAIL: inline runfiles_export_envvars did not set RUNFILES_DIR
    exit /b 1
)
if defined _rl_path (
    echo>&2 FAIL: inline rlocation leaked temporaries into the caller
    exit /b 1
)
exit /b 0

@REM runfiles.bat is appended below this line by the test.
