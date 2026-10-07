@echo off
setlocal enableextensions enabledelayedexpansion

@REM Unit test: drives runfiles.bat against synthetic manifests, repo mappings
@REM and runfiles directories created in TEST_TMPDIR so that behaviors Bazel
@REM does not produce for this repository (external repos, compact repo
@REM mappings, escaped manifest entries, directory runfiles, large manifests,
@REM ...) are covered.

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

set "FAILED="

@REM Locate the inline mode test body through the real runfiles.
call "%RLOCATION%" "_main/batch/runfiles/tests/inline_test_body.bat" BODY
if errorlevel 1 (
    echo>&2 FAIL: cannot resolve inline_test_body.bat
    exit /b 1
)

@REM ---------------------------------------------------------------------------
@REM Build the synthetic runfiles fixtures. "small" exercises the in-process
@REM scan used for small files, "big" (padded well past 256 KiB) exercises the
@REM findstr path. Environment variables are set with forward slashes, as Bazel
@REM does; expectations use backslashes, as the library returns them.
@REM ---------------------------------------------------------------------------
set "T=%TEST_TMPDIR%"
if not defined T set "T=%TEMP%\rules_batch_runfiles_unit_test"
set "T=!T:/=\!\fixtures"
if exist "!T!\" rmdir /s /q "!T!"
mkdir "!T!"
@REM A 640 character key exceeds what findstr accepts as a search string.
set "L=zzzzzzzzzz"
for /L %%n in (1,1,6) do set "L=!L!!L!"
call :make_fixtures small 0
call :make_fixtures big 4000

for %%s in (small big) do (
    echo [TEST] --- manifest mode: %%s fixtures ---
    set "FX=!T!\%%s"
    call :manifest_cases
)

@REM ---------------------------------------------------------------------------
echo [TEST] --- directory mode ---
set "RUNFILES_MANIFEST_FILE="
set "RUNFILES_DIR=!T:\=/!/small/dir.runfiles"
call :expect "my_ws/data/a.txt" "!T!\small\dir.runfiles\_main\data\a.txt" "directory lookup with repo mapping"
call :expect "_main/data/a.txt" "!T!\small\dir.runfiles\_main\data\a.txt" "directory lookup"
call :expect_fail "_main/data/missing.txt" "missing file in directory mode"

@REM ---------------------------------------------------------------------------
echo [TEST] --- no runfiles ---
set "RUNFILES_MANIFEST_FILE="
set "RUNFILES_DIR="
call :expect_fail "_main/data/a.txt" "neither manifest nor directory"

@REM ---------------------------------------------------------------------------
echo [TEST] --- runfiles_export_envvars ---
set "RUNFILES_MANIFEST_FILE=!T:\=/!/small/x.runfiles/MANIFEST"
set "RUNFILES_DIR="
call "%RLOCATION%" runfiles_export_envvars
if errorlevel 1 (
    echo>&2 FAIL: export from manifest returned an error
    set "FAILED=1"
)
if /i not "!RUNFILES_DIR!"=="!T!\small\x.runfiles" (
    echo>&2 FAIL: RUNFILES_DIR not derived from a forward slash manifest path: [!RUNFILES_DIR!]
    set "FAILED=1"
) else (
    echo [TEST] PASS: RUNFILES_DIR derived from RUNFILES_MANIFEST_FILE
)
set "RUNFILES_MANIFEST_FILE="
set "RUNFILES_DIR=!T!\small\x.runfiles"
call "%RLOCATION%" runfiles_export_envvars
if /i not "!RUNFILES_MANIFEST_FILE!"=="!T!\small\x.runfiles\MANIFEST" (
    echo>&2 FAIL: RUNFILES_MANIFEST_FILE not derived from RUNFILES_DIR: [!RUNFILES_MANIFEST_FILE!]
    set "FAILED=1"
) else (
    echo [TEST] PASS: RUNFILES_MANIFEST_FILE derived from RUNFILES_DIR
)
set "RUNFILES_MANIFEST_FILE="
set "RUNFILES_DIR="
call "%RLOCATION%" runfiles_export_envvars
if not errorlevel 1 (
    echo>&2 FAIL: export without any runfiles should fail
    set "FAILED=1"
) else (
    echo [TEST] PASS: export without runfiles fails
)

@REM ---------------------------------------------------------------------------
echo [TEST] --- inline mode ---
set "RUNFILES_MANIFEST_FILE=!T:\=/!/small/x.runfiles/MANIFEST"
set "RUNFILES_DIR="
type "%BODY%" > "!T!\inline.bat"
type "%RLOCATION%" >> "!T!\inline.bat"
call "!T!\inline.bat" "!T!\small\src\a.txt" "!T!\small\src\x.bat"
if errorlevel 1 (
    echo>&2 FAIL: inline mode script failed
    set "FAILED=1"
) else (
    echo [TEST] PASS: inline mode
)

if defined FAILED (
    echo>&2 [TEST] FAILED
    exit /b 1
)
echo [TEST] PASS: all runfiles unit tests passed
exit /b 0

