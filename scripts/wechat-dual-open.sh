#!/usr/bin/env bash
set -euo pipefail

SOURCE_APP="/Applications/WeChat.app"
TARGET_APP="/Applications/EarnMore.app"
TARGET_BUNDLE_ID="com.tencent.xinEarnMore"
REFRESH_COPY=0
NO_LAUNCH=0
DIAGNOSE=0

usage() {
  cat <<'EOF'
Usage: wechat-dual-open.sh [options]

Create, repair, and optionally launch a second WeChat on macOS.

Options:
  --source PATH       Source WeChat.app path. Default: /Applications/WeChat.app
  --target PATH       Clone app path. Default: /Applications/EarnMore.app
  --bundle-id ID      Bundle id for the clone. Default: com.tencent.xinEarnMore
  --refresh-copy      Delete the target clone and copy from the source app first
  --no-launch         Configure and verify only; do not launch the clone
  --diagnose          Print current state without changing files
  -h, --help          Show this help

Examples:
  bash scripts/wechat-dual-open.sh
  bash scripts/wechat-dual-open.sh --refresh-copy
  bash scripts/wechat-dual-open.sh --target /Applications/WeChat-Work.app --bundle-id com.tencent.xinWorkClone
EOF
}

log() {
  printf '[wechat-dual-open] %s\n' "$*"
}

