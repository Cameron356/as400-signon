#!/usr/bin/env bash
# Install as400-signon onto a Debian (or derivative) host for one VT.
# Requires --tty N (defaults to 3). Refuses tty1 unless --force-tty1.
set -euo pipefail

PROG_NAME="as400-signon"
PREFIX="${PREFIX:-/usr/local}"
LIBEXEC="${PREFIX}/libexec/${PROG_NAME}"
UNIT_DROPIN_DIR=""
BACKUP_DIR=""
TTY_NUM=""
FORCE_TTY1=0
DRY_RUN=0
DO_RESTART=1
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

usage() {
  cat <<USAGE
Usage: $(basename "$0") --tty N [options]

Install ${PROG_NAME} for a single virtual terminal (getty@ttyN).

Required / primary:
  --tty N              VT number (1–63). Default if omitted: 3
  --force-tty1         Allow tty1 (refused by default — often the primary console)

Options:
  --prefix DIR         Install prefix (default: /usr/local)
  --dry-run            Print actions only; change nothing
  --no-restart         Install drop-in but do not restart getty@ttyN
  -h, --help           Show this help

What it does:
  1. Copies bin/as400-signon → \${PREFIX}/libexec/as400-signon
  2. Installs systemd drop-in getty@ttyN.service.d/as400-signon.conf
  3. Optionally installs /etc/issue.d/as400-signon.issue (static art; unused
     when agetty --noissue is set — kept for reference / non-skip login)
  4. systemctl daemon-reload && restart getty@ttyN (unless --no-restart)

Backups go under /var/backups/as400-signon/<timestamp>/.

Examples:
  sudo ./scripts/install.sh --tty 3
  sudo ./scripts/install.sh --tty 1 --force-tty1   # only if you mean to replace tty1 getty
  ./scripts/install.sh --tty 3 --dry-run
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
    --tty)
      TTY_NUM=${2:?"--tty requires a number"}
      shift 2
      ;;
    --tty=*)
      TTY_NUM=${1#*=}
      shift
      ;;
    --force-tty1) FORCE_TTY1=1; shift ;;
    --prefix)
      PREFIX=${2:?}
      LIBEXEC="${PREFIX}/libexec/${PROG_NAME}"
      shift 2
      ;;
    --dry-run) DRY_RUN=1; shift ;;
    --no-restart) DO_RESTART=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# Default tty3 — spare VT, never tty1
if [ -z "$TTY_NUM" ]; then
  TTY_NUM=3
  log "Note: --tty omitted; defaulting to tty3"
fi

if ! [[ "$TTY_NUM" =~ ^[0-9]+$ ]] || [ "$TTY_NUM" -lt 1 ] || [ "$TTY_NUM" -gt 63 ]; then
  printf 'Invalid --tty %q (want 1–63)\n' "$TTY_NUM" >&2
  exit 2
fi

if [ "$TTY_NUM" = 1 ] && [ "$FORCE_TTY1" != 1 ]; then
  cat >&2 <<'REFUSE'
Refusing to install on tty1.
tty1 is often the primary console (and on some hosts a dashboard). Hijacking
getty@tty1 would displace whatever is there. Prefer a spare VT, e.g.:

  sudo ./scripts/install.sh --tty 3

If you really mean tty1:  --tty 1 --force-tty1
REFUSE
  exit 1
fi

UNIT_DROPIN_DIR="/etc/systemd/system/getty@tty${TTY_NUM}.service.d"
TS=$(date +%Y%m%dT%H%M%S)
BACKUP_DIR="/var/backups/${PROG_NAME}/${TS}"

if [ "$DRY_RUN" != 1 ] && [ "$(id -u)" -ne 0 ]; then
  printf 'Must run as root (or use --dry-run)\n' >&2
  exit 1
fi

