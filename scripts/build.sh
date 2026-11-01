#!/usr/bin/env bash
# =============================================================================
# Firewood mobile — minified release build pipeline.
#
# Always build through this script so every artifact is:
#   * R8-minified + resource-shrunk (isMinifyEnabled/isShrinkResources in
#     android/app/build.gradle.kts, verified after the build)
#   * Dart-obfuscated (--obfuscate) with split debug symbols kept OUT of the APK
#   * ABI-split (arm64-v8a by default) so the APK carries one native lib set
#   * Release-signed (fails closed without android/key.properties — V-030)
#   * Checksummed (SHA-256) and copied to dist/ with version + timestamp
#
# Usage:
#   scripts/build.sh [options]
#
# Options:
#   --abi <arm64|arm|x64|all>  Target ABI(s)                (default: arm64)
#   --aab                      Also build an App Bundle (Play Store)
#   --skip-checks              Skip `flutter analyze` and `flutter test`
#   --clean                    `flutter clean` before building
#   --push                     git push current branch after a successful build
#   --share <ssh-host>         scp APK to host (e.g. tp24)
#   --via <ssh-host>           Relay: upload to --share host, then forward from
#                              it to <ssh-host> (e.g. --share tp24 --via tunkstunph)
#   --dest <remote-path>       Remote path/name for share (default: ~/storage/shared/Download/firewood-release.apk)
#   --port <n>                 SSH port of the --via host      (default: 8022)
#   -h, --help                 Show this help
# =============================================================================
set -Eeuo pipefail

# ---------- helpers ----------------------------------------------------------
C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_CYN=$'\033[36m'; C_RST=$'\033[0m'
log()  { printf '%s[build]%s %s\n' "$C_CYN" "$C_RST" "$*"; }
ok()   { printf '%s[ ok  ]%s %s\n' "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s[warn ]%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; }
die()  { printf '%s[fail ]%s %s\n' "$C_RED" "$C_RST" "$*" >&2; exit 1; }
trap 'die "aborted at line $LINENO (exit $?)"' ERR

usage() { sed -n '2,/^# ====.*$/p' "$0" | sed -n '2,29p' | sed 's/^# \{0,1\}//'; }

# ---------- args -------------------------------------------------------------
ABI="arm64"; BUILD_AAB=0; SKIP_CHECKS=0; DO_CLEAN=0; DO_PUSH=0
SHARE_HOST=""; VIA_HOST=""; REMOTE_DEST="~/storage/shared/Download/firewood-release.apk"; VIA_PORT=8022

while [[ $# -gt 0 ]]; do
  case "$1" in
    --abi)         ABI="${2:?--abi needs a value}"; shift 2 ;;
    --aab)         BUILD_AAB=1; shift ;;
    --skip-checks) SKIP_CHECKS=1; shift ;;
    --clean)       DO_CLEAN=1; shift ;;
    --push)        DO_PUSH=1; shift ;;
    --share)       SHARE_HOST="${2:?--share needs a host}"; shift 2 ;;
    --via)         VIA_HOST="${2:?--via needs a host}"; shift 2 ;;
    --dest)        REMOTE_DEST="${2:?--dest needs a path}"; shift 2 ;;
    --port)        VIA_PORT="${2:?--port needs a number}"; shift 2 ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "unknown option: $1 (try --help)" ;;
  esac
done

case "$ABI" in
  arm64) PLATFORM="android-arm64";  ABI_NAME="arm64-v8a" ;;
  arm)   PLATFORM="android-arm";    ABI_NAME="armeabi-v7a" ;;
  x64)   PLATFORM="android-x64";    ABI_NAME="x86_64" ;;
  all)   PLATFORM="android-arm,android-arm64,android-x64"; ABI_NAME="all" ;;
  *)     die "invalid --abi '$ABI' (arm64|arm|x64|all)" ;;
esac

# ---------- locate project ---------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f pubspec.yaml ]] || die "pubspec.yaml not found in $ROOT"

START_TS=$(date +%s)
STAMP=$(date +%Y%m%d-%H%M%S)
VERSION=$(grep -E '^version:' pubspec.yaml | head -1 | awk '{print $2}')
VERSION_NAME="${VERSION%%+*}"; VERSION_CODE="${VERSION##*+}"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")
BRANCH=$(git branch --show-current 2>/dev/null || echo "-")
DIRTY=""; if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then DIRTY="-dirty"; fi

APK_DIR="build/app/outputs/flutter-apk"
SYMBOLS_DIR="build/symbols/${VERSION_NAME}+${VERSION_CODE}-${STAMP}"
DIST_DIR="dist"

log "Firewood ${VERSION_NAME} (code ${VERSION_CODE}) | git ${GIT_SHA}${DIRTY} on ${BRANCH} | ABI ${ABI_NAME}"

# ---------- preflight --------------------------------------------------------
command -v flutter >/dev/null || die "flutter not found in PATH"
command -v git     >/dev/null || warn "git not found; commit metadata skipped"