die() {
  printf '[wechat-dual-open] ERROR: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

sudo_if_needed() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

plist_get() {
  local plist="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :${key}" "$plist" 2>/dev/null || true
}

plist_set_or_add() {
  local plist="$1"
  local key="$2"
  local value="$3"
  if sudo_if_needed /usr/libexec/PlistBuddy -c "Set :${key} ${value}" "$plist" 2>/dev/null; then
    return 0
  fi
  sudo_if_needed /usr/libexec/PlistBuddy -c "Add :${key} string ${value}" "$plist"
}

realpath_portable() {
  local path="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$path"
  else
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$path"
  fi
}

validate_paths() {
  [[ "$(uname -s)" == "Darwin" ]] || die "This script only supports macOS."
  [[ -d "$SOURCE_APP" ]] || die "Source app not found: $SOURCE_APP"
  [[ "$SOURCE_APP" == *.app ]] || die "Source path must end with .app: $SOURCE_APP"
  [[ "$TARGET_APP" == *.app ]] || die "Target path must end with .app: $TARGET_APP"

  local source_real
  local target_parent
  local target_parent_real
  source_real="$(realpath_portable "$SOURCE_APP")"
  target_parent="$(dirname "$TARGET_APP")"
  [[ -d "$target_parent" ]] || die "Target parent directory not found: $target_parent"
  target_parent_real="$(realpath_portable "$target_parent")"

  [[ "$SOURCE_APP" != "$TARGET_APP" ]] || die "Target app must differ from source app."
  local source_bundle_id
  source_bundle_id="$(plist_get "$SOURCE_APP/Contents/Info.plist" CFBundleIdentifier)"
  [[ -n "$source_bundle_id" ]] || die "Cannot read source CFBundleIdentifier from $SOURCE_APP/Contents/Info.plist"
  [[ "$TARGET_BUNDLE_ID" != "$source_bundle_id" ]] || die "Clone bundle id must differ from the source WeChat bundle id: $source_bundle_id"
  [[ "$TARGET_BUNDLE_ID" != "com.tencent.xin" ]] || die "Clone bundle id must not use the legacy official WeChat bundle id: com.tencent.xin"
  case "$target_parent_real" in
    "$source_real"/*) die "Target must not be inside the source app bundle." ;;
  esac
}

diagnose() {
  log "Source app: $SOURCE_APP"
  log "Target app: $TARGET_APP"
  log "Target bundle id: $TARGET_BUNDLE_ID"

  if [[ -f "$SOURCE_APP/Contents/Info.plist" ]]; then
    log "Source CFBundleIdentifier: $(plist_get "$SOURCE_APP/Contents/Info.plist" CFBundleIdentifier)"
  else
    log "Source Info.plist: missing"
  fi

  if [[ -d "$TARGET_APP" ]]; then
    if [[ -f "$TARGET_APP/Contents/Info.plist" ]]; then
      log "Target CFBundleIdentifier: $(plist_get "$TARGET_APP/Contents/Info.plist" CFBundleIdentifier)"
    else
      log "Target Info.plist: missing"
    fi
    if /usr/bin/codesign --verify --deep --strict "$TARGET_APP" >/dev/null 2>&1; then
      log "Target code signature: valid"
    else
      log "Target code signature: invalid or missing"
    fi
  else
    log "Target app: missing; it will be created from source during a normal run"
  fi
}

copy_target_if_needed() {
  if [[ "$REFRESH_COPY" -eq 1 && -d "$TARGET_APP" ]]; then
    log "Removing existing target because --refresh-copy was supplied: $TARGET_APP"
    sudo_if_needed /bin/rm -rf "$TARGET_APP"
  fi

  if [[ ! -d "$TARGET_APP" ]]; then
    log "Copying source app to target: $SOURCE_APP -> $TARGET_APP"
    sudo_if_needed /usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
  else
    log "Target exists; repairing in place: $TARGET_APP"
  fi
}

configure_target() {
  local plist="$TARGET_APP/Contents/Info.plist"
  local executable="$TARGET_APP/Contents/MacOS/WeChat"

  [[ -f "$plist" ]] || die "Target Info.plist not found: $plist"
  [[ -x "$executable" ]] || die "Target WeChat executable not found or not executable: $executable"

  log "Setting target CFBundleIdentifier to: $TARGET_BUNDLE_ID"
  plist_set_or_add "$plist" CFBundleIdentifier "$TARGET_BUNDLE_ID"

  log "Removing quarantine xattr if present"
  sudo_if_needed /usr/bin/xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

  log "Re-signing target app with ad-hoc signature"
  sudo_if_needed /usr/bin/codesign --force --deep --sign - "$TARGET_APP"

  local actual_id
  actual_id="$(plist_get "$plist" CFBundleIdentifier)"
  [[ "$actual_id" == "$TARGET_BUNDLE_ID" ]] || die "Bundle id verification failed: expected $TARGET_BUNDLE_ID, got $actual_id"

  log "Verifying code signature"
  /usr/bin/codesign --verify --deep --strict "$TARGET_APP"
}

launch_target() {
  local executable="$TARGET_APP/Contents/MacOS/WeChat"
  [[ "$NO_LAUNCH" -eq 0 ]] || {
    log "Launch skipped because --no-launch was supplied"
    return 0
  }

  log "Launching cloned WeChat: $executable"
  if [[ "${EUID}" -eq 0 ]]; then
    local console_user
    local console_uid
    console_user="$(/usr/bin/stat -f '%Su' /dev/console)"
    [[ -n "$console_user" && "$console_user" != "root" ]] || die "Cannot identify the desktop user for launch. Re-run as your normal user."
    console_uid="$(/usr/bin/id -u "$console_user")"
    /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" /bin/sh -c 'nohup "$1" >/dev/null 2>&1 & echo $!' sh "$executable"
  else
    nohup "$executable" >/dev/null 2>&1 &
    printf '%s\n' "$!"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      [[ $# -ge 2 ]] || die "--source requires a path"
      SOURCE_APP="$2"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || die "--target requires a path"
      TARGET_APP="$2"
      shift 2
      ;;
    --bundle-id)
      [[ $# -ge 2 ]] || die "--bundle-id requires a value"
      TARGET_BUNDLE_ID="$2"
      shift 2
      ;;
    --refresh-copy)
      REFRESH_COPY=1
      shift
      ;;
    --no-launch)
      NO_LAUNCH=1
      shift
      ;;
    --diagnose)
      DIAGNOSE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

need_cmd /usr/libexec/PlistBuddy
need_cmd /usr/bin/codesign
need_cmd /usr/bin/ditto
need_cmd /usr/bin/xattr

validate_paths

if [[ "$DIAGNOSE" -eq 1 ]]; then
  diagnose
  exit 0
fi

copy_target_if_needed
configure_target
pid="$(launch_target)"

if [[ "$NO_LAUNCH" -eq 0 ]]; then
  log "Launch command submitted. PID: $pid"
fi
log "Done."
