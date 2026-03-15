@REM Runfiles rlocation utility for batch scripts.
@REM
@REM Two modes of use:
@REM
@REM   Standalone (call as an external script):
@REM     call "%RLOCATION%" "workspace/path/to/file" RESULT_VAR [SOURCE_REPO]
@REM
@REM   Inline (paste or concatenate into your script, then call the subroutine):
@REM     call :rlocation "workspace/path/to/file" RESULT_VAR [SOURCE_REPO]
@REM
@REM   Export runfiles env vars (for child processes):
@REM     call :runfiles_export_envvars
@REM
@REM The optional SOURCE_REPO argument specifies the canonical name of the
@REM repository whose repo mapping is used to resolve the first path segment.
@REM If omitted, the main repository is assumed (same default as runfiles.sh;
@REM batch has no BASH_SOURCE equivalent for auto-detection).
@REM
@REM Repo mapping:
@REM   When Bazel provides a _repo_mapping file in the runfiles manifest, the
@REM   first path segment (apparent repo name) is translated to the canonical
@REM   runfiles directory name before the manifest lookup. This includes
@REM   support for the compact wildcard format from
@REM   --incompatible_compact_repo_mapping_manifest (Bazel 9).
@REM
@REM Manifest discovery order:
@REM   1. RUNFILES_MANIFEST_FILE env var (most explicit)
@REM   2. RUNFILES_DIR\MANIFEST (Windows / manifest-based runfiles)
@REM   3. RUNFILES_DIR_manifest (POSIX sibling convention)
@REM   4. %~f0.runfiles\MANIFEST
@REM   5. %~f0.runfiles_manifest
@REM   6. %~f0.exe.runfiles_manifest

@REM --- begin subroutines ---
goto :_rl_end

:rlocation
if "%~2" equ "" (
    echo>&2 ERROR: Expected at least two arguments for rlocation.
    exit /b 1
)

set "_rl_MF="
if not defined _rl_MF if defined RUNFILES_MANIFEST_FILE if exist "!RUNFILES_MANIFEST_FILE!" (
    set "_rl_MF=!RUNFILES_MANIFEST_FILE!"
)
if not defined _rl_MF if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\MANIFEST" (
    set "_rl_MF=!RUNFILES_DIR!\MANIFEST"
)
if not defined _rl_MF if defined RUNFILES_DIR if exist "!RUNFILES_DIR!_manifest" (
    set "_rl_MF=!RUNFILES_DIR!_manifest"
)
if not defined _rl_MF if exist "%~f0.runfiles\MANIFEST" (
    set "_rl_MF=%~f0.runfiles\MANIFEST"
)
if not defined _rl_MF if exist "%~f0.runfiles_manifest" (
    set "_rl_MF=%~f0.runfiles_manifest"
)
if not defined _rl_MF if exist "%~f0.exe.runfiles_manifest" (
    set "_rl_MF=%~f0.exe.runfiles_manifest"
)
if not defined _rl_MF (
    echo>&2 ERROR: cannot find runfiles manifest
    exit /b 1
)
set "_rl_MF=!_rl_MF:/=\!"
if not exist "!_rl_MF!" (
    echo>&2 ERROR: Manifest file !_rl_MF! does not exist.
    exit /b 1
)

@REM Resolve _repo_mapping path on first call; cached for subsequent calls.
if not defined _rl_RM_INIT (
    set "_rl_RM_INIT=1"
    set "_rl_REPO_MAPPING="
    for /F "tokens=1,* usebackq" %%i in ("!_rl_MF!") do (
        if "%%i" equ "_repo_mapping" if not defined _rl_REPO_MAPPING set "_rl_REPO_MAPPING=%%j"
    )
)

set "_rl_path=%~1"
if defined _rl_REPO_MAPPING if exist "!_rl_REPO_MAPPING!" (
    set "_rl_apparent="
    set "_rl_remainder="
    for /F "tokens=1,* delims=/" %%a in ("!_rl_path!") do (
        set "_rl_apparent=%%a"
        set "_rl_remainder=%%b"
    )
    if defined _rl_remainder (
        call :_rl_compute_prefix "%~3" _rl_prefix
        call :_rl_find_repo_mapping "%~3" "!_rl_prefix!" "!_rl_apparent!" "!_rl_REPO_MAPPING!" _rl_target
        if defined _rl_target (
            set "_rl_path=!_rl_target!/!_rl_remainder!"
        )
    )
)

set "_rl_result="
for /F "tokens=1,* usebackq" %%i in ("!_rl_MF!") do (
    if "%%i" equ "!_rl_path!" if not defined _rl_result set "_rl_result=%%j"
)
if "!_rl_result!" equ "" (
    echo>&2 ERROR: !_rl_path! not found in runfiles manifest
    exit /b 1
)
set "%~2=!_rl_result:/=\!"
exit /b 0

