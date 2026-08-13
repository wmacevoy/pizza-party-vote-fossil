#!/usr/bin/env bash
set -euo pipefail

# Build fossil-ppv: a thin wrapper around the shared fossil-see project
# (vendor/fossil-see, https://github.com/wmacevoy/fossil-sqlcipher-libressl),
# which builds Fossil + SQLCipher + LibreSSL with a mode-aware PRAGMA key
# patch. This script just delegates to it and copies the result here as
# fossil-ppv, keeping the binary name this repo's docs/tests/CI already
# depend on.
#
# fossil-see was factored out of this repo so pizza-party-vote-fossil and
# fossil-app can share one build instead of each duplicating the LibreSSL/
# SQLCipher/Fossil-patching recipe. See vendor/fossil-see/README.md.
#
# The mode-aware key source fossil-see wires in reads:
#   FOSSIL_SEE_KEY env var > gpg-decrypt keys/master.key.asc > stock prompt
#   only if FOSSIL_SEE_STOCK_PROMPT=1.
# (Renamed from FOSSIL_PPV_KEY/FOSSIL_PPV_STOCK_PROMPT when the build moved
# into fossil-see, since the mechanism isn't voting-specific. See
# docs/threat-model.md here and vendor/fossil-see/docs/SECURITY.md there.)
#
# The CLI (bin/ppv) is not linked into Fossil. It runs in standalone QuickJS
# alongside this binary. A verifier needs: the custom fossil (for mode-2
# SQLCipher repos), qjs-ppv, gpg.
#
# Optional env:
#   OUTPUT_DIR   where to write fossil-ppv (default: build/dist)
#   JOBS         make parallelism; passed through to fossil-see's build.sh
#                via normal environment inheritance

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/dist}"
FOSSIL_SEE_DIR="$REPO_ROOT/vendor/fossil-see"

[ -d "$FOSSIL_SEE_DIR" ] || { echo "ERR: $FOSSIL_SEE_DIR not a directory (did you 'git submodule update --init --recursive'?)"; exit 1; }
[ -x "$FOSSIL_SEE_DIR/build/build.sh" ] || { echo "ERR: $FOSSIL_SEE_DIR/build/build.sh missing or not executable"; exit 1; }

mkdir -p "$OUTPUT_DIR"

echo "==> Delegating to vendor/fossil-see/build/build.sh"
"$FOSSIL_SEE_DIR/build/build.sh"

echo "==> Installing to $OUTPUT_DIR"
cp "$FOSSIL_SEE_DIR/build/dist/fossil-see" "$OUTPUT_DIR/fossil-ppv"
ls -lh "$OUTPUT_DIR/fossil-ppv"

echo "==> Smoke test"
"$OUTPUT_DIR/fossil-ppv" version

echo "==> Build complete"
