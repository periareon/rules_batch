#!/usr/bin/env bash
# A shell test that launches a batch script on Windows. The batch script has
# no runfiles tree or manifest of its own, so it must find the runfiles through
# the RUNFILES_* variables Bazel gives the shell test, which the shell passes
# on. This mirrors a bash wrapper or sh_test driving a Windows-only tool.

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

bat="$(rlocation _main/batch/runfiles/tests/runfiles_test.bat)"
[[ -f "${bat}" ]] || { echo >&2 "FAIL: cannot resolve runfiles_test.bat"; exit 1; }

# Make sure the child sees both variables, like any runfiles-aware child.
runfiles_export_envvars

# cmd.exe needs a Windows path. MSYS must not rewrite the /c switch.
win_bat="$(cygpath -w "${bat}")"
echo "[TEST] launching ${win_bat} from bash"
MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' cmd.exe /c "${win_bat}"
echo "[TEST] PASS: batch script resolved its runfiles when launched from a shell test"