:runfiles_export_envvars
@REM Ensure both RUNFILES_DIR and RUNFILES_MANIFEST_FILE are set.
@REM If only one is available, derives the other. Returns 1 if neither is usable.
set "_rl_has_mf="
if defined RUNFILES_MANIFEST_FILE if exist "!RUNFILES_MANIFEST_FILE!" set "_rl_has_mf=1"
set "_rl_has_dir="
if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\" set "_rl_has_dir=1"
if not defined _rl_has_mf if not defined _rl_has_dir (
    set "_rl_has_mf=" & set "_rl_has_dir="
    exit /b 1
)
if not defined _rl_has_mf (
    if exist "!RUNFILES_DIR!\MANIFEST" (
        set "RUNFILES_MANIFEST_FILE=!RUNFILES_DIR!\MANIFEST"
    ) else if exist "!RUNFILES_DIR!_manifest" (
        set "RUNFILES_MANIFEST_FILE=!RUNFILES_DIR!_manifest"
    ) else (
        set "RUNFILES_MANIFEST_FILE="
    )
)
if not defined _rl_has_dir (
    set "_rl_ev_p=!RUNFILES_MANIFEST_FILE!"
    if "!_rl_ev_p:~-9!" equ "\MANIFEST" (
        set "_rl_ev_d=!_rl_ev_p:~0,-9!"
        if exist "!_rl_ev_d!\" (set "RUNFILES_DIR=!_rl_ev_d!") else set "RUNFILES_DIR="
    ) else if "!_rl_ev_p:~-9!" equ "_manifest" (
        set "_rl_ev_d=!_rl_ev_p:~0,-9!"
        if exist "!_rl_ev_d!\" (set "RUNFILES_DIR=!_rl_ev_d!") else set "RUNFILES_DIR="
    ) else (
        set "RUNFILES_DIR="
    )
    set "_rl_ev_p=" & set "_rl_ev_d="
)
set "_rl_has_mf=" & set "_rl_has_dir="
exit /b 0

:_rl_compute_prefix
@REM Compute wildcard prefix for compact repo mapping support.
@REM Strips trailing safe characters [a-zA-Z0-9_.-] and appends *.
@REM Returns the input unchanged if no non-safe character exists.
@REM %1=repo_name  %2=output_var
set "_rl_cp_str=%~1"
set "_rl_cp_trim=!_rl_cp_str!"
:_rl_cp_loop
if "!_rl_cp_trim!" equ "" (
    set "%~2=!_rl_cp_str!"
    exit /b 0
)
set "_rl_cp_ch=!_rl_cp_trim:~-1!"
echo(!_rl_cp_ch!| %SYSTEMROOT%\system32\findstr.exe /r "^[a-zA-Z0-9_.-]$" >nul 2>&1
if errorlevel 1 (
    set "%~2=!_rl_cp_trim!*"
    exit /b 0
)
set "_rl_cp_trim=!_rl_cp_trim:~0,-1!"
goto :_rl_cp_loop

:_rl_find_repo_mapping
@REM Look up a repo mapping entry. Searches for lines starting with either
@REM "source,apparent," (exact) or "prefix,apparent," (compact wildcard).
@REM Uses findstr /l so the * in compact entries is matched literally.
@REM %1=source_repo  %2=source_prefix  %3=apparent_name
@REM %4=mapping_file  %5=output_var (canonical target dir)
set "%~5="
set "_rl_rm_pat1=%~1,%~3,"
set "_rl_rm_pat2=%~2,%~3,"
for /F "usebackq delims=" %%L in (`%SYSTEMROOT%\system32\findstr.exe /b /l /c:"!_rl_rm_pat1!" /c:"!_rl_rm_pat2!" "%~4" 2^>nul`) do (
    set "_rl_rm_line=%%L"
    @REM Strip first two comma-delimited fields to extract column 3.
    set "_rl_rm_rest=!_rl_rm_line:*,=!"
    set "%~5=!_rl_rm_rest:*,=!"
    goto :_rl_rm_done
)
:_rl_rm_done
exit /b 0

:_rl_end
@REM --- end subroutines ---

@REM Standalone entry point -- only runs when script is called directly.
if /i not "%~nx0" equ "runfiles.bat" goto :_rl_main_end
@echo off
setlocal enableextensions enabledelayedexpansion
call :rlocation %1 %2 %3
set "_rl_out=!%~2!"
endlocal & set "%~2=%_rl_out%"
exit /b %ERRORLEVEL%
:_rl_main_end
