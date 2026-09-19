#!/usr/bin/env bash
# Remove as400-signon drop-in and binary; restore stock getty for the VT.
set -euo pipefail

PROG_NAME="as400-signon"
DRY_RUN=0
CLI_TTY=""
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--tty N] [--dry-run]

Remove ${PROG_NAME} from the VT recorded at install time (or --tty N).

  --tty N       Override VT number if state file is missing
  --dry-run     Print actions only
  -h, --help    Show this help
USAGE
}

log() { printf '%s\n' "$*"; }
run() {
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: $*"
  else
    log "+ $*"
    "$@"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --tty) CLI_TTY=${2:?}; shift 2 ;;
    --tty=*) CLI_TTY=${1#*=}; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ "$DRY_RUN" != 1 ] && [ "$(id -u)" -ne 0 ]; then
  printf 'Must run as root (or use --dry-run)\n' >&2
  exit 1
fi

STATE_FILE="/var/lib/${PROG_NAME}/install.env"
PREFIX="/usr/local"
LIBEXEC="${PREFIX}/libexec/${PROG_NAME}"
UNIT_DROPIN_DIR=""
TTY_NUM=""

if [ -f "$STATE_FILE" ]; then
  # shellcheck disable=SC1090
  . "$STATE_FILE"
fi

if [ -n "$CLI_TTY" ]; then
  TTY_NUM=$CLI_TTY
fi

if [ -z "${TTY_NUM:-}" ]; then
  printf 'No VT recorded and no --tty N given.\n' >&2
  exit 1
fi

UNIT_DROPIN_DIR="${UNIT_DROPIN_DIR:-/etc/systemd/system/getty@tty${TTY_NUM}.service.d}"
LIBEXEC="${LIBEXEC:-/usr/local/libexec/${PROG_NAME}}"
DROPIN="${UNIT_DROPIN_DIR}/as400-signon.conf"
ISSUE="/etc/issue.d/as400-signon.issue"

log "=== ${PROG_NAME} uninstall (tty${TTY_NUM}) ==="

if [ -f "$DROPIN" ]; then
  run rm -f "$DROPIN"
  # Remove drop-in dir if empty
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: rmdir --ignore-fail-on-non-empty ${UNIT_DROPIN_DIR}"
  else
    rmdir --ignore-fail-on-non-empty "$UNIT_DROPIN_DIR" 2>/dev/null || true
  fi
else
  log "No drop-in at ${DROPIN}"
fi

if [ -e "$LIBEXEC" ]; then
  run rm -f "$LIBEXEC"
fi

if [ -f "$ISSUE" ]; then
  run rm -f "$ISSUE"
fi

if [ -f "$STATE_FILE" ]; then
  run rm -f "$STATE_FILE"
fi

run systemctl daemon-reload
run systemctl restart "getty@tty${TTY_NUM}.service"

log "Done. tty${TTY_NUM} is back to stock agetty/login."
log "Backups (if any) remain under /var/backups/${PROG_NAME}/"
