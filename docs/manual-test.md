# Manual test (spare VT)

Do **not** enable on fTower tty1 (dashboard). Prefer tty3+.

## Dry-run install

```bash
cd ~/src/as400-signon
./scripts/install.sh --tty 3 --dry-run
```

## UI-only (no PAM, any user)

```bash
sudo AS400_SIGNON_UI_ONLY=1 /usr/local/libexec/as400-signon
# or from the checkout:
sudo AS400_SIGNON_UI_ONLY=1 ./bin/as400-signon
```

## Live on tty3

```bash
sudo ./scripts/install.sh --tty 3
# Ctrl+Alt+F3 → Sign On → real account
# Return: Ctrl+Alt+F1 (dashboard) or F7 (GUI) as applicable
sudo ./scripts/uninstall.sh
```

## Dump screen to ANSI (screenshots)

```bash
AS400_SIGNON_DUMP=1 AS400_SYSTEM=ftower AS400_COLS=80 \
  AS400_DATE_FMT='+%m/%d/%y' \
  ./bin/as400-signon > /tmp/signon.ansi
```