@REM ---------------------------------------------------------------------------
:make_fixtures
@REM %1=fixture name  %2=number of filler manifest/mapping lines
set "D=!T!\%~1"
mkdir "!D!\src" "!D!\tree\nested" "!D!\x.runfiles" "!D!\dir.runfiles\_main\data"
echo A> "!D!\src\a.txt"
echo X> "!D!\src\x.bat"
echo Y> "!D!\src\y.txt"
echo SP> "!D!\src\sp ace.txt"
echo NESTED> "!D!\tree\nested\file.txt"
echo DIRA> "!D!\dir.runfiles\_main\data\a.txt"
> "!D!\x.runfiles\MANIFEST" (
    for /L %%n in (1,1,%~2) do echo(_main/filler/dir%%n/file_%%n.txt C:/filler/bazel-out/x64_windows-fastbuild/bin/filler/dir%%n/file_%%n.txt
    echo(_main/data/a.txt !D:\=/!/src/a.txt
    echo(_main/tree !D:\=/!/tree
    echo( _main/sp\sace/f.txt !D:\=/!/src/sp ace.txt
    echo(_repo_mapping !D:\=/!/x.repo_mapping
    echo(dep+/lib/x.bat !D:\=/!/src/x.bat
    echo(other+1.2.3/y.txt !D:\=/!/src/y.txt
    echo(_main/k/!L! C:/x/long
)
> "!D!\x.repo_mapping" (
    for /L %%n in (1,1,%~2) do echo(filler_module++filler_extension+filler_repo_%%n,filler_apparent_name_%%n,filler_module++filler_extension+filler_repo_%%n
    echo(,dep,dep+
    echo(,my_ws,_main
    echo(dep+,other,other+1.2.3
    echo(mod++ext+*,dep,dep+
)
copy /y "!D!\x.repo_mapping" "!D!\dir.runfiles\_repo_mapping" >nul
exit /b 0

:manifest_cases
@REM Runs the manifest based cases against the fixture directory in FX.
set "RUNFILES_MANIFEST_FILE=!FX:\=/!/x.runfiles/MANIFEST"
set "RUNFILES_DIR=!FX:\=/!/x.runfiles"
call :expect "_main/data/a.txt" "!FX!\src\a.txt" "canonical path"
call :expect "my_ws/data/a.txt" "!FX!\src\a.txt" "main repo apparent name"
call :expect "dep/lib/x.bat" "!FX!\src\x.bat" "external repo apparent name"
call :expect "_main\data\a.txt" "!FX!\src\a.txt" "backslash separators"
call :expect "_main/tree/nested/file.txt" "!FX!\tree\nested\file.txt" "file below a directory runfile"
call :expect "my_ws/tree/nested/file.txt" "!FX!\tree\nested\file.txt" "mapped file below a directory runfile"
call :expect "_main/sp ace/f.txt" "!FX!\src\sp ace.txt" "escaped manifest entry"
call :expect "_main/k/!L!" "C:\x\long" "key longer than findstr allows"
call :expect "C:\abs\file.txt" "C:\abs\file.txt" "absolute path passthrough"
call :expect "C:/abs/file.txt" "C:\abs\file.txt" "absolute path with forward slashes"
call :expect "_repo_mapping" "!FX!\x.repo_mapping" "single segment path"
call :expect "other/y.txt" "!FX!\src\y.txt" "explicit source repo" "dep+"
call :expect "dep/lib/x.bat" "!FX!\src\x.bat" "compact repo mapping prefix" "mod++ext+repo"
call :expect "dep/lib/x.bat" "!FX!\src\x.bat" "cached translation reused" "mod++ext+repo"
call :expect_fail "other/y.txt" "apparent name unknown to the main repo"
call :expect_fail "_main/tree/nested/missing.txt" "missing file below a directory runfile"
call :expect_fail "_main/missing.txt" "missing entry"
call :expect_fail "_MAIN/data/a.txt" "case sensitive keys"
call :expect_fail "../x" "parent reference"
call :expect_fail "_main/../x" "embedded parent reference"
call :expect_fail "_main//x" "double slash"
call :expect_fail "/x" "leading slash"
call :expect_fail "_main/./x" "dot segment"
call :expect_fail "" "empty path"
exit /b 0

:expect
@REM %1=path  %2=expected result  %3=description  [%4=source repo]
set "OUT="
call "%RLOCATION%" %1 OUT %4
if errorlevel 1 (
    echo>&2 FAIL: %~3: rlocation failed
    set "FAILED=1"
    exit /b 0
)
if /i not "!OUT!"=="%~2" (
    echo>&2 FAIL: %~3: got [!OUT!] expected [%~2]
    set "FAILED=1"
    exit /b 0
)
echo [TEST] PASS: %~3
exit /b 0

:expect_fail
@REM %1=path  %2=description
set "OUT=unset"
call "%RLOCATION%" %1 OUT 2>nul
if not errorlevel 1 (
    echo>&2 FAIL: %~2: expected failure but got [!OUT!]
    set "FAILED=1"
    exit /b 0
)
if defined OUT (
    echo>&2 FAIL: %~2: result variable not cleared on failure: [!OUT!]
    set "FAILED=1"
    exit /b 0
)
echo [TEST] PASS: %~2
exit /b 0
