# shellcheck shell=bash
# Argument translation between omnigent's `pi-native` harness and omp.
#
# omnigent builds `--extension <js> [--approve] --session-dir <dir>
# [--session <id>] <user args>` (omnigent/runner/native/orchestration.py
# _build_pi_native_args) against the upstream `pi` CLI at 0.79.x. omp 17.x
# differs in three ways:
#
#   1. `--approve` (pi's project-trust override) does not exist; omp exits
#      "unknown flag: --approve". Drop it — a human is attached to the TUI and
#      omp's own approval prompts are what we want.
#   2. `--session <id>` is spelled `--resume <id>` in omp.
#   3. omnigent's bridge extension is CommonJS (`module.exports = fn`), while
#      omp dynamic-imports the file and accepts only `module` /
#      `module.default` as the factory — a CJS file fails with "Extension does
#      not export a valid factory function". Point omp at a generated ESM
#      adapter that re-exports the CJS factory as a default export instead.
#      Verified: the status line then reads "· linked", prompts typed in the
#      TUI appear in the dashboard transcript, and messages sent from the
#      dashboard execute in the TUI.
argv=()
while [ "$#" -gt 0 ]; do
  case "$1" in
  --approve)
    shift
    ;;
  --session)
    argv+=(--resume "$2")
    shift 2
    ;;
  --extension)
    ext=$2
    shift 2
    adapter="$(dirname "$ext")/omnigent-esm-adapter.mjs"
    if [ ! -e "$adapter" ]; then
      cat >"$adapter" <<EOF
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
export default require("$ext");
EOF
    fi
    argv+=(--extension "$adapter")
    ;;
  *)
    argv+=("$1")
    shift
    ;;
  esac
done

exec "$OMP_BIN" "${argv[@]}"
