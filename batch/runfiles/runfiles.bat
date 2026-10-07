@REM Runfiles lookup library for Bazel-built batch scripts.
@REM
@REM Two modes of use:
@REM
@REM   Standalone (call as an external script; see the preamble in the docs):
@REM     call "%RLOCATION%" "workspace/path/to/file" RESULT_VAR [SOURCE_REPO]
@REM     call "%RLOCATION%" runfiles_export_envvars
@REM
@REM   Inline (paste or concatenate into your script, then call the labels):
@REM     call :rlocation "workspace/path/to/file" RESULT_VAR [SOURCE_REPO]
@REM     call :runfiles_export_envvars
@REM
@REM Both entry points run in their own setlocal scope: callers do not need
@REM delayed expansion, and no temporaries leak. Only the result variable, the
@REM RUNFILES_* variables and the _rl_RM_* cache variables are written to the
@REM caller's environment.
@REM
@REM rlocation:
@REM   Stores the absolute, backslash separated location of a runfile in
@REM   RESULT_VAR. Returns 1 and prints a message to stderr on failure.
@REM   Lookup order mirrors the other Bazel runfiles libraries:
@REM     1. The runfiles manifest, when one can be found. It is authoritative:
@REM        a populated runfiles directory may hold stale contents. If the path
@REM        itself is not listed, its parent directories are tried so that files
@REM        below a directory runfile (tree artifact) resolve as well.
@REM     2. RUNFILES_DIR\path, when no manifest exists but the file does.
@REM   Absolute paths (X:\... or X:/...) are returned unchanged. Paths that are
@REM   not normalized (leading /, ./, ../, //) are rejected.
@REM
@REM   The optional SOURCE_REPO argument is the canonical name of the
@REM   repository whose repo mapping resolves the first path segment. If
@REM   omitted, the main repository is assumed (batch has no BASH_SOURCE
@REM   equivalent for auto-detection).
@REM
@REM   Repo mapping: when a _repo_mapping runfile is present, the first path
@REM   segment (apparent repo name) is translated to the canonical runfiles
@REM   directory name before the lookup. The compact wildcard format produced
@REM   by --incompatible_compact_repo_mapping_manifest (Bazel 9) is supported.
@REM
@REM runfiles_export_envvars:
@REM   Ensures RUNFILES_DIR and RUNFILES_MANIFEST_FILE are both set so child
@REM   processes can initialize their own runfiles library. Returns 1 if
@REM   neither variable points to something usable.
@REM
@REM Manifest discovery order:
@REM   1. RUNFILES_MANIFEST_FILE env var (most explicit)
@REM   2. RUNFILES_DIR\MANIFEST (Windows / manifest-based runfiles)
@REM   3. RUNFILES_DIR_manifest (POSIX sibling convention)
@REM   4. %~f0.runfiles\MANIFEST
@REM   5. %~f0.runfiles_manifest
@REM   6. %~f0.exe.runfiles_manifest
@REM   In standalone mode %~f0 is this script, so 4-6 only apply inline.
@REM
@REM Performance: manifests and repo mappings below 256 KiB are scanned
@REM in-process with for /F (about a millisecond for typical files); larger
@REM files are queried with a single findstr.exe scan, which stays at roughly
@REM 20 ms for a 50,000 entry manifest where for /F takes 100 ms. The location
@REM of _repo_mapping and the last repo name translation are cached across
@REM calls. Loops avoid goto where possible since every goto rescans this file.
@REM
@REM Limitations: paths containing '!' cannot be handled, and manifest entries
@REM whose path or target contains a newline are not supported.

@REM Standalone entry point -- runs only when this script is called directly.
@REM When the file is pasted into another script, skip over the subroutines.
@if /i not "%~nx0"=="runfiles.bat" goto :_rl_end
@echo off
if /i "%~1"=="runfiles_export_envvars" (call :runfiles_export_envvars) else (call :rlocation %1 %2 %3)
exit /b %ERRORLEVEL%

:rlocation
@REM %1=rlocation path  %2=result variable  [%3=source repo canonical name]
if "%~2"=="" (
    echo>&2 ERROR: rlocation: expected arguments: PATH RESULT_VAR [SOURCE_REPO]
    exit /b 1
)
setlocal enableextensions enabledelayedexpansion
call :_rl_rlocation_impl %1 _rl_out %3
endlocal & set "%~2=%_rl_out%" & set "_rl_RM_FILE=%_rl_RM_FILE%" & set "_rl_RM_KEY=%_rl_RM_KEY%" & set "_rl_RM_LAST=%_rl_RM_LAST%" & set "_rl_RM_LAST_DIR=%_rl_RM_LAST_DIR%" & exit /b %ERRORLEVEL%

:runfiles_export_envvars
setlocal enableextensions enabledelayedexpansion
call :_rl_export_envvars_impl
endlocal & set "RUNFILES_DIR=%RUNFILES_DIR%" & set "RUNFILES_MANIFEST_FILE=%RUNFILES_MANIFEST_FILE%" & exit /b %ERRORLEVEL%

:_rl_rlocation_impl
@REM %1=rlocation path  %2=result variable  [%3=source repo canonical name]
set "%~2="
set "_rl_SCAN_MAX=262144"
set "_rl_path=%~1"
if not defined _rl_path (
    echo>&2 ERROR: rlocation: path must not be empty
    exit /b 1
)
set "_rl_path=!_rl_path:\=/!"
@REM Absolute paths are returned unchanged.
if "!_rl_path:~1,1!"==":" (
    set "%~2=!_rl_path:/=\!"
    exit /b 0
)
@REM Reject paths that are not normalized.
set "_rl_bad="
if "!_rl_path:~0,1!"=="/" set "_rl_bad=1"
if "!_rl_path:~0,2!"=="./" set "_rl_bad=1"
if "!_rl_path:~0,3!"=="../" set "_rl_bad=1"
if "!_rl_path:~-2!"=="/." set "_rl_bad=1"
if "!_rl_path:~-3!"=="/.." set "_rl_bad=1"
if not "!_rl_path:/./=!"=="!_rl_path!" set "_rl_bad=1"
if not "!_rl_path:/../=!"=="!_rl_path!" set "_rl_bad=1"
if not "!_rl_path://=!"=="!_rl_path!" set "_rl_bad=1"
if defined _rl_bad (
    echo>&2 ERROR: rlocation: path is not normalized: !_rl_path!
    exit /b 1
)

call :_rl_find_manifest
if not defined _rl_MF if not defined RUNFILES_DIR (
    echo>&2 ERROR: rlocation: cannot find runfiles manifest or directory
    exit /b 1
)

@REM Resolve _repo_mapping once per manifest/directory; cached across calls.
set "_rl_rm_cur=!_rl_MF!"
if not defined _rl_MF set "_rl_rm_cur=DIR !RUNFILES_DIR!"
if not "!_rl_RM_KEY!"=="!_rl_rm_cur!" (
    set "_rl_RM_KEY=!_rl_rm_cur!"
    set "_rl_RM_LAST="
    set "_rl_RM_FILE="
    call :_rl_lookup "_repo_mapping" _rl_RM_FILE
    if defined _rl_RM_FILE if not exist "!_rl_RM_FILE!" set "_rl_RM_FILE="
)

@REM Translate the apparent repo name. Single segment paths may be root
@REM symlinks and are not translated. The last translation is cached since
@REM scripts usually resolve several files from the same repository.
if defined _rl_RM_FILE (
    set "_rl_apparent="
    set "_rl_remainder="
    for /F "tokens=1,* delims=/" %%a in ("!_rl_path!") do (
        set "_rl_apparent=%%a"
        set "_rl_remainder=%%b"
    )
    if defined _rl_remainder (
        if not "!_rl_RM_LAST!"=="%~3 !_rl_apparent!" (
            set "_rl_RM_LAST=%~3 !_rl_apparent!"
            set "_rl_prefix="
            if not "%~3"=="" call :_rl_compute_prefix "%~3" _rl_prefix
            call :_rl_find_repo_mapping "%~3" "!_rl_prefix!" "!_rl_apparent!" "!_rl_RM_FILE!" _rl_RM_LAST_DIR
        )
        if defined _rl_RM_LAST_DIR set "_rl_path=!_rl_RM_LAST_DIR!/!_rl_remainder!"
    )
)

call :_rl_lookup "!_rl_path!" %~2
if errorlevel 1 (
    echo>&2 ERROR: rlocation: !_rl_path! not found in runfiles
    exit /b 1
)
exit /b 0

:_rl_export_envvars_impl
@REM Ensure both RUNFILES_DIR and RUNFILES_MANIFEST_FILE are set, deriving one
@REM from the other when needed. Returns 1 if neither is usable.
call :_rl_find_manifest
set "_rl_ev_dir="
if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\" set "_rl_ev_dir=1"
if not defined _rl_MF if not defined _rl_ev_dir exit /b 1
set "RUNFILES_MANIFEST_FILE=!_rl_MF!"
if not defined _rl_ev_dir (
    set "RUNFILES_DIR="
    if /i "!_rl_MF:~-9!"=="\MANIFEST" set "RUNFILES_DIR=!_rl_MF:~0,-9!"
    if /i "!_rl_MF:~-9!"=="_manifest" set "RUNFILES_DIR=!_rl_MF:~0,-9!"
    if defined RUNFILES_DIR if not exist "!RUNFILES_DIR!\" set "RUNFILES_DIR="
)
exit /b 0

:_rl_find_manifest
@REM Sets _rl_MF to the runfiles manifest path (backslashes; empty if none is
@REM found) and _rl_MF_SIZE to its size in bytes.
set "_rl_MF="
set "_rl_MF_SIZE=0"
if defined RUNFILES_MANIFEST_FILE if exist "!RUNFILES_MANIFEST_FILE!" set "_rl_MF=!RUNFILES_MANIFEST_FILE!"
if not defined _rl_MF if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\MANIFEST" set "_rl_MF=!RUNFILES_DIR!\MANIFEST"
if not defined _rl_MF if defined RUNFILES_DIR if exist "!RUNFILES_DIR!_manifest" set "_rl_MF=!RUNFILES_DIR!_manifest"
if not defined _rl_MF if exist "%~f0.runfiles\MANIFEST" set "_rl_MF=%~f0.runfiles\MANIFEST"
if not defined _rl_MF if exist "%~f0.runfiles_manifest" set "_rl_MF=%~f0.runfiles_manifest"
if not defined _rl_MF if exist "%~f0.exe.runfiles_manifest" set "_rl_MF=%~f0.exe.runfiles_manifest"
if not defined _rl_MF exit /b 0
set "_rl_MF=!_rl_MF:/=\!"
for %%f in ("!_rl_MF!") do set "_rl_MF_SIZE=%%~zf"
exit /b 0

:_rl_lookup
@REM Resolve a (canonical) rlocation path via the manifest, or via RUNFILES_DIR
@REM when there is no manifest. %1=path  %2=result variable.
@REM Silent; returns 1 if not found.
set "%~2="
set "_rl_lk_key=%~1"
if not defined _rl_MF (
    if defined RUNFILES_DIR if exist "!RUNFILES_DIR!\!_rl_lk_key:/=\!" (
        set "%~2=!RUNFILES_DIR:/=\!\!_rl_lk_key:/=\!"
        exit /b 0
    )
    exit /b 1
)
call :_rl_manifest_find "!_rl_lk_key!" %~2
if not errorlevel 1 exit /b 0
@REM Not listed directly: a parent directory may be a runfile (tree artifact).
@REM Move characters from the end of the prefix to the suffix; at each segment
@REM boundary look the prefix up, until a hit or the prefix is exhausted.
set "_rl_lk_prefix=!_rl_lk_key!"
set "_rl_lk_suffix="
set "_rl_lk_res="
for /L %%n in (1,1,1024) do if defined _rl_lk_prefix if not defined _rl_lk_res (
    set "_rl_lk_ch=!_rl_lk_prefix:~-1!"
    set "_rl_lk_prefix=!_rl_lk_prefix:~0,-1!"
    if defined _rl_lk_prefix if "!_rl_lk_ch!"=="/" (
        call :_rl_manifest_find "!_rl_lk_prefix!" _rl_lk_res
        if not defined _rl_lk_res set "_rl_lk_suffix=/!_rl_lk_suffix!"
    ) else set "_rl_lk_suffix=!_rl_lk_ch!!_rl_lk_suffix!"
)
if not defined _rl_lk_res exit /b 1
@REM Bazel manifests never list a path that is a prefix of another entry, so
@REM do not retry with a shorter prefix if the file is missing.
if not exist "!_rl_lk_res!\!_rl_lk_suffix:/=\!" exit /b 1
set "%~2=!_rl_lk_res!\!_rl_lk_suffix:/=\!"
exit /b 0

:_rl_manifest_find
@REM Look up an exact rlocation path in the manifest. %1=path  %2=result var.
@REM Silent; returns 1 if not found. Entries whose path contains a space are
@REM stored escaped: the line starts with a space, ' ' becomes \s and
@REM '\' becomes \b (in the target column only \b and \n are escaped).
set "%~2="
set "_rl_mf_key=%~1"
set "_rl_mf_esc=!_rl_mf_key:\=\b!"
set "_rl_mf_esc=!_rl_mf_esc: =\s!"
set "_rl_mf_line="
set "_rl_mf_res="
@REM Small manifests are scanned in-process. findstr is used for large ones,
@REM except for keys longer than the 510 characters it accepts.
if !_rl_MF_SIZE! lss !_rl_SCAN_MAX! goto :_rl_mf_scan
if not "!_rl_mf_key:~500,1!"=="" goto :_rl_mf_scan
call :_rl_findstr_first "!_rl_mf_key! " " !_rl_mf_esc! " "!_rl_MF!" _rl_mf_line
goto :_rl_mf_parse
:_rl_mf_scan
@REM for /F drops the leading space of escaped lines, so an escaped entry is
@REM recognized by its escaped key. Only consider that form when it differs
@REM from the plain key, otherwise a plain line would be unescaped wrongly.
for /F "usebackq tokens=1,*" %%i in ("!_rl_MF!") do (
    if "%%i"=="!_rl_mf_key!" set "_rl_mf_line=%%i %%j"
    if not "!_rl_mf_esc!"=="!_rl_mf_key!" if "%%i"=="!_rl_mf_esc!" set "_rl_mf_line= %%i %%j"
    if defined _rl_mf_line goto :_rl_mf_parse
)
:_rl_mf_parse
if not defined _rl_mf_line exit /b 1
for /F "tokens=1,*" %%i in ("!_rl_mf_line!") do set "_rl_mf_res=%%j"
if not defined _rl_mf_res exit /b 1
if "!_rl_mf_line:~0,1!"==" " set "_rl_mf_res=!_rl_mf_res:\b=\!"
set "%~2=!_rl_mf_res:/=\!"
exit /b 0

:_rl_findstr_first
@REM Store the first line of file %3 that starts with literal %1 or %2 in
@REM variable %4 (empty when there is none).
set "%~4="
for /F "usebackq delims=" %%L in (`%SYSTEMROOT%\system32\findstr.exe /b /l /c:"%~1" /c:"%~2" "%~3" 2^>nul`) do if not defined %~4 set "%~4=%%L"
exit /b 0

:_rl_compute_prefix
@REM Compute the wildcard prefix used by compact repo mapping entries: the
@REM trailing run of [a-zA-Z0-9_.-] characters after the last other character
@REM is replaced by '*'. Returns the input unchanged if it has no other
@REM character or ends with one.
@REM %1=repo name  %2=result variable
set "_rl_cp_str=%~1"
set "_rl_cp_trim=!_rl_cp_str!"
set "_rl_cp_done="
for /L %%n in (1,1,256) do if defined _rl_cp_trim if not defined _rl_cp_done (
    set "_rl_cp_ch=!_rl_cp_trim:~-1!"
    set "_rl_cp_safe="
    if /i "!_rl_cp_ch!" geq "a" if /i "!_rl_cp_ch!" leq "z" set "_rl_cp_safe=1"
    if "!_rl_cp_ch!" geq "0" if "!_rl_cp_ch!" leq "9" set "_rl_cp_safe=1"
    if "!_rl_cp_ch!"=="_" set "_rl_cp_safe=1"
    if "!_rl_cp_ch!"=="." set "_rl_cp_safe=1"
    if "!_rl_cp_ch!"=="-" set "_rl_cp_safe=1"
    if defined _rl_cp_safe (set "_rl_cp_trim=!_rl_cp_trim:~0,-1!") else set "_rl_cp_done=1"
)
set "%~2=!_rl_cp_trim!*"
if not defined _rl_cp_trim set "%~2=!_rl_cp_str!"
if "!_rl_cp_trim!"=="!_rl_cp_str!" set "%~2=!_rl_cp_str!"
exit /b 0

:_rl_find_repo_mapping
@REM Look up a repo mapping entry: the first line whose first two columns are
@REM either "source,apparent" (exact) or "prefix,apparent" (compact wildcard).
@REM %1=source_repo  %2=source_prefix  %3=apparent_name
@REM %4=mapping_file  %5=result variable (canonical target dir)
set "%~5="
set "_rl_rm_line="
set "_rl_rm_size=0"
for %%f in ("%~4") do set "_rl_rm_size=%%~zf"
if !_rl_rm_size! lss !_rl_SCAN_MAX! goto :_rl_rm_scan
call :_rl_findstr_first "%~1,%~3," "%~2,%~3," "%~4" _rl_rm_line
goto :_rl_rm_parse
:_rl_rm_scan
@REM A marker is prefixed so that an empty source column (the main repository)
@REM is not collapsed away by for /F.
for /F "usebackq delims=" %%L in ("%~4") do (
    set "_rl_rm_l=#%%L"
    for /F "tokens=1,2,* delims=," %%a in ("!_rl_rm_l!") do if "%%b"=="%~3" (
        if "%%a"=="#%~1" set "_rl_rm_line=%%L"
        if "%%a"=="#%~2" set "_rl_rm_line=%%L"
    )
    if defined _rl_rm_line goto :_rl_rm_parse
)
:_rl_rm_parse
if not defined _rl_rm_line exit /b 0
@REM Strip the first two comma-delimited fields to extract column 3.
set "_rl_rm_rest=!_rl_rm_line:*,=!"
set "%~5=!_rl_rm_rest:*,=!"
exit /b 0

:_rl_end