[[ -f android/key.properties || -n "${FIREWOOD_STORE_FILE:-}" ]] \
  || die "no release keystore (android/key.properties or FIREWOOD_STORE_FILE) — release signing fails closed (V-030)"

if [[ -f android/key.properties ]]; then
  STORE_FILE=$(grep -E '^store_file' android/key.properties | cut -d= -f2- | xargs || true)
  if [[ -n "$STORE_FILE" ]]; then
    # relative paths resolve from android/app (Gradle `file()` in the app module)
    if   [[ -f "$STORE_FILE" ]];              then :
    elif [[ -f "android/app/$STORE_FILE" ]];  then :
    else die "keystore referenced in key.properties not found: $STORE_FILE"; fi
  fi
fi

grep -qE 'isMinifyEnabled *= *true'   android/app/build.gradle.kts || die "R8 minify is not enabled in build.gradle.kts"
grep -qE 'isShrinkResources *= *true' android/app/build.gradle.kts || die "resource shrinking is not enabled in build.gradle.kts"
[[ -f android/app/proguard-rules.pro ]] || die "android/app/proguard-rules.pro missing"
ok "preflight: keystore present, R8 minify + resource shrink enabled"

# ---------- prepare ----------------------------------------------------------
if [[ $DO_CLEAN -eq 1 ]]; then
  log "flutter clean"; flutter clean
fi
log "flutter pub get"
flutter pub get

if [[ $SKIP_CHECKS -eq 0 ]]; then
  log "flutter analyze (errors fail the build; infos/warnings do not)"
  flutter analyze --no-fatal-infos --no-fatal-warnings
  if [[ -d test ]] && [[ -n "$(find test -name '*_test.dart' -print -quit 2>/dev/null)" ]]; then
    log "flutter test"
    flutter test
  fi
else
  warn "skipping analyze/test (--skip-checks)"
fi

# ---------- build ------------------------------------------------------------
mkdir -p "$SYMBOLS_DIR" "$DIST_DIR"

COMMON_FLAGS=(
  --release
  --obfuscate
  "--split-debug-info=${SYMBOLS_DIR}"
  --tree-shake-icons
  "--target-platform=${PLATFORM}"
)

log "building minified APK (R8 + Dart obfuscation + tree-shaken icons)"
if [[ "$ABI" == "all" ]]; then
  flutter build apk "${COMMON_FLAGS[@]}" --split-per-abi
else
  flutter build apk "${COMMON_FLAGS[@]}" --split-per-abi
fi

if [[ $BUILD_AAB -eq 1 ]]; then
  log "building App Bundle"
  flutter build appbundle "${COMMON_FLAGS[@]}"
fi

# ---------- collect artifacts ------------------------------------------------
shopt -s nullglob
if [[ "$ABI" == "all" ]]; then
  APKS=("$APK_DIR"/app-*-release.apk)
else
  APKS=("$APK_DIR/app-${ABI_NAME}-release.apk")