SRC_BIN="${REPO_ROOT}/bin/as400-signon"
SRC_DROPIN="${REPO_ROOT}/systemd/as400-signon.conf"
SRC_ISSUE="${REPO_ROOT}/issue/as400-signon.issue"

for f in "$SRC_BIN" "$SRC_DROPIN"; do
  if [ ! -f "$f" ]; then
    printf 'Missing %s — run from a full checkout\n' "$f" >&2
    exit 1
  fi
done

log "=== ${PROG_NAME} install (tty${TTY_NUM}) ==="
log "prefix=${PREFIX}  libexec=${LIBEXEC}"
log "drop-in=${UNIT_DROPIN_DIR}/as400-signon.conf"
log "backup=${BACKUP_DIR}"

run mkdir -p "$(dirname "$LIBEXEC")" "$UNIT_DROPIN_DIR"
if [ "$DRY_RUN" != 1 ]; then
  mkdir -p "$BACKUP_DIR"
fi

if [ -e "$LIBEXEC" ]; then
  run cp -a "$LIBEXEC" "${BACKUP_DIR}/as400-signon.prev"
fi
run install -m 0755 "$SRC_BIN" "$LIBEXEC"

DROPIN_DEST="${UNIT_DROPIN_DIR}/as400-signon.conf"
if [ -e "$DROPIN_DEST" ]; then
  run cp -a "$DROPIN_DEST" "${BACKUP_DIR}/as400-signon.conf.prev"
fi

# Bake the libexec path into the drop-in
if [ "$DRY_RUN" = 1 ]; then
  log "DRY-RUN: would write drop-in with LoginProgram=${LIBEXEC}"
else
  sed "s|@LIBEXEC@|${LIBEXEC}|g" "$SRC_DROPIN" > "$DROPIN_DEST"
  chmod 0644 "$DROPIN_DEST"
  log "+ wrote ${DROPIN_DEST}"
fi

# Optional static issue art (not shown with --noissue; useful for docs / fallback)
ISSUE_DEST="/etc/issue.d/as400-signon.issue"
if [ -f "$SRC_ISSUE" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    log "DRY-RUN: mkdir -p /etc/issue.d && install issue art"
  else
    mkdir -p /etc/issue.d
    if [ -e "$ISSUE_DEST" ]; then
      cp -a "$ISSUE_DEST" "${BACKUP_DIR}/as400-signon.issue.prev"
    fi
    install -m 0644 "$SRC_ISSUE" "$ISSUE_DEST"
    log "+ installed ${ISSUE_DEST} (reference; agetty --noissue hides it)"
  fi
fi

# Record state for uninstall
STATE_DIR="/var/lib/${PROG_NAME}"
if [ "$DRY_RUN" = 1 ]; then
  log "DRY-RUN: would record state tty=${TTY_NUM} in ${STATE_DIR}/install.env"
else
  mkdir -p "$STATE_DIR"
  cat > "${STATE_DIR}/install.env" <<STATE
TTY_NUM=${TTY_NUM}
PREFIX=${PREFIX}
LIBEXEC=${LIBEXEC}
UNIT_DROPIN_DIR=${UNIT_DROPIN_DIR}
BACKUP_DIR=${BACKUP_DIR}
INSTALLED_AT=${TS}
STATE
  chmod 0644 "${STATE_DIR}/install.env"
fi

run systemctl daemon-reload

if [ "$DO_RESTART" = 1 ]; then
  run systemctl restart "getty@tty${TTY_NUM}.service"
else
  log "Skipping restart (--no-restart). After reboot or:"
  log "  systemctl restart getty@tty${TTY_NUM}.service"
fi

log ""
log "Done. Switch to VT${TTY_NUM} (Ctrl+Alt+F${TTY_NUM}) to see Sign On."
log "Uninstall:  sudo ${REPO_ROOT}/scripts/uninstall.sh"
log "Manual test without hijacking a getty:"
log "  sudo AS400_SIGNON_UI_ONLY=1 ${LIBEXEC}"