fi
[[ ${#APKS[@]} -gt 0 && -f "${APKS[0]}" ]] || die "expected APK not found in $APK_DIR"

# freshness guard: never ship a stale file from a previous run
for f in "${APKS[@]}"; do
  mtime=$(stat -c %Y "$f")
  (( mtime >= START_TS )) || die "stale artifact (not rebuilt this run): $f"
done

OUT_FILES=()
for f in "${APKS[@]}"; do
  abi=$(basename "$f" | sed -E 's/^app-(.*)-release\.apk$/\1/')
  out="${DIST_DIR}/firewood-${VERSION_NAME}+${VERSION_CODE}-${abi}-${STAMP}-${GIT_SHA}${DIRTY}.apk"
  cp -f "$f" "$out"; OUT_FILES+=("$out")
done

if [[ $BUILD_AAB -eq 1 ]]; then
  AAB="build/app/outputs/bundle/release/app-release.aab"
  [[ -f "$AAB" ]] || die "AAB not found: $AAB"
  out="${DIST_DIR}/firewood-${VERSION_NAME}+${VERSION_CODE}-${STAMP}-${GIT_SHA}${DIRTY}.aab"
  cp -f "$AAB" "$out"; OUT_FILES+=("$out")
fi

# keep the debug symbols next to the artifacts (needed to de-obfuscate stack traces)
SYM_ARCHIVE="${DIST_DIR}/symbols-${VERSION_NAME}+${VERSION_CODE}-${STAMP}.tar.gz"
tar -czf "$SYM_ARCHIVE" -C "$(dirname "$SYMBOLS_DIR")" "$(basename "$SYMBOLS_DIR")"

# ---------- verify -----------------------------------------------------------
verify_apk() {
  local apk="$1" sdk bt
  sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}}"
  bt=$(ls -1 "$sdk/build-tools" 2>/dev/null | sort -V | tail -1 || true)

  # 1. minification evidence: R8 emits a mapping file; obfuscated class names are short
  local mapping="build/app/outputs/mapping/release/mapping.txt"
  if [[ -f "$mapping" ]]; then ok "R8 mapping present ($(wc -l < "$mapping") lines)"
  else warn "R8 mapping.txt not found — minification could not be confirmed"; fi

  # 2. signature
  if [[ -n "$bt" && -x "$sdk/build-tools/$bt/apksigner" ]]; then
    if "$sdk/build-tools/$bt/apksigner" verify --print-certs "$apk" >/tmp/firewood-apksigner.$$ 2>&1; then
      ok "signature valid: $(grep -m1 'certificate DN' /tmp/firewood-apksigner.$$ || echo 'ok')"
      if grep -qi 'Android Debug' /tmp/firewood-apksigner.$$; then
        rm -f /tmp/firewood-apksigner.$$
        die "APK is signed with the DEBUG key — refusing to ship (V-030)"
      fi
    else
      cat /tmp/firewood-apksigner.$$ >&2; rm -f /tmp/firewood-apksigner.$$
      die "apksigner verification failed for $apk"
    fi
    rm -f /tmp/firewood-apksigner.$$
  else
    warn "apksigner not found; skipped signature verification"
  fi

  # 3. no debug symbols / unminified Dart snapshot leaked inside the APK
  if unzip -l "$apk" | grep -qE '\.symbols$|mapping\.txt$'; then
    die "debug symbols / mapping found inside APK"
  fi
  ok "no symbol files bundled inside the APK"
}

for f in "${OUT_FILES[@]}"; do [[ "$f" == *.apk ]] && verify_apk "$f"; done

# ---------- checksums + report ----------------------------------------------
( cd "$DIST_DIR" && sha256sum "$(basename "${OUT_FILES[0]}")" >/dev/null )
SUMS="${DIST_DIR}/SHA256SUMS-${STAMP}.txt"
( cd "$DIST_DIR" && for f in "${OUT_FILES[@]}"; do sha256sum "$(basename "$f")"; done ) > "$SUMS"

human() { numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "$1 B"; }
printf '\n%s================ BUILD REPORT ================%s\n' "$C_GRN" "$C_RST"
printf 'Version      : %s (code %s)\n' "$VERSION_NAME" "$VERSION_CODE"
printf 'Git          : %s%s (%s)\n'    "$GIT_SHA" "$DIRTY" "$BRANCH"
printf 'Built        : %s\n'           "$(date '+%Y-%m-%d %H:%M:%S %z')"
printf 'Build time   : %ss\n'          "$(( $(date +%s) - START_TS ))"
printf 'Minify       : R8 + resource shrink + Dart obfuscation\n'
printf 'Symbols      : %s\n'           "$SYM_ARCHIVE"
for f in "${OUT_FILES[@]}"; do
  printf 'Artifact     : %s (%s)\n' "$f" "$(human "$(stat -c %s "$f")")"
  printf 'SHA-256      : %s\n'      "$(sha256sum "$f" | cut -d' ' -f1)"
done
printf '%s==============================================%s\n\n' "$C_GRN" "$C_RST"

PRIMARY_APK=""
for f in "${OUT_FILES[@]}"; do [[ "$f" == *.apk ]] && { PRIMARY_APK="$f"; break; }; done

# ---------- push -------------------------------------------------------------
if [[ $DO_PUSH -eq 1 ]]; then
  [[ -n "$BRANCH" && "$BRANCH" != "-" ]] || die "cannot push: no current branch"
  if [[ -n "$DIRTY" ]]; then
    warn "working tree has uncommitted changes; only commits are pushed (artifact was built from the dirty tree)"
  fi
  log "git push origin ${BRANCH}"
  git push origin "$BRANCH"
  ok "pushed ${BRANCH}"
fi

# ---------- share ------------------------------------------------------------
if [[ -n "$SHARE_HOST" ]]; then
  [[ -n "$PRIMARY_APK" ]] || die "nothing to share (no APK built)"
  local_sum=$(sha256sum "$PRIMARY_APK" | cut -d' ' -f1)

  log "uploading to ${SHARE_HOST}:${REMOTE_DEST}"
  scp -q "$PRIMARY_APK" "${SHARE_HOST}:${REMOTE_DEST}"

  if [[ -n "$VIA_HOST" ]]; then
    log "relaying ${SHARE_HOST} -> ${VIA_HOST}:${VIA_PORT}"
    ssh "$SHARE_HOST" "scp -q -P ${VIA_PORT} -o BatchMode=yes ${REMOTE_DEST} ${VIA_HOST}:${REMOTE_DEST}"
    remote_sum=$(ssh "$SHARE_HOST" "ssh -o BatchMode=yes ${VIA_HOST} 'sha256sum ${REMOTE_DEST}'" | cut -d' ' -f1)
    where="${VIA_HOST} (via ${SHARE_HOST})"
  else
    remote_sum=$(ssh "$SHARE_HOST" "sha256sum ${REMOTE_DEST}" | cut -d' ' -f1)
    where="$SHARE_HOST"
  fi

  [[ "$remote_sum" == "$local_sum" ]] \
    || die "checksum mismatch after share: local ${local_sum} vs remote ${remote_sum}"
  ok "shared to ${where} — SHA-256 verified (${local_sum:0:12}…)"
fi

ok "done in $(( $(date +%s) - START_TS ))s"
